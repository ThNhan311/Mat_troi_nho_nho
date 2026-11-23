package vn.edu.tdtu.fitcenter.exception;

import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.ConcurrencyFailureException;
import org.springframework.dao.QueryTimeoutException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.ServletWebRequest;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;
import vn.edu.tdtu.fitcenter.dto.error.ApiErrorResponse;
import java.util.LinkedHashMap;
import java.util.Map;

@Slf4j
@RestControllerAdvice
public class ApiExceptionHandler extends ResponseEntityExceptionHandler {
    @ExceptionHandler(vn.edu.tdtu.fitcenter.membershipinitial.InitialActivationFailure.class)
    ResponseEntity<Object> initial(vn.edu.tdtu.fitcenter.membershipinitial.InitialActivationFailure ex, HttpServletRequest request) {
        var response=error(ex.status,ex.code,ex.getMessage(),Map.of(),request);
        return ResponseEntity.status(ex.status).headers(response.getHeaders()).cacheControl(org.springframework.http.CacheControl.noStore()).body(response.getBody());
    }
    @ExceptionHandler(vn.edu.tdtu.fitcenter.activation.ActivationFailure.class)
    ResponseEntity<Object> activation(vn.edu.tdtu.fitcenter.activation.ActivationFailure ex, HttpServletRequest request) {
        var response = error(ex.getStatus(), ex.getCode(), ex.getMessage(), Map.of(), request);
        return ResponseEntity.status(ex.getStatus()).headers(response.getHeaders()).cacheControl(org.springframework.http.CacheControl.noStore()).body(response.getBody());
    }

    @ExceptionHandler(BookingConflictException.class)
    ResponseEntity<Object> bookingConflict(BookingConflictException ex, HttpServletRequest request) {
        return error(409, ex.getCode(), ex.getMessage(), Map.of(), request);
    }

    @ExceptionHandler(BookingPolicyNotFoundException.class)
    ResponseEntity<Object> bookingPolicyNotFound(BookingPolicyNotFoundException ex, HttpServletRequest request) {
        return error(404, BookingPolicyNotFoundException.CODE, ex.getMessage(), Map.of(), request);
    }

    @ExceptionHandler(AuthenticationException.class)
    ResponseEntity<Object> authentication(AuthenticationException ex, HttpServletRequest request) {
        return error(401, "ERR_UNAUTHORIZED", "Invalid credentials or authentication required", Map.of(), request);
    }

    @ExceptionHandler(AccessDeniedException.class)
    ResponseEntity<Object> forbidden(AccessDeniedException ex, HttpServletRequest request) {
        return error(403, "ERR_FORBIDDEN", "You do not have permission to access this resource", Map.of(), request);
    }

    @ExceptionHandler(IllegalArgumentException.class)
    ResponseEntity<Object> invalid(IllegalArgumentException ex, HttpServletRequest request) {
        return error(400, "ERR_VALIDATION", "Invalid request", Map.of(), request);
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    ResponseEntity<Object> conflict(DataIntegrityViolationException ex, HttpServletRequest request) {
        return error(409, "ERR_CONFLICT", "The request conflicts with existing data", Map.of(), request);
    }

    @ExceptionHandler({ConcurrencyFailureException.class, QueryTimeoutException.class})
    ResponseEntity<Object> concurrentWrite(Exception ex, HttpServletRequest request) {
        return error(409, "ERR_CONFLICT", "Concurrent change; refresh the resource and retry", Map.of(), request);
    }

    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(MethodArgumentNotValidException ex,
            HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        Map<String, Object> fields = new LinkedHashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(e -> fields.putIfAbsent(e.getField(), e.getDefaultMessage()));
        return error(400, "ERR_VALIDATION", "Request validation failed", fields,
                ((ServletWebRequest) request).getRequest());
    }

    @Override
    protected ResponseEntity<Object> handleExceptionInternal(Exception ex, Object body, HttpHeaders headers,
            HttpStatusCode status, WebRequest request) {
        HttpStatus known = HttpStatus.resolve(status.value());
        String message = ex instanceof ResponseStatusException rse && rse.getReason() != null
                ? rse.getReason() : known != null ? known.getReasonPhrase() : "Request failed";
        String code = switch (status.value()) {
            case 400 -> "ERR_VALIDATION";
            case 404 -> "ERR_NOT_FOUND";
            case 409 -> "ERR_CONFLICT";
            default -> "ERR_HTTP_" + status.value();
        };
        HttpServletRequest servletRequest = ((ServletWebRequest) request).getRequest();
        HttpHeaders responseHeaders = new HttpHeaders();
        responseHeaders.putAll(headers);
        responseHeaders.set("X-Correlation-Id", vn.edu.tdtu.fitcenter.web.CorrelationIdFilter.getOrCreate(servletRequest));
        return new ResponseEntity<>(ApiErrorResponse.of(status.value(), code, message, Map.of(), servletRequest),
                responseHeaders, status);
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<Object> unexpected(Exception ex, HttpServletRequest request) {
        String id = vn.edu.tdtu.fitcenter.web.CorrelationIdFilter.getOrCreate(request);
        log.error("Unhandled request failure correlationId={}", id, ex);
        return error(500, "ERR_INTERNAL", "An unexpected error occurred", Map.of(), request);
    }

    private ResponseEntity<Object> error(int status, String code, String message,
            Map<String, Object> details, HttpServletRequest request) {
        return ResponseEntity.status(status)
                .header("X-Correlation-Id", vn.edu.tdtu.fitcenter.web.CorrelationIdFilter.getOrCreate(request))
                .body(ApiErrorResponse.of(status, code, message, details, request));
    }
}
