package local.personachat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties={"LLM_API_KEY=test-not-a-real-key", "CHAT_CLIENT_TOKEN=test-local-token-over-32-characters"})
@AutoConfigureMockMvc
class HttpAccessTest {
    @Autowired MockMvc mvc;
    static final String TOKEN = "test-local-token-over-32-characters";
    @DynamicPropertySource static void promptPath(DynamicPropertyRegistry r) {
        r.add("CHAT_PROMPT_DIR", () -> java.nio.file.Path.of("../prompts").toAbsolutePath().toString());
    }
    @Test void healthHasNoSecrets() throws Exception {
        mvc.perform(get("/api/health").header("X-Chat-Token", TOKEN)).andExpect(status().isOk())
                .andExpect(jsonPath("$.service").value("persona-chat")).andExpect(jsonPath("$.apiKey").doesNotExist())
                .andExpect(jsonPath("$.token").doesNotExist());
    }
    @Test void missingOrWrongTokenDenied() throws Exception {
        mvc.perform(get("/api/health")).andExpect(status().isForbidden());
        mvc.perform(get("/api/health").header("X-Chat-Token", "wrong")).andExpect(status().isForbidden());
    }
    @Test void browserOriginDeniedEvenWithToken() throws Exception {
        mvc.perform(get("/api/health").header("X-Chat-Token", TOKEN).header("Origin", "https://example.com")).andExpect(status().isForbidden());
    }
    @Test void malformedRequestsRejectedWithoutApiCall() throws Exception {
        mvc.perform(post("/api/chat").header("X-Chat-Token", TOKEN).contentType("application/json").content("{\"stage\":3,\"messages\":[]}"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.error").value("INVALID_MESSAGES"));
        mvc.perform(post("/api/chat").header("X-Chat-Token", TOKEN).contentType("application/json").content("{\"apiKey\":\"no\"}"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.error").value("INVALID_JSON"));
    }
}
