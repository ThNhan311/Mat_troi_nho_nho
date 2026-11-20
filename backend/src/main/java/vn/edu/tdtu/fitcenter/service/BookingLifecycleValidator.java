package vn.edu.tdtu.fitcenter.service;

import org.springframework.stereotype.Component;
import vn.edu.tdtu.fitcenter.domain.enums.BookingStatus;
import vn.edu.tdtu.fitcenter.exception.BookingConflictException;

import java.time.Duration;
import java.time.Instant;

@Component
public class BookingLifecycleValidator {
    public void requireConfirmed(BookingStatus status) {
        if (status != BookingStatus.CONFIRMED) {
            throw new BookingConflictException("ERR_BOOKING_NOT_CONFIRMED", "Only CONFIRMED bookings can transition");
        }
    }

    public void memberCancellation(Instant start, Instant now, int deadlineHours) {
        if (Duration.between(now, start).compareTo(Duration.ofHours(deadlineHours)) < 0) {
            throw new BookingConflictException("ERR_CANCELLATION_DEADLINE", "Cancellation deadline has passed");
        }
    }

    public void ptCancellation(Instant start, Instant now) {
        if (!now.isBefore(start)) {
            throw new BookingConflictException("ERR_PT_CANCELLATION_WINDOW_CLOSED", "PT cancellation is allowed only before session start");
        }
    }

    public void completion(Instant end, Instant now) {
        if (now.isBefore(end)) {
            throw new BookingConflictException("ERR_BOOKING_NOT_ENDED", "Session has not ended");
        }
    }

    public void reason(String reason) {
        if (reason == null || reason.codePointCount(0, reason.length()) > 500
                || reason.codePoints().allMatch(c -> Character.isWhitespace(c) || Character.isSpaceChar(c))) {
            throw new IllegalArgumentException("PT cancellation requires a nonblank reason of at most 500 characters");
        }
    }
}
