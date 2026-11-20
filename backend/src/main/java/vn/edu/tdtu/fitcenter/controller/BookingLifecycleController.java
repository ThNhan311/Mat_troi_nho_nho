package vn.edu.tdtu.fitcenter.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vn.edu.tdtu.fitcenter.dto.booking.BookingResponse;
import vn.edu.tdtu.fitcenter.dto.booking.PtCancellationRequest;
import vn.edu.tdtu.fitcenter.service.BookingLifecycleService;

import java.util.UUID;

@RestController
@RequiredArgsConstructor
public class BookingLifecycleController {
    private final BookingLifecycleService service;

    @PostMapping("/api/v1/bookings/{id}/cancel")
    public BookingResponse memberCancel(Authentication auth, @PathVariable UUID id) {
        return service.memberCancel(auth.getName(), id);
    }

    @PostMapping("/api/v1/pt/bookings/{id}/cancel")
    public BookingResponse ptCancel(Authentication auth, @PathVariable UUID id, @RequestBody PtCancellationRequest request) {
        return service.ptCancel(auth.getName(), id, request.reason());
    }

    @PostMapping("/api/v1/pt/bookings/{id}/complete")
    public BookingResponse complete(Authentication auth, @PathVariable UUID id) {
        return service.complete(auth.getName(), id);
    }
}
