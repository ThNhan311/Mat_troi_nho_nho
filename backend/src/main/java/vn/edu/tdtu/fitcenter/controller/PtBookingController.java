package vn.edu.tdtu.fitcenter.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import vn.edu.tdtu.fitcenter.domain.enums.BookingStatus;
import vn.edu.tdtu.fitcenter.dto.booking.BookingResponse;
import vn.edu.tdtu.fitcenter.service.BookingQueryService;

import java.time.OffsetDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/v1/pt/bookings")
@RequiredArgsConstructor
public class PtBookingController {
    private final BookingQueryService bookingQueryService;

    @GetMapping
    public List<BookingResponse> getMyBookings(
            Authentication authentication,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to,
            @RequestParam(required = false) String status) {
        BookingStatus bookingStatus = status == null ? null : BookingStatus.valueOf(status);
        return bookingQueryService.getMyPtBookings(authentication.getName(), from, to, bookingStatus);
    }
}
