package vn.edu.tdtu.fitcenter.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vn.edu.tdtu.fitcenter.dto.booking.BookingCreateRequest;
import vn.edu.tdtu.fitcenter.dto.booking.BookingResponse;
import vn.edu.tdtu.fitcenter.service.BookingCreateService;

@RestController
@RequestMapping("/api/v1/bookings")
@RequiredArgsConstructor
public class BookingCreateController {
    private final BookingCreateService service;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public BookingResponse create(Authentication authentication, @Valid @RequestBody BookingCreateRequest request) {
        return service.create(authentication.getName(), request);
    }
}
