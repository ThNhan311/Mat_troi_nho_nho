package vn.edu.tdtu.fitcenter.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import vn.edu.tdtu.fitcenter.dto.booking.BookedMember;
import vn.edu.tdtu.fitcenter.service.BookingQueryService;

import java.util.List;

/** Read only and always about the signed-in trainer; there is no way to name another one. */
@RestController
@RequiredArgsConstructor
public class PtBookedMemberController {
    private final BookingQueryService bookingQueryService;

    @GetMapping("/api/v1/pt/booked-members")
    public List<BookedMember> mine(Authentication authentication) {
        return bookingQueryService.getMyBookedMembers(authentication.getName());
    }
}
