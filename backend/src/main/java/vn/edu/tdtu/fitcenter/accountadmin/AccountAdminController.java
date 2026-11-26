package vn.edu.tdtu.fitcenter.accountadmin;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vn.edu.tdtu.fitcenter.dto.account.PhoneNumbers;

import java.util.List;
import java.util.UUID;

/** Under /api/v1/admin/**, so only ADMIN reaches these routes. */
@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
public class AccountAdminController {
    private final AccountAdminService service;

    public record Update(@NotBlank @Size(max = 150) String fullName, @NotBlank @Email @Size(max = 255) String email,
            @Pattern(regexp = PhoneNumbers.PATTERN) String phone) {
    }

    @GetMapping("/account-details")
    public ResponseEntity<List<AccountAdminService.Detail>> details(Authentication admin) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(service.details(admin.getName()));
    }

    @PatchMapping("/accounts/{userId}")
    public ResponseEntity<Void> update(Authentication admin, @PathVariable UUID userId,
            @Valid @RequestBody Update request) {
        service.update(admin.getName(), userId, request.fullName(), request.email(), request.phone());
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/accounts/{userId}")
    public ResponseEntity<Void> delete(Authentication admin, @PathVariable UUID userId) {
        var deleted = service.delete(admin.getName(), userId);
        service.cleanUp(deleted);
        return ResponseEntity.noContent().build();
    }
}
