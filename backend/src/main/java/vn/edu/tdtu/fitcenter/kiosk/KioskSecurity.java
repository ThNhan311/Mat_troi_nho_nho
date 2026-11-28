package vn.edu.tdtu.fitcenter.kiosk;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.filter.OncePerRequestFilter;
import vn.edu.tdtu.fitcenter.security.RestAccessDeniedHandler;
import vn.edu.tdtu.fitcenter.security.RestAuthenticationEntryPoint;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.List;
import java.util.Set;

/** Its own chain, so the shared security rules stay untouched. */
@Configuration
@ConditionalOnProperty(name = "fitcenter.kiosk.enabled", havingValue = "true")
public class KioskSecurity {
    static final String HEADER = "X-Kiosk-Token";
    static final int MIN_TOKEN_LENGTH = 24;
    private static final Set<String> LOOPBACK = Set.of("127.0.0.1", "::1", "0:0:0:0:0:0:0:1");

    static boolean allowed(String remoteAddress, String provided, String expected) {
        return LOOPBACK.contains(remoteAddress) && provided != null
                && MessageDigest.isEqual(provided.getBytes(StandardCharsets.UTF_8),
                        expected.getBytes(StandardCharsets.UTF_8));
    }

    @Bean
    @Order(2)
    SecurityFilterChain kioskChain(HttpSecurity http, @Value("${fitcenter.kiosk.token:}") String token,
            RestAuthenticationEntryPoint unauthorized, RestAccessDeniedHandler forbidden) throws Exception {
        if (token.length() < MIN_TOKEN_LENGTH) {
            throw new IllegalStateException(
                    "fitcenter.kiosk.token must be at least " + MIN_TOKEN_LENGTH + " characters");
        }
        var filter = new OncePerRequestFilter() {
            @Override
            protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                    FilterChain chain) throws ServletException, IOException {
                if (allowed(request.getRemoteAddr(), request.getHeader(HEADER), token)) {
                    SecurityContextHolder.getContext().setAuthentication(UsernamePasswordAuthenticationToken
                            .authenticated("face-kiosk", null,
                                    List.of(new SimpleGrantedAuthority("ROLE_FACE_KIOSK"))));
                }
                chain.doFilter(request, response);
            }
        };
        return http.securityMatcher("/api/v1/kiosk/**")
                .csrf(x -> x.disable())
                .sessionManagement(x -> x.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .exceptionHandling(x -> x.authenticationEntryPoint(unauthorized).accessDeniedHandler(forbidden))
                .authorizeHttpRequests(x -> x.anyRequest().hasRole("FACE_KIOSK"))
                .addFilterBefore(filter, UsernamePasswordAuthenticationFilter.class)
                .build();
    }
}
