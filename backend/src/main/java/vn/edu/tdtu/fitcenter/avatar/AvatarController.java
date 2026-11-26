package vn.edu.tdtu.fitcenter.avatar;

import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.repository.PersonalTrainerRepository;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

import java.io.IOException;
import java.util.UUID;

/** "me" routes always use the signed-in account; there is no way to name another user. */
@RestController
@RequiredArgsConstructor
@ConditionalOnProperty(name = "fitcenter.avatar.enabled", havingValue = "true")
public class AvatarController {
    private final AvatarStore store;
    private final UserRepository users;
    private final PersonalTrainerRepository trainers;

    @GetMapping("/api/v1/avatar/me")
    @PreAuthorize("hasAnyRole('MEMBER','PT')")
    public ResponseEntity<byte[]> mine(Authentication authentication) {
        return image(currentUser(authentication));
    }

    @PutMapping(value = "/api/v1/avatar/me", consumes = {MediaType.IMAGE_JPEG_VALUE, MediaType.IMAGE_PNG_VALUE})
    @PreAuthorize("hasAnyRole('MEMBER','PT')")
    public ResponseEntity<Void> replace(Authentication authentication, HttpServletRequest request) throws IOException {
        UUID user = currentUser(authentication);
        // Read at most one byte past the limit, whatever Content-Length claims.
        store.save(user, request.getInputStream().readNBytes(AvatarStore.MAX_BYTES + 1));
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/api/v1/avatar/me")
    @PreAuthorize("hasAnyRole('MEMBER','PT')")
    public ResponseEntity<Void> remove(Authentication authentication) {
        store.delete(currentUser(authentication));
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/api/v1/trainers/{ptId}/avatar")
    @PreAuthorize("hasRole('MEMBER')")
    public ResponseEntity<byte[]> trainer(@PathVariable UUID ptId) {
        return image(trainers.findByIdAndUser_Status(ptId, AccountStatus.ACTIVE)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Personal trainer not found"))
                .getUser().getId());
    }

    private UUID currentUser(Authentication authentication) {
        return users.findByEmailIgnoreCase(authentication.getName())
                .filter(user -> user.getStatus() == AccountStatus.ACTIVE)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.FORBIDDEN, "Account is not active"))
                .getId();
    }

    private ResponseEntity<byte[]> image(UUID user) {
        // 204 instead of 404: having no picture yet is normal.
        return store.load(user)
                .map(bytes -> ResponseEntity.ok().cacheControl(CacheControl.noStore()).contentType(MediaType.IMAGE_JPEG).body(bytes))
                .orElseGet(() -> ResponseEntity.noContent().build());
    }
}
