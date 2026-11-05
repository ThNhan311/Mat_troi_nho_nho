
package vn.edu.tdtu.fitcenter.security;

import tools.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.Map;
import vn.edu.tdtu.fitcenter.dto.error.ApiErrorResponse;
import vn.edu.tdtu.fitcenter.web.CorrelationIdFilter;

@Component
@RequiredArgsConstructor
public class RestAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final ObjectMapper objectMapper;

    @Override
    public void commence(
            HttpServletRequest request,
            HttpServletResponse response,
            AuthenticationException authException
    ) throws IOException {

        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        response.setHeader(CorrelationIdFilter.HEADER, CorrelationIdFilter.getOrCreate(request));

        objectMapper.writeValue(
                response.getOutputStream(),
                ApiErrorResponse.of(401, "ERR_UNAUTHORIZED", "Authentication is required",
                        Map.of(), request)
        );
    }
}
