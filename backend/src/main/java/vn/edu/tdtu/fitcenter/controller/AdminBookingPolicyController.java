package vn.edu.tdtu.fitcenter.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import vn.edu.tdtu.fitcenter.dto.booking.BookingPolicyResponse;
import vn.edu.tdtu.fitcenter.service.BookingPolicyService;

@RestController
@RequestMapping("/api/v1/admin/booking-policy")
@RequiredArgsConstructor
public class AdminBookingPolicyController {
    private final BookingPolicyService service;

    @GetMapping
    public BookingPolicyResponse getEffectivePolicy() {
        return service.getEffectivePolicy();
    }
}
