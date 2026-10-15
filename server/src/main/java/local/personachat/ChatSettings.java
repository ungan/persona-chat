package local.personachat;

import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;
import java.nio.file.Path;
import java.util.Set;

@Component
public final class ChatSettings {
    final String apiKey, model, token, temperature, reasoning, instructionRole;
    final int maxTokens, charLimit, port;
    final Path promptDir, characterFile;
    public ChatSettings(Environment env) {
        apiKey = env.getProperty("LLM_API_KEY", "").trim();
        model = env.getProperty("LLM_MODEL", "gpt-4.1-mini").trim();
        token = env.getProperty("CHAT_CLIENT_TOKEN", "").trim();
        temperature = env.getProperty("LLM_TEMPERATURE", "").trim();
        reasoning = env.getProperty("LLM_REASONING_EFFORT", "").trim();
        instructionRole = env.getProperty("LLM_INSTRUCTION_ROLE", "system").trim();
        maxTokens = number(env, "LLM_MAX_COMPLETION_TOKENS", 1024, 64, 32768);
        charLimit = number(env, "CHAT_CONTEXT_CHAR_LIMIT", 20000, 1000, 200000);
        port = number(env, "CHAT_PORT", 18081, 1024, 65535);
        promptDir = Path.of(env.getProperty("CHAT_PROMPT_DIR", "prompts")).toAbsolutePath();
        characterFile = Path.of(env.getProperty("CHAT_CHARACTER_FILE", promptDir.resolveSibling("character/character.json").toString())).toAbsolutePath();
        if (apiKey.isBlank() || apiKey.equals("your-api-key-here")) throw new IllegalArgumentException("Set LLM_API_KEY in .env");
        if (model.isBlank() || model.length() > 150) throw new IllegalArgumentException("Invalid LLM_MODEL");
        if (token.length() < 32) throw new IllegalArgumentException("Use Start.ps1 to create a local client token");
        if (!Set.of("system", "developer").contains(instructionRole)) throw new IllegalArgumentException("Invalid instruction role");
        if (!reasoning.isEmpty() && !Set.of("none", "minimal", "low", "medium", "high", "xhigh").contains(reasoning))
            throw new IllegalArgumentException("Invalid reasoning effort");
        if (!temperature.isEmpty()) {
            double t = Double.parseDouble(temperature);
            if (!Double.isFinite(t) || t < 0 || t > 2) throw new IllegalArgumentException("Temperature must be 0..2");
        }
    }
    private static int number(Environment env, String name, int fallback, int min, int max) {
        int n = Integer.parseInt(env.getProperty(name, "" + fallback));
        if (n < min || n > max) throw new IllegalArgumentException("Invalid " + name);
        return n;
    }
}
