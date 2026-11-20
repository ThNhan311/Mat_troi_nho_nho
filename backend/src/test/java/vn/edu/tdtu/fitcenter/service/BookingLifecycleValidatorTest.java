package vn.edu.tdtu.fitcenter.service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.NullSource;
import org.junit.jupiter.params.provider.ValueSource;
import vn.edu.tdtu.fitcenter.domain.enums.BookingStatus;
import vn.edu.tdtu.fitcenter.exception.BookingConflictException;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.*;

class BookingLifecycleValidatorTest {
    private final BookingLifecycleValidator validator = new BookingLifecycleValidator();
    private final Instant start = Instant.parse("2030-01-02T03:04:05.123456Z");

    @ParameterizedTest @ValueSource(longs = {-1, 0, 1})
    void memberDeadlineIncludesEquality(long delta) {
        Instant now = start.minusSeconds(4 * 3600L).plusNanos(delta);
        if (delta > 0) assertCode("ERR_CANCELLATION_DEADLINE", () -> validator.memberCancellation(start, now, 4));
        else assertDoesNotThrow(() -> validator.memberCancellation(start, now, 4));
    }

    @Test void zeroDeadlineAllowsExactStartButNotAfter() {
        assertDoesNotThrow(() -> validator.memberCancellation(start, start, 0));
        assertCode("ERR_CANCELLATION_DEADLINE", () -> validator.memberCancellation(start, start.plusNanos(1), 0));
    }

    @Test void deadlineIsConfiguredRatherThanAssumedFourHours() {
        assertCode("ERR_CANCELLATION_DEADLINE", () -> validator.memberCancellation(start, start.minusSeconds(5 * 3600L), 6));
        assertDoesNotThrow(() -> validator.memberCancellation(start, start.minusSeconds(6 * 3600L), 6));
    }

    @ParameterizedTest @ValueSource(longs = {-1, 0, 1})
    void ptCancellationExcludesExactStart(long delta) {
        if (delta < 0) assertDoesNotThrow(() -> validator.ptCancellation(start, start.plusNanos(delta)));
        else assertCode("ERR_PT_CANCELLATION_WINDOW_CLOSED", () -> validator.ptCancellation(start, start.plusNanos(delta)));
    }

    @ParameterizedTest @ValueSource(longs = {-1, 0, 1})
    void completionIncludesExactEnd(long delta) {
        Instant now = start.plusNanos(delta);
        if (delta < 0) assertCode("ERR_BOOKING_NOT_ENDED", () -> validator.completion(start, now));
        else assertDoesNotThrow(() -> validator.completion(start, now));
    }

    @ParameterizedTest @EnumSource(value = BookingStatus.class, names = "CONFIRMED", mode = EnumSource.Mode.EXCLUDE)
    void terminalStatesRejectRepeatTransition(BookingStatus state) {
        assertCode("ERR_BOOKING_NOT_CONFIRMED", () -> validator.requireConfirmed(state));
    }

    @Test void confirmedCanTransition() { assertDoesNotThrow(() -> validator.requireConfirmed(BookingStatus.CONFIRMED)); }

    @ParameterizedTest @NullSource @ValueSource(strings = {"", " ", "\t\r\n", "\u2003", "\u00a0"})
    void ptReasonMustContainNonWhitespace(String reason) {
        assertThrows(IllegalArgumentException.class, () -> validator.reason(reason));
    }

    @Test void reasonLimitMatchesPostgresUnicodeCharacters() {
        assertDoesNotThrow(() -> validator.reason("x".repeat(500)));
        assertThrows(IllegalArgumentException.class, () -> validator.reason("x".repeat(501)));
        assertDoesNotThrow(() -> validator.reason("\ud83d\udcaa".repeat(500)));
        assertThrows(IllegalArgumentException.class, () -> validator.reason("\ud83d\udcaa".repeat(501)));
    }

    private void assertCode(String expected, Runnable action) {
        assertEquals(expected, assertThrows(BookingConflictException.class, action::run).getCode());
    }
}
