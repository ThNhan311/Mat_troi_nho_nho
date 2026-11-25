package vn.edu.tdtu.fitcenter.controller;

import lombok.RequiredArgsConstructor;
import jakarta.validation.Valid;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import vn.edu.tdtu.fitcenter.dto.booking.BookingPolicyResponse;
import vn.edu.tdtu.fitcenter.dto.booking.BookingPolicyWriteRequest;
import vn.edu.tdtu.fitcenter.service.BookingPolicyService;
import vn.edu.tdtu.fitcenter.service.BookingPolicyWriteService;

@RestController
@RequestMapping("/api/v1/admin/booking-policy")
@RequiredArgsConstructor
public class AdminBookingPolicyController {
    private final BookingPolicyService service;
    private final BookingPolicyWriteService writeService;

    @GetMapping
    public BookingPolicyResponse getEffectivePolicy() {
        return service.getEffectivePolicy();
    }

    @PutMapping
    public BookingPolicyResponse update(Authentication auth, @Valid @RequestBody BookingPolicyWriteRequest request) {
        return writeService.update(auth.getName(), request);
    }
}
