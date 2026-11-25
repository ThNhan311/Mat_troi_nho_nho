package vn.edu.tdtu.fitcenter.service;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import vn.edu.tdtu.fitcenter.domain.entity.AvailabilitySlot;
import vn.edu.tdtu.fitcenter.domain.entity.PersonalTrainer;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.BookingStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.domain.enums.SlotStatus;
import vn.edu.tdtu.fitcenter.dto.request.AvailabilityWriteRequest;
import vn.edu.tdtu.fitcenter.dto.response.AvailabilitySlotResponse;
import vn.edu.tdtu.fitcenter.repository.*;

import java.time.Clock;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional(timeout = 10)
public class AvailabilityWriteService {
    private static final Duration CORE_DURATION = Duration.ofMinutes(90);
    private static final UUID NO_SLOT = new UUID(0, 0);
    private final UserRepository users;
    private final PersonalTrainerRepository trainers;
    private final AvailabilitySlotRepository slots;
    private final BookingRepository bookings;
    private final Clock clock;

    public AvailabilitySlotResponse create(String email, AvailabilityWriteRequest request) {
        var trainer = lockTrainer(email);
        validate(request.startAt(), request.endAt());
        ensureNoOverlap(trainer.getId(), NO_SLOT, request.startAt(), request.endAt());
        return response(insert(trainer, request.startAt(), request.endAt()));
    }

    public AvailabilitySlotResponse update(String email, UUID slotId, AvailabilityWriteRequest request) {
        var trainer = lockTrainer(email);
        var slot = lockSlot(trainer, slotId);
        ensureNotBooked(slot);
        if (slot.getStatus() != SlotStatus.AVAILABLE || !slot.getStartAt().toInstant().isAfter(clock.instant())) {
            throw conflict("Only future AVAILABLE slots can be edited; publish a new slot instead");
        }
        if (request.startAt() == null && request.endAt() == null) {
            throw new IllegalArgumentException("At least one time field is required");
        }
        var start = request.startAt() == null ? slot.getStartAt() : request.startAt();
        var end = request.endAt() == null ? slot.getEndAt() : request.endAt();
        validate(start, end);
        ensureNoOverlap(trainer.getId(), slotId, start, end);
        if (start.toInstant().equals(slot.getStartAt().toInstant()) && end.toInstant().equals(slot.getEndAt().toInstant())) {
            return response(slot);
        }
        if (bookings.existsBySlotId(slotId)) {
            // V4's composite FK includes timestamps: never rewrite history or cascade its times.
            slot.setStatus(SlotStatus.DISABLED);
            slots.flush(); // remove the old interval from the exclusion constraint before inserting its replacement
            return response(insert(trainer, start, end));
        }
        slot.setStartAt(utc(start));
        slot.setEndAt(utc(end));
        slots.flush();
        return response(slot);
    }

    public void disable(String email, UUID slotId) {
        var trainer = lockTrainer(email);
        var slot = lockSlot(trainer, slotId);
        ensureNotBooked(slot);
        if (slot.getStatus() != SlotStatus.DISABLED) {
            slot.setStatus(SlotStatus.DISABLED);
            slots.flush();
        }
    }

    private PersonalTrainer lockTrainer(String email) {
        var user = users.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new BadCredentialsException("User not found"));
        if (user.getRole() != Role.PT || user.getStatus() != AccountStatus.ACTIVE) {
            throw new AccessDeniedException("Only active personal trainers can manage availability");
        }
        return trainers.findByUserIdForUpdate(user.getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Personal trainer profile not found"));
    }

    private AvailabilitySlot lockSlot(PersonalTrainer trainer, UUID id) {
        return slots.findOwnedByIdForUpdate(id, trainer.getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Availability slot not found"));
    }

    private void ensureNotBooked(AvailabilitySlot slot) {
        if (slot.getStatus() == SlotStatus.BOOKED || bookings.existsBySlotIdAndStatus(slot.getId(), BookingStatus.CONFIRMED)) {
            throw conflict("A booked slot or slot with a CONFIRMED booking cannot be changed");
        }
    }

    private void ensureNoOverlap(UUID ptId, UUID excludedId, OffsetDateTime start, OffsetDateTime end) {
        if (slots.overlaps(ptId, excludedId, start, end) || bookings.overlapsConfirmed(ptId, start, end)) {
            throw conflict("Availability overlaps an existing slot or CONFIRMED session");
        }
    }

    private void validate(OffsetDateTime start, OffsetDateTime end) {
        if (start == null || end == null || !start.isBefore(end)
                || !Duration.between(start.toInstant(), end.toInstant()).equals(CORE_DURATION)
                || !start.toInstant().isAfter(clock.instant())
                || start.getNano() % 1000 != 0 || end.getNano() % 1000 != 0) {
            throw new IllegalArgumentException("Require future startAt, a 90-minute duration and at most microsecond precision");
        }
    }

    private AvailabilitySlot insert(PersonalTrainer trainer, OffsetDateTime start, OffsetDateTime end) {
        return slots.saveAndFlush(AvailabilitySlot.builder().personalTrainer(trainer).startAt(utc(start)).endAt(utc(end))
                .status(SlotStatus.AVAILABLE).build());
    }

    private static OffsetDateTime utc(OffsetDateTime time) { return time.withOffsetSameInstant(ZoneOffset.UTC); }

    private static AvailabilitySlotResponse response(AvailabilitySlot slot) {
        return new AvailabilitySlotResponse(slot.getId(), slot.getPersonalTrainer().getId(),
                utc(slot.getStartAt()), utc(slot.getEndAt()), slot.getStatus().name());
    }

    private static ResponseStatusException conflict(String message) {
        return new ResponseStatusException(HttpStatus.CONFLICT, message);
    }
}
