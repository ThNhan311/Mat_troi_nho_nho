package vn.edu.tdtu.fitcenter.password;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequiredArgsConstructor
public class PasswordController {
    private final PasswordChangeService changes;
    private final PasswordResetService resets;

    // toString is overridden so a password or code can never reach a log line.
    public record Change(@NotBlank @Size(max = 200) String currentPassword,
            @NotBlank @Size(max = 200) String newPassword) {
        @Override
        public String toString() {
            return "Change[redacted]";
        }
    }

    public record Ask(@NotBlank @Email @Size(max = 255) String email) {
    }

    public record Verify(@NotBlank @Email @Size(max = 255) String email,
            @NotBlank @Pattern(regexp = "[0-9]{6}") String otp) {
        @Override
        public String toString() {
            return "Verify[redacted]";
        }
    }

    public record NewPassword(@NotBlank @Size(max = 100) String verificationToken,
            @NotBlank @Size(max = 200) String password) {
        @Override
        public String toString() {
            return "NewPassword[redacted]";
        }
    }

    @PostMapping("/api/v1/profile/password")
    @PreAuthorize("hasAnyRole('MEMBER','PT')")
    public ResponseEntity<Map<String, Object>> change(Authentication authentication,
            @Valid @RequestBody Change request) {
        changes.change(authentication.getName(), request.currentPassword(), request.newPassword());
        return body(HttpStatus.OK, Map.of("status", "CHANGED"));
    }

    @PostMapping("/api/v1/auth/password-reset/request-otp")
    public ResponseEntity<Map<String, Object>> ask(@Valid @RequestBody Ask request) {
        resets.request(request.email());
        return body(HttpStatus.ACCEPTED, Map.of("expiresInSeconds", PasswordResetService.CODE_SECONDS));
    }

    @PostMapping("/api/v1/auth/password-reset/verify-otp")
    public ResponseEntity<Map<String, Object>> verify(@Valid @RequestBody Verify request) {
        return body(HttpStatus.OK, Map.of(
                "verificationToken", resets.verify(request.email(), request.otp()),
                "expiresInSeconds", PasswordResetService.CODE_SECONDS));
    }

    @PostMapping("/api/v1/auth/password-reset/password")
    public ResponseEntity<Map<String, Object>> reset(@Valid @RequestBody NewPassword request) {
        resets.reset(request.verificationToken(), request.password());
        return body(HttpStatus.OK, Map.of("status", "RESET"));
    }

    private static ResponseEntity<Map<String, Object>> body(HttpStatus status, Map<String, Object> value) {
        return ResponseEntity.status(status).cacheControl(CacheControl.noStore()).body(value);
    }
}
