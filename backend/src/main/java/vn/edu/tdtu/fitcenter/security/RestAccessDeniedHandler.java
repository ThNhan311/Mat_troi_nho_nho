
package vn.edu.tdtu.fitcenter.security;

import tools.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.Map;
import vn.edu.tdtu.fitcenter.dto.error.ApiErrorResponse;
import vn.edu.tdtu.fitcenter.web.CorrelationIdFilter;

@Component
@RequiredArgsConstructor
public class RestAccessDeniedHandler implements AccessDeniedHandler {

    private final ObjectMapper objectMapper;

    @Override
    public void handle(
            HttpServletRequest request,
            HttpServletResponse response,
            AccessDeniedException accessDeniedException
    ) throws IOException {

        response.setStatus(HttpServletResponse.SC_FORBIDDEN);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        response.setHeader(CorrelationIdFilter.HEADER, CorrelationIdFilter.getOrCreate(request));

        objectMapper.writeValue(
                response.getOutputStream(),
                ApiErrorResponse.of(403, "ERR_FORBIDDEN",
                        "You do not have permission to access this resource", Map.of(), request)
        );
    }
}
