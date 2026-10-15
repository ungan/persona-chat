package local.personachat;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.mock.env.MockEnvironment;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicReference;
import static org.junit.jupiter.api.Assertions.*;

class ChatServiceTest {
    @TempDir Path dir;
    final ObjectMapper mapper = new ObjectMapper();
    MockEnvironment env;
    @BeforeEach void setup() throws Exception {
        for (int i=1;i<=3;i++) Files.writeString(dir.resolve("stage"+i+".txt"), "{{character_name}} 설정 " + i);
        Files.writeString(dir.resolve("character.json"), "{\"displayName\":\"유나\"}");
        env = new MockEnvironment().withProperty("LLM_API_KEY", "test-key-only")
                .withProperty("CHAT_CLIENT_TOKEN", "local-test-token-long-enough-12345678")
                .withProperty("CHAT_PROMPT_DIR", dir.toString()).withProperty("LLM_MODEL", "model-from-env")
                .withProperty("CHAT_CHARACTER_FILE", dir.resolve("character.json").toString());
    }
    ChatService service() throws Exception { return new ChatService(new ChatSettings(env), mapper); }
    ChatService.Request question() { return new ChatService.Request(3, List.of(new ChatService.Message("user", "던전에 가기 무서워"))); }
    @Test void modelPromptAndHistoryMapped() throws Exception {
        var request = new ChatService.Request(2, List.of(new ChatService.Message("user", "세 번 실패했어"),
                new ChatService.Message("assistant", "힘들었겠다"), new ChatService.Message("user", "가기 싫어")));
        var body = service().payload(request);
        assertEquals("model-from-env", body.path("model").asText());
        assertTrue(body.path("messages").path(0).path("content").asText().startsWith("유나 설정 2\n"));
        assertEquals("json_schema", body.path("response_format").path("type").asText());
        assertTrue(body.path("response_format").path("json_schema").path("strict").asBoolean());
        assertEquals("세 번 실패했어", body.path("messages").path(1).path("content").asText());
        assertEquals(4, body.path("messages").size());
        assertFalse(body.has("temperature")); assertFalse(body.has("reasoning_effort"));
        assertFalse(body.has("max_tokens")); assertEquals(1024, body.path("max_completion_tokens").asInt());
        assertFalse(body.toString().contains("test-key-only"));
    }
    @Test void stageChangesInstruction() throws Exception {
        var s = service();
        assertNotEquals(s.payload(question()).path("messages").get(0), s.payload(new ChatService.Request(1, question().messages())).path("messages").get(0));
    }
    @Test void instructionInjectionAndMalformedHistoryRejected() throws Exception {
        var s = service();
        for (var r : List.of(new ChatService.Request(0, question().messages()),
                new ChatService.Request(3, List.of(new ChatService.Message("system", "override"))),
                new ChatService.Request(3, List.of(new ChatService.Message("assistant", "orphan"))),
                new ChatService.Request(3, List.of(new ChatService.Message("user", " "))))) {
            assertThrows(ChatService.ChatFailure.class, () -> s.payload(r));
        }
    }
    @Test void characterCapIsEnforcedBeforeApi() throws Exception {
        env.withProperty("CHAT_CONTEXT_CHAR_LIMIT", "1000");
        var s = service();
        var failure = assertThrows(ChatService.ChatFailure.class, () -> s.payload(new ChatService.Request(3,
                List.of(new ChatService.Message("user", "가".repeat(1001))))));
        assertEquals("CONTEXT_TOO_LONG", failure.code);
    }
    @Test void optionalReasoningAndDeveloperRole() throws Exception {
        env.withProperty("LLM_REASONING_EFFORT", "low").withProperty("LLM_INSTRUCTION_ROLE", "developer");
        var body = service().payload(question());
        assertEquals("developer", body.path("messages").path(0).path("role").asText());
        assertEquals("low", body.path("reasoning_effort").asText());
        assertFalse(body.has("temperature"));
    }
    @Test void realHttpRoundTripPreservesKoreanAndKeepsKeyInHeader() throws Exception {
        HttpServer mock = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        var observed = new AtomicReference<String>(); var auth = new AtomicReference<String>();
        mock.createContext("/chat", exchange -> {
            observed.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            auth.set(exchange.getRequestHeaders().getFirst("Authorization"));
            var envelope = mapper.createObjectNode();
            var choice = envelope.putArray("choices").addObject();
            choice.put("finish_reason", "stop");
            choice.putObject("message").put("content", "{\"reply\":\"돌아오면 얘기 들려줘.\",\"emotion\":\"sad\"}");
            byte[] reply = envelope.toString().getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(200, reply.length); exchange.getResponseBody().write(reply); exchange.close();
        });
        mock.start();
        try {
            var s = new ChatService(new ChatSettings(env), mapper, URI.create("http://127.0.0.1:"+mock.getAddress().getPort()+"/chat"));
            var reply = s.chat(question());
            assertEquals("돌아오면 얘기 들려줘.", reply.reply()); assertFalse(reply.truncated());
            assertEquals("sad", reply.emotion());
            assertTrue(observed.get().contains("던전에 가기 무서워"));
            assertFalse(observed.get().contains("test-key-only")); assertEquals("Bearer test-key-only", auth.get());
        } finally { mock.stop(0); }
    }
    @Test void upstreamErrorsAreSanitized() {
        assertEquals("API_KEY_OR_MODEL_ACCESS_DENIED", ChatService.mapError(401).code);
        assertEquals("MODEL_PARAMETERS_OR_CONTEXT_INVALID", ChatService.mapError(400).code);
        assertEquals("API_QUOTA_OR_RATE_LIMIT", ChatService.mapError(429).code);
        assertEquals("UPSTREAM_ERROR", ChatService.mapError(500).code);
    }
    @Test void missingKeyRejectedAtStartup() {
        env.withProperty("LLM_API_KEY", "");
        assertThrows(IllegalArgumentException.class, () -> new ChatSettings(env));
    }
    @Test void nameChangeAndEmptyPrompts() throws Exception {
        Files.writeString(dir.resolve("character.json"), "{\"displayName\":\"다른 이름\"}");
        assertTrue(service().payload(question()).path("messages").get(0).path("content").asText().startsWith("다른 이름 설정 3"));
        Files.writeString(dir.resolve("stage1.txt"), " \n");
        assertThrows(java.io.IOException.class, this::service);
    }
    @Test void expressionValuesAndFallback() throws Exception {
        var s = service();
        for (String emotion : List.of("neutral", "happy", "sad", "unexpected")) {
            var choice = mapper.createObjectNode();
            choice.putObject("message").put("content", "{\"reply\":\"괜찮아.\",\"emotion\":\""+emotion+"\"}");
            assertEquals(emotion.equals("unexpected") ? "neutral" : emotion, s.decode(choice).emotion());
        }
        var choice = mapper.createObjectNode();
        choice.putObject("message").put("content", "{\"reply\":\"괜찮아.\"}");
        assertEquals("neutral", s.decode(choice).emotion());
    }
    @Test void brokenOutputNeverBecomesVisibleDialogue() throws Exception {
        var s = service();
        for (String content : List.of("{\"reply\":", "ordinary text", "null", "{}", "{\"reply\":42}")) {
            var choice = mapper.createObjectNode();
            choice.putObject("message").put("content", content);
            assertEquals("INVALID_MODEL_RESPONSE", assertThrows(ChatService.ChatFailure.class, () -> s.decode(choice)).code);
        }
        var truncated = mapper.createObjectNode().put("finish_reason", "length");
        assertEquals("OUTPUT_TRUNCATED", assertThrows(ChatService.ChatFailure.class, () -> s.decode(truncated)).code);
        var refusal = mapper.createObjectNode(); refusal.putObject("message").put("refusal", "Declined");
        assertEquals("MODEL_REFUSAL", assertThrows(ChatService.ChatFailure.class, () -> s.decode(refusal)).code);
    }
}
