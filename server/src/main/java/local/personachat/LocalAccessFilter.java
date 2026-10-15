package local.personachat;

import jakarta.servlet.*;
import jakarta.servlet.http.*;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

@Component
public final class LocalAccessFilter extends OncePerRequestFilter {
    private final ChatSettings settings;
    public LocalAccessFilter(ChatSettings settings) { this.settings = settings; }
    @Override protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String token = req.getHeader("X-Chat-Token");
        if (req.getHeader("Origin") != null || token == null || !MessageDigest.isEqual(
                token.getBytes(StandardCharsets.UTF_8), settings.token.getBytes(StandardCharsets.UTF_8))) {
            reject(res, 403, "LOCAL_ACCESS_DENIED"); return;
        }
        if (req.getContentLengthLong() > 1048576) { reject(res, 413, "REQUEST_TOO_LARGE"); return; }
        chain.doFilter(req, res);
    }
    private static void reject(HttpServletResponse res, int status, String code) throws IOException {
        res.setStatus(status); res.setContentType("application/json;charset=UTF-8");
        res.getWriter().write("{\"error\":\"" + code + "\"}");
    }
}
