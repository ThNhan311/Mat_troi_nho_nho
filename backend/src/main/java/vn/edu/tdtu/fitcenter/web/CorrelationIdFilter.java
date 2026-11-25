package vn.edu.tdtu.fitcenter.web;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import java.io.IOException;
import java.util.UUID;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class CorrelationIdFilter extends OncePerRequestFilter {
    public static final String HEADER = "X-Correlation-Id";
    public static final String ATTRIBUTE = CorrelationIdFilter.class.getName() + ".id";

    public static String getOrCreate(HttpServletRequest request) {
        Object existing = request.getAttribute(ATTRIBUTE);
        if (existing instanceof String id) return id;
        String supplied = request.getHeader(HEADER);
        String id = supplied != null && supplied.matches("[A-Za-z0-9._-]{1,64}")
                ? supplied : UUID.randomUUID().toString();
        request.setAttribute(ATTRIBUTE, id);
        return id;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        String id = getOrCreate(request);
        response.setHeader(HEADER, id);
        String previous = MDC.get("correlationId");
        MDC.put("correlationId", id);
        try {
            chain.doFilter(request, response);
        } finally {
            if (previous == null) MDC.remove("correlationId");
            else MDC.put("correlationId", previous);
        }
    }
}
