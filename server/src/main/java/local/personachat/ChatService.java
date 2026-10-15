package local.personachat;

import com.fasterxml.jackson.databind.*;
import com.fasterxml.jackson.databind.node.*;
import org.springframework.stereotype.Service;
import java.io.IOException;
import java.net.URI;
import java.net.http.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.Semaphore;

@Service
public final class ChatService {
    public record Message(String role, String content) {}
    public record Request(int stage, List<Message> messages) {}
    public record Reply(String reply, String model, boolean truncated, String emotion) {}
    private static final String OUTPUT_RULE = "\n[출력 형식]\nJSON 객체의 reply에는 캐릭터의 실제 대사만, emotion에는 캐릭터가 답변하며 드러내는 표정 상태를 넣어. "
            + "emotion은 neutral(평상시), happy(기쁨), sad(슬픔 또는 걱정) 중 하나야. 사용자 감정과 캐릭터 표정은 같을 필요가 없어. "
            + "애매하면 neutral. 이 형식 규칙은 캐릭터의 관계나 말투를 추가로 정하지 않아.";
    static final class ChatFailure extends RuntimeException {
        final int status; final String code;
        ChatFailure(int status, String code) { super(code); this.status = status; this.code = code; }
    }
    private final ChatSettings settings;
    private final ObjectMapper mapper;
    private final HttpClient http;
    private final URI endpoint;
    private final Map<Integer, String> prompts = new HashMap<>();
    private final Semaphore inFlight = new Semaphore(1);
    @org.springframework.beans.factory.annotation.Autowired
    public ChatService(ChatSettings settings, ObjectMapper mapper) throws IOException {
        this(settings, mapper, URI.create("https://api.openai.com/v1/chat/completions"));
    }
    // Package-private endpoint injection is only used by local HTTP integration tests.
    ChatService(ChatSettings settings, ObjectMapper mapper, URI endpoint) throws IOException {
        this.settings = settings; this.mapper = mapper; this.endpoint = endpoint;
        http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(15))
                .followRedirects(HttpClient.Redirect.NEVER).build();
        String name = mapper.readTree(Files.readString(settings.characterFile, StandardCharsets.UTF_8).replace("\uFEFF", ""))
                .path("displayName").asText("").trim();
        if (name.isBlank() || name.length() > 40) throw new IOException("Invalid character displayName (1..40 characters)");
        for (int i = 1; i <= 3; i++) {
            String prompt = Files.readString(settings.promptDir.resolve("stage" + i + ".txt"), StandardCharsets.UTF_8)
                    .replace("\uFEFF", "").trim().replace("{{character_name}}", name);
            if (prompt.isBlank() || prompt.length() >= settings.charLimit) throw new IOException("Invalid stage" + i + " prompt");
            prompts.put(i, prompt + OUTPUT_RULE);
        }
    }
    ObjectNode payload(Request request) {
        if (request == null || !prompts.containsKey(request.stage()) || request.messages() == null
                || request.messages().isEmpty() || request.messages().size() > 21)
            throw new ChatFailure(400, "INVALID_MESSAGES");
        List<Message> history = request.messages();
        long chars = prompts.get(request.stage()).length();
        for (int i = 0; i < history.size(); i++) {
            Message m = history.get(i);
            String expectedRole = i % 2 == 0 ? "user" : "assistant";
            if (m == null || !expectedRole.equals(m.role()) || m.content() == null || m.content().isBlank())
                throw new ChatFailure(400, "INVALID_MESSAGES");
            chars += m.content().length();
        }
        if (!"user".equals(history.get(history.size() - 1).role())) throw new ChatFailure(400, "LAST_MESSAGE_MUST_BE_USER");
        if (chars > settings.charLimit) throw new ChatFailure(413, "CONTEXT_TOO_LONG");
        ObjectNode body = mapper.createObjectNode();
        body.put("model", settings.model); body.put("stream", false); body.put("store", false);
        body.put("max_completion_tokens", settings.maxTokens);
        if (!settings.reasoning.isEmpty()) body.put("reasoning_effort", settings.reasoning);
        if (!settings.temperature.isEmpty()) body.put("temperature", Double.parseDouble(settings.temperature));
        ObjectNode format = body.putObject("response_format");
        format.put("type", "json_schema");
        ObjectNode spec = format.putObject("json_schema");
        spec.put("name", "character_reply"); spec.put("strict", true);
        ObjectNode schema = spec.putObject("schema");
        schema.put("type", "object"); schema.put("additionalProperties", false);
        schema.putArray("required").add("reply").add("emotion");
        ObjectNode properties = schema.putObject("properties");
        properties.putObject("reply").put("type", "string");
        properties.putObject("emotion").put("type", "string").putArray("enum").add("neutral").add("happy").add("sad");
        ArrayNode messages = body.putArray("messages");
        messages.addObject().put("role", settings.instructionRole).put("content", prompts.get(request.stage()));
        history.forEach(m -> messages.addObject().put("role", m.role()).put("content", m.content()));
        return body;
    }
    public Reply chat(Request request) {
        ObjectNode body = payload(request);
        if (!inFlight.tryAcquire()) throw new ChatFailure(429, "REQUEST_IN_PROGRESS");
        try {
            HttpRequest outbound = HttpRequest.newBuilder(endpoint).timeout(Duration.ofSeconds(100))
                    .header("Authorization", "Bearer " + settings.apiKey).header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(body.toString(), StandardCharsets.UTF_8)).build();
            HttpResponse<String> response = http.send(outbound, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (response.statusCode() != 200) throw mapError(response.statusCode());
            JsonNode choice = mapper.readTree(response.body()).path("choices").path(0);
            return decode(choice);
        } catch (HttpTimeoutException e) { throw new ChatFailure(504, "UPSTREAM_TIMEOUT");
        } catch (InterruptedException e) { Thread.currentThread().interrupt(); throw new ChatFailure(503, "REQUEST_CANCELLED");
        } catch (IOException e) { throw new ChatFailure(502, "UPSTREAM_CONNECTION_FAILED");
        } finally { inFlight.release(); }
    }
    Reply decode(JsonNode choice) {
        if (!choice.path("message").path("refusal").asText("").isBlank()) throw new ChatFailure(422, "MODEL_REFUSAL");
        if ("length".equals(choice.path("finish_reason").asText())) throw new ChatFailure(502, "OUTPUT_TRUNCATED");
        String content = choice.path("message").path("content").asText("");
        if (content.isBlank()) throw new ChatFailure(502, "EMPTY_REPLY_CHECK_TOKEN_BUDGET");
        try {
            JsonNode data = mapper.readTree(content);
            if (data == null || !data.isObject() || !data.path("reply").isTextual() || data.path("reply").asText().isBlank())
                throw new ChatFailure(502, "INVALID_MODEL_RESPONSE");
            String emotion = data.path("emotion").asText("neutral");
            if (!Set.of("neutral", "happy", "sad").contains(emotion)) emotion = "neutral";
            return new Reply(data.path("reply").asText().trim(), settings.model, false, emotion);
        } catch (IOException e) { throw new ChatFailure(502, "INVALID_MODEL_RESPONSE"); }
    }
    static ChatFailure mapError(int status) {
        return switch (status) {
            case 401, 403 -> new ChatFailure(502, "API_KEY_OR_MODEL_ACCESS_DENIED");
            case 404 -> new ChatFailure(502, "MODEL_NOT_FOUND_OR_UNAVAILABLE");
            case 429 -> new ChatFailure(429, "API_QUOTA_OR_RATE_LIMIT");
            case 400 -> new ChatFailure(400, "MODEL_PARAMETERS_OR_CONTEXT_INVALID");
            default -> new ChatFailure(502, "UPSTREAM_ERROR");
        };
    }
}
