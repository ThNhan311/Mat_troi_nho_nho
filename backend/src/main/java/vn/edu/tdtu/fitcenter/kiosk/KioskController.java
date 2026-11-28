package vn.edu.tdtu.fitcenter.kiosk;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Links the face kiosk to member accounts, for local trials. The kiosk does the
 * recognition itself and there is no liveness check, so an answer here must not
 * be used to open a real door. Visits are recorded under their own kiosk id.
 */
@RestController
@RequiredArgsConstructor
@ConditionalOnProperty(name = "fitcenter.kiosk.enabled", havingValue = "true")
public class KioskController {
    private final KioskDesk desk;
    private final KioskMembers members;
    private final KioskFaces faces;
    private final KioskAttendance attendance;
    private final KioskLauncher launcher;

    public record EnrollmentRequest(@NotNull UUID memberId) {
    }

    public record EnrollmentResult(@NotNull KioskDesk.Status outcome) {
    }

    // Front desk (signed-in Admin).

    @GetMapping("/api/v1/admin/kiosk")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Map<String, Object>> desk() {
        var body = new LinkedHashMap<String, Object>();
        body.put("enrollment", desk.current());
        body.put("recent", desk.recent());
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(body);
    }

    @PostMapping("/api/v1/admin/kiosk/enrollment")
    @PreAuthorize("hasRole('ADMIN')")
    public KioskDesk.Enrollment start(@Valid @RequestBody EnrollmentRequest request) {
        return desk.request(request.memberId(), members.nameForEnrollment(request.memberId()));
    }

    @DeleteMapping("/api/v1/admin/kiosk/enrollment")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> cancel() {
        desk.cancel();
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/api/v1/admin/kiosk/open")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> open() {
        launcher.open();
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/api/v1/admin/kiosk/faces/{profileId}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> removeFace(@PathVariable UUID profileId) {
        faces.requestRemoval(profileId);
        return ResponseEntity.noContent().build();
    }

    // Kiosk screen (kiosk token, this computer only; see KioskSecurity).

    @GetMapping("/api/v1/kiosk/removals")
    @PreAuthorize("hasRole('FACE_KIOSK')")
    public ResponseEntity<java.util.List<UUID>> removals() {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(faces.pendingRemovals());
    }

    @PostMapping("/api/v1/kiosk/removals/{profileId}/done")
    @PreAuthorize("hasRole('FACE_KIOSK')")
    public ResponseEntity<Void> removed(@PathVariable UUID profileId) {
        faces.removed(profileId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/api/v1/kiosk/enrollment")
    @PreAuthorize("hasRole('FACE_KIOSK')")
    public ResponseEntity<KioskDesk.Enrollment> waiting() {
        var current = desk.current();
        return current == null || current.status() != KioskDesk.Status.WAITING
                ? ResponseEntity.noContent().build()
                : ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(current);
    }

    @PostMapping("/api/v1/kiosk/enrollment/{requestId}/result")
    @PreAuthorize("hasRole('FACE_KIOSK')")
    public ResponseEntity<Void> result(@PathVariable UUID requestId, @Valid @RequestBody EnrollmentResult result) {
        if (result.outcome() != KioskDesk.Status.SUCCESS && result.outcome() != KioskDesk.Status.DUPLICATE
                && result.outcome() != KioskDesk.Status.FAILED) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported outcome");
        }
        var waiting = desk.current();
        if (!desk.finish(requestId, result.outcome())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "This request is no longer waiting");
        }
        if (result.outcome() == KioskDesk.Status.SUCCESS) {
            faces.enrolled(waiting.memberId());
        }
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/api/v1/kiosk/members/{memberId}/scan")
    @PreAuthorize("hasRole('FACE_KIOSK')")
    public ResponseEntity<KioskMembers.Card> scan(@PathVariable UUID memberId) {
        var card = members.card(memberId);
        faces.seen(memberId);
        desk.scanned(memberId, card.fullName(), card.role().name(), card.membershipValid());
        if (card.membershipValid()) {
            attendance.record(memberId, card.role());
        }
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(card);
    }
}
