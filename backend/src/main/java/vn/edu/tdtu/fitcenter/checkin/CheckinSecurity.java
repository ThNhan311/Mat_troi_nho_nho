package vn.edu.tdtu.fitcenter.checkin;

import jakarta.servlet.*;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.*;
import org.springframework.context.annotation.*;
import org.springframework.core.annotation.Order;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.filter.OncePerRequestFilter;
import tools.jackson.databind.ObjectMapper;
import vn.edu.tdtu.fitcenter.dto.error.ApiErrorResponse;
import vn.edu.tdtu.fitcenter.web.CorrelationIdFilter;
import vn.edu.tdtu.fitcenter.security.RestAuthenticationEntryPoint;
import vn.edu.tdtu.fitcenter.security.RestAccessDeniedHandler;

@Configuration
public class CheckinSecurity {
    @Bean @Order(1)
    SecurityFilterChain checkinChain(HttpSecurity http,FaceTestAdapter adapter,ObjectMapper json,
            RestAuthenticationEntryPoint unauthorized,RestAccessDeniedHandler forbidden) throws Exception {
        var filter=new OncePerRequestFilter() {
            protected void doFilterInternal(HttpServletRequest request,HttpServletResponse response,FilterChain chain) throws ServletException,IOException {
                response.setHeader("Cache-Control","no-store");
                if(!adapter.enabled()) {
                    response.setStatus(503);response.setContentType(MediaType.APPLICATION_JSON_VALUE);response.setCharacterEncoding("UTF-8");
                    response.setHeader(CorrelationIdFilter.HEADER,CorrelationIdFilter.getOrCreate(request));
                    json.writeValue(response.getOutputStream(),ApiErrorResponse.of(503,"ERR_CHECKIN_UNAVAILABLE","Face check-in is unavailable in this environment",Map.of(),request));return;
                }
                String kiosk=request.getHeader("X-Kiosk-Id"), token=request.getHeader("X-Kiosk-Token");
                if(Set.of("127.0.0.1","::1","0:0:0:0:0:0:0:1").contains(request.getRemoteAddr())&&adapter.authenticate(kiosk,token)) {
                    SecurityContextHolder.getContext().setAuthentication(UsernamePasswordAuthenticationToken.authenticated(kiosk,null,List.of(new SimpleGrantedAuthority("ROLE_CHECKIN_KIOSK"))));
                }
                chain.doFilter(request,response);
            }
        };
        return http.securityMatcher("/api/v1/check-ins/face").csrf(x->x.disable())
            .sessionManagement(x->x.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .exceptionHandling(x->x.authenticationEntryPoint(unauthorized).accessDeniedHandler(forbidden))
            .authorizeHttpRequests(x->x.requestMatchers(org.springframework.http.HttpMethod.POST,"/api/v1/check-ins/face").hasRole("CHECKIN_KIOSK").anyRequest().denyAll())
            .addFilterBefore(filter,UsernamePasswordAuthenticationFilter.class).build();
    }
}
