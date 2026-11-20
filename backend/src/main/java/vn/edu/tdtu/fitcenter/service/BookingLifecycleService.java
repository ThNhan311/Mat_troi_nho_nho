package vn.edu.tdtu.fitcenter.service;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import vn.edu.tdtu.fitcenter.domain.entity.AvailabilitySlot;
import vn.edu.tdtu.fitcenter.domain.entity.Booking;
import vn.edu.tdtu.fitcenter.domain.enums.*;
import vn.edu.tdtu.fitcenter.dto.booking.BookingResponse;
import vn.edu.tdtu.fitcenter.exception.BookingConflictException;
import vn.edu.tdtu.fitcenter.repository.*;

import java.time.Clock;
import java.time.ZoneOffset;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional(isolation = Isolation.READ_COMMITTED, timeout = 10)
public class BookingLifecycleService {
    private final UserRepository users;
    private final MemberRepository members;
    private final PersonalTrainerRepository trainers;
    private final AvailabilitySlotRepository slots;
    private final BookingRepository bookings;
    private final BookingPolicyService policies;
    private final BookingLifecycleValidator validator;
    private final Clock clock;

    public BookingResponse memberCancel(String email, UUID id) {
        var locked = lock(email, id, Role.MEMBER);
        var booking = locked.booking();
        var now = clock.instant();
        var policy = policies.getEffectivePolicyAt(now);
        validator.memberCancellation(booking.getStartAt().toInstant(), now, policy.cancelDeadlineHours());
        booking.setStatus(BookingStatus.CANCELLED);
        booking.setCancelledBy("MEMBER");
        booking.setCancelReason(null);
        booking.setCancelledAt(now.atOffset(ZoneOffset.UTC));
        return persist(locked, booking.getStartAt().toInstant().isAfter(now) ? SlotStatus.AVAILABLE : SlotStatus.DISABLED);
    }

    public BookingResponse ptCancel(String email, UUID id, String reason) {
        validator.reason(reason);
        var locked = lock(email, id, Role.PT);
        var booking = locked.booking();
        var now = clock.instant(); // Decide after waiting for all locks, never at request arrival.
        validator.ptCancellation(booking.getStartAt().toInstant(), now);
        booking.setStatus(BookingStatus.CANCELLED);
        booking.setCancelledBy("PT");
        booking.setCancelReason(reason);
        booking.setCancelledAt(now.atOffset(ZoneOffset.UTC));
        return persist(locked, SlotStatus.DISABLED);
    }

    public BookingResponse complete(String email, UUID id) {
        var locked = lock(email, id, Role.PT);
        var booking = locked.booking();
        var now = clock.instant();
        validator.completion(booking.getEndAt().toInstant(), now);
        booking.setStatus(BookingStatus.COMPLETED);
        booking.setCompletedAt(now.atOffset(ZoneOffset.UTC));
        booking.setCancelReason(null);
        return persist(locked, SlotStatus.DISABLED);
    }

    private record Locked(Booking booking, AvailabilitySlot slot) {}

    private Locked lock(String email, UUID id, Role role) {
        var user = users.findByEmailIgnoreCase(email).orElseThrow(() -> new BadCredentialsException("User not found"));
        if (user.getRole() != role || user.getStatus() != AccountStatus.ACTIVE) {
            throw new AccessDeniedException("Active account with the required role is needed");
        }
        var link = bookings.findLink(id).orElseThrow(() -> missing("Booking not found"));
        UUID profile = role == Role.MEMBER
                ? members.findByUser_Id(user.getId()).orElseThrow(() -> missing("Member profile not found")).getId()
                : trainers.findByUser_Id(user.getId()).orElseThrow(() -> missing("PT profile not found")).getId();
        if (!profile.equals(role == Role.MEMBER ? link.memberId() : link.ptId())) throw missing("Booking not found");

        // Parent lock order matches R03; no membership read is needed for cancellation/completion.
        members.findByIdForUpdate(link.memberId()).orElseThrow(() -> missing("Member not found"));
        trainers.findByIdForUpdate(link.ptId()).orElseThrow(() -> missing("PT not found"));
        var slot = slots.findOwnedByIdForUpdate(link.slotId(), link.ptId()).orElseThrow(() -> missing("Slot not found"));
        var booking = bookings.findByIdForUpdate(id).orElseThrow(() -> missing("Booking not found"));
        if (!users.existsByIdAndRoleAndStatus(user.getId(), role, AccountStatus.ACTIVE)) {
            throw new AccessDeniedException("Account is no longer ACTIVE");
        }
        if (!booking.getMemberId().equals(link.memberId()) || !booking.getPtId().equals(link.ptId())
                || !booking.getSlotId().equals(link.slotId())) {
            throw conflict("Booking identity changed while waiting");
        }
        validator.requireConfirmed(booking.getStatus()); // repeated/old requests must stop before touching the slot
        if (!booking.getStartAt().toInstant().equals(slot.getStartAt().toInstant())
                || !booking.getEndAt().toInstant().equals(slot.getEndAt().toInstant())
                || bookings.existsBySlotIdAndStatusAndIdNot(slot.getId(), BookingStatus.CONFIRMED, id)) {
            throw conflict("Slot is inconsistent with this booking or owned by another CONFIRMED booking");
        }
        return new Locked(booking, slot);
    }

    private BookingResponse persist(Locked locked, SlotStatus targetStatus) {
        // Remove CONFIRMED first, then publish/disable its slot; neither flush is visible before commit.
        // A failure in the slot update must roll back the already-flushed booking metadata as well.
        bookings.flush();
        locked.slot().setStatus(targetStatus);
        slots.flush();
        var b = locked.booking();
        return new BookingResponse(b.getId(), b.getMemberId(), b.getPtId(), b.getSlotId(),
                b.getStartAt().withOffsetSameInstant(ZoneOffset.UTC), b.getEndAt().withOffsetSameInstant(ZoneOffset.UTC),
                b.getStatus().name(), b.getCancelledBy(), b.getCancelReason(), b.getCancelledAt(), b.getCompletedAt());
    }

    private static ResponseStatusException missing(String message) {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, message);
    }

    private static BookingConflictException conflict(String message) {
        return new BookingConflictException("ERR_BOOKING_SLOT_CONFLICT", message);
    }
}
