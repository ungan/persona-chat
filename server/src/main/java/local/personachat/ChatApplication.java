package local.personachat;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.web.embedded.tomcat.TomcatServletWebServerFactory;
import org.springframework.boot.web.server.WebServerFactoryCustomizer;
import org.springframework.context.annotation.Bean;
import java.net.InetAddress;

@SpringBootApplication
public class ChatApplication {
    public static void main(String[] args) { SpringApplication.run(ChatApplication.class, args); }
    @Bean WebServerFactoryCustomizer<TomcatServletWebServerFactory> loopbackOnly(ChatSettings settings) {
        return factory -> {
            try { factory.setAddress(InetAddress.getByName("127.0.0.1")); factory.setPort(settings.port); }
            catch (Exception e) { throw new IllegalStateException(e); }
        };
    }
}
