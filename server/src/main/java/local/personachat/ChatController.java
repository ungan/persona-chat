package local.personachat;

import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class ChatController {
    private final ChatService chat;
    private final ChatSettings settings;
    public ChatController(ChatService chat, ChatSettings settings) { this.chat = chat; this.settings = settings; }
    @GetMapping("/health") public Map<String, Object> health() {
        return Map.of("service", "persona-chat", "status", "UP", "model", settings.model,
                "contextCharLimit", settings.charLimit);
    }
    @PostMapping("/chat") public ChatService.Reply chat(@RequestBody ChatService.Request request) { return chat.chat(request); }
    @ExceptionHandler(ChatService.ChatFailure.class) ResponseEntity<?> failure(ChatService.ChatFailure e) {
        return ResponseEntity.status(e.status).body(Map.of("error", e.code));
    }
    @ExceptionHandler(HttpMessageNotReadableException.class) ResponseEntity<?> invalid() {
        return ResponseEntity.badRequest().body(Map.of("error", "INVALID_JSON"));
    }
}
