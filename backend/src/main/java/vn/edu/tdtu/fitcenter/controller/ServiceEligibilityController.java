package vn.edu.tdtu.fitcenter.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import vn.edu.tdtu.fitcenter.dto.booking.ServiceEligibilityResponse;
import vn.edu.tdtu.fitcenter.service.ServiceEligibilityService;

import java.util.UUID;

@RestController
@RequiredArgsConstructor
public class ServiceEligibilityController {
    private final ServiceEligibilityService service;

    @GetMapping("/api/v1/pt/bookings/{id}/service-eligibility")
    public ResponseEntity<ServiceEligibilityResponse> check(Authentication auth, @PathVariable UUID id) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(service.check(auth.getName(), id));
    }
}
