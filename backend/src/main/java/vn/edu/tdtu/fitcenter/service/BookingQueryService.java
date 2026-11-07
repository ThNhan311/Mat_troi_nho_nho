package vn.edu.tdtu.fitcenter.service;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import vn.edu.tdtu.fitcenter.domain.entity.Booking;
import vn.edu.tdtu.fitcenter.domain.entity.Member;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.BookingStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.dto.booking.BookingResponse;
import vn.edu.tdtu.fitcenter.repository.BookingRepository;
import vn.edu.tdtu.fitcenter.repository.MemberRepository;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

import java.time.OffsetDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BookingQueryService {
    private final UserRepository userRepository;
    private final MemberRepository memberRepository;
    private final BookingRepository bookingRepository;

    public List<BookingResponse> getMyBookings(
            String email, OffsetDateTime from, OffsetDateTime to, BookingStatus status) {
        if (from == null || to == null || !from.isBefore(to)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "'from' must be earlier than 'to'");
        }

        User user = userRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new BadCredentialsException("User not found"));
        if (user.getRole() != Role.MEMBER || user.getStatus() != AccountStatus.ACTIVE) {
            throw new AccessDeniedException("Only active members can access this resource");
        }

        Member member = memberRepository.findByUser_Id(user.getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Member profile not found"));

        List<Booking> bookings = status == null
                ? bookingRepository.findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                        member.getId(), from, to)
                : bookingRepository.findByMemberIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                        member.getId(), status, from, to);

        return bookings.stream().map(this::toResponse).toList();
    }

    private BookingResponse toResponse(Booking booking) {
        return new BookingResponse(booking.getId(), booking.getMemberId(), booking.getPtId(),
                booking.getSlotId(), booking.getStartAt(), booking.getEndAt(), booking.getStatus().name(),
                booking.getCancelledBy(), booking.getCancelReason(), booking.getCancelledAt(),
                booking.getCompletedAt());
    }
}
