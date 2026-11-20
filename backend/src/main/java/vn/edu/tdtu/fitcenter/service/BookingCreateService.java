package vn.edu.tdtu.fitcenter.service;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.web.server.ResponseStatusException;
import vn.edu.tdtu.fitcenter.domain.entity.Booking;
import vn.edu.tdtu.fitcenter.domain.enums.*;
import vn.edu.tdtu.fitcenter.dto.booking.BookingCreateRequest;
import vn.edu.tdtu.fitcenter.dto.booking.BookingResponse;
import vn.edu.tdtu.fitcenter.exception.BookingConflictException;
import vn.edu.tdtu.fitcenter.repository.*;

import java.time.Clock;
import java.time.ZoneOffset;

@Service
@RequiredArgsConstructor
public class BookingCreateService {
    private final UserRepository users;
    private final MemberRepository members;
    private final MembershipRepository memberships;
    private final PersonalTrainerRepository trainers;
    private final AvailabilitySlotRepository slots;
    private final BookingRepository bookings;
    private final BookingPolicyService policies;
    private final BookingEligibilityValidator validator;
    private final Clock clock;

    @Transactional(isolation = Isolation.READ_COMMITTED, timeout = 10)
    public BookingResponse create(String email, BookingCreateRequest request) {
        var user = users.findByEmailIgnoreCase(email).orElseThrow(() -> new BadCredentialsException("User not found"));
        if (user.getRole() != Role.MEMBER || user.getStatus() != AccountStatus.ACTIVE) {
            throw new AccessDeniedException("Only ACTIVE members can create bookings");
        }
        // Observe the selection before waiting: a concurrent in-place PATCH must not silently change its times.
        long selectedVersion = slots.findOwnedVersion(request.slotId(), request.ptId())
                .orElseThrow(() -> notFound("PT/slot pair not found"));
        var member = members.findByUserIdForUpdate(user.getId()).orElseThrow(() -> notFound("Member profile not found"));
        var membership = memberships.findByMember_IdAndStatusNot(member.getId(), MembershipStatus.CANCELLED).orElse(null);
        var trainer = trainers.findByIdForUpdate(request.ptId()).orElseThrow(() -> notFound("PT not found"));
        var slot = slots.findOwnedByIdForUpdate(request.slotId(), trainer.getId()).orElseThrow(() -> notFound("Slot not found"));

        // Fresh scalar queries recheck accounts after waits, rather than relying on entity snapshots.
        if (!users.existsByIdAndRoleAndStatus(user.getId(), Role.MEMBER, AccountStatus.ACTIVE)) {
            throw new AccessDeniedException("Member account is no longer ACTIVE");
        }
        if (!users.existsByIdAndRoleAndStatus(trainer.getUser().getId(), Role.PT, AccountStatus.ACTIVE)) {
            throw notFound("Active PT not found");
        }
        if (slot.getVersion() != selectedVersion || slot.getStatus() != SlotStatus.AVAILABLE
                || bookings.existsBySlotIdAndStatus(slot.getId(), BookingStatus.CONFIRMED)) {
            throw new BookingConflictException("ERR_SLOT_NO_LONGER_AVAILABLE", "Slot changed or is no longer available");
        }
        var now = clock.instant();
        var start = slot.getStartAt().toInstant();
        var end = slot.getEndAt().toInstant();
        validator.validateMembership(membership, start, end, now);
        var policy = policies.getEffectivePolicyAt(now);
        validator.validateWindow(policy, start, end, now);
        validator.validateFutureCount(policy, bookings.countFutureConfirmed(member.getId(), now.atOffset(ZoneOffset.UTC)));
        if (bookings.overlapsMember(member.getId(), slot.getStartAt(), slot.getEndAt())
                || bookings.overlapsConfirmed(trainer.getId(), slot.getStartAt(), slot.getEndAt())) {
            throw new BookingConflictException("ERR_BOOKING_OVERLAP", "Session overlaps a CONFIRMED booking");
        }
        slot.setStatus(SlotStatus.BOOKED);
        slots.flush();
        var booking = bookings.saveAndFlush(Booking.builder().memberId(member.getId()).ptId(trainer.getId())
                .slotId(slot.getId()).startAt(slot.getStartAt()).endAt(slot.getEndAt()).status(BookingStatus.CONFIRMED).build());
        return new BookingResponse(booking.getId(), booking.getMemberId(), booking.getPtId(), booking.getSlotId(),
                booking.getStartAt().withOffsetSameInstant(ZoneOffset.UTC), booking.getEndAt().withOffsetSameInstant(ZoneOffset.UTC),
                booking.getStatus().name(), null, null, null, null);
    }

    private static ResponseStatusException notFound(String message) {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, message);
    }
}
