package vn.edu.tdtu.fitcenter.dto.error;

import jakarta.servlet.http.HttpServletRequest;
import vn.edu.tdtu.fitcenter.web.CorrelationIdFilter;
import java.time.Instant;
import java.util.Map;

// status/message remain at the top level for existing prototype clients.
public record ApiErrorResponse(boolean success, ErrorDetail error, Instant timestamp,
                               int status, String message) {
    public record ErrorDetail(String code, String message, Map<String, Object> details,
                              String correlationId) {}

    public static ApiErrorResponse of(int status, String code, String message,
                                      Map<String, Object> details, HttpServletRequest request) {
        return new ApiErrorResponse(false,
                new ErrorDetail(code, message, details, CorrelationIdFilter.getOrCreate(request)),
                Instant.now(), status, message);
    }
}
