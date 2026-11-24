package vn.edu.tdtu.fitcenter.checkin;

import jakarta.validation.Valid;
import java.time.OffsetDateTime;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.*;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
public class CheckinController {
    private final CheckinService service;
    public CheckinController(CheckinService service) { this.service=service; }
    @PostMapping("/api/v1/check-ins/face")
    public ResponseEntity<?> checkin(Authentication principal,@Valid @RequestBody CheckinRequest request) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(service.checkin(principal.getName(),request));
    }
    @GetMapping("/api/v1/attendance/me")
    public ResponseEntity<?> history(Authentication principal,
            @RequestParam @DateTimeFormat(iso=DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam @DateTimeFormat(iso=DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(service.history(principal.getName(),from,to));
    }
}
