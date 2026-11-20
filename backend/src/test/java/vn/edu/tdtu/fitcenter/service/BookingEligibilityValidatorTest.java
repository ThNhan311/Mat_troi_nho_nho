package vn.edu.tdtu.fitcenter.service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.ValueSource;
import vn.edu.tdtu.fitcenter.domain.entity.Membership;
import vn.edu.tdtu.fitcenter.domain.enums.MembershipStatus;
import vn.edu.tdtu.fitcenter.dto.booking.BookingPolicyResponse;
import vn.edu.tdtu.fitcenter.exception.BookingConflictException;

import java.time.*;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class BookingEligibilityValidatorTest {
    private final BookingEligibilityValidator validator = new BookingEligibilityValidator();
    private final Instant now = Instant.parse("2030-01-02T03:04:05.123456Z");
    private final BookingPolicyResponse policy = new BookingPolicyResponse(UUID.randomUUID(), 14, 2, 4, 5, now);

    @ParameterizedTest @ValueSource(longs = {-1, 0, 1})
    void minimumNoticeIncludesEquality(long delta) {
        Instant start = now.plus(Duration.ofHours(2)).plusNanos(delta);
        if (delta < 0) assertCode("ERR_BOOKING_NOTICE", () -> validator.validateWindow(policy, start, start.plusSeconds(5400), now));
        else assertDoesNotThrow(() -> validator.validateWindow(policy, start, start.plusSeconds(5400), now));
    }

    @ParameterizedTest @ValueSource(longs = {-1, 0, 1})
    void maximumAdvanceIsExactDurationAndIncludesEquality(long delta) {
        Instant start = now.plus(Duration.ofDays(14)).plusNanos(delta);
        if (delta > 0) assertCode("ERR_BOOKING_ADVANCE", () -> validator.validateWindow(policy, start, start.plusSeconds(5400), now));
        else assertDoesNotThrow(() -> validator.validateWindow(policy, start, start.plusSeconds(5400), now));
    }

    @ParameterizedTest @ValueSource(ints = {0, 60, 120})
    void only90MinuteCoreDurationIsAccepted(int minutes) {
        Instant start = now.plusSeconds(7200);
        assertCode("ERR_SLOT_INVALID_DURATION", () -> validator.validateWindow(policy, start, start.plusSeconds(minutes * 60L), now));
    }

    @Test void zeroNoticeAllowsStartExactlyNowButNeverPast() {
        var zero = new BookingPolicyResponse(UUID.randomUUID(), 1, 0, 0, 1, now);
        assertDoesNotThrow(() -> validator.validateWindow(zero, now, now.plusSeconds(5400), now));
        assertCode("ERR_BOOKING_NOTICE", () -> validator.validateWindow(zero, now.minusNanos(1), now.plusSeconds(5400).minusNanos(1), now));
    }

    @ParameterizedTest @ValueSource(ints = {0, 4, 5, 6})
    void maxFutureComesFromPolicyAndRejectsWhenAlreadyAtLimit(int count) {
        if (count >= 5) assertCode("ERR_MAX_FUTURE_BOOKINGS", () -> validator.validateFutureCount(policy, count));
        else assertDoesNotThrow(() -> validator.validateFutureCount(policy, count));
    }

    @Test void customLimitsAreUsedWithoutInitialDefaults() {
        var custom = new BookingPolicyResponse(UUID.randomUUID(), 1, 3, 0, 1, now);
        assertCode("ERR_BOOKING_NOTICE", () -> validator.validateWindow(custom, now.plusSeconds(7200), now.plusSeconds(12600), now));
        assertCode("ERR_BOOKING_ADVANCE", () -> validator.validateWindow(custom, now.plus(Duration.ofDays(2)), now.plus(Duration.ofDays(2)).plusSeconds(5400), now));
        assertCode("ERR_MAX_FUTURE_BOOKINGS", () -> validator.validateFutureCount(custom, 1));
    }

    @ParameterizedTest @EnumSource(value = MembershipStatus.class, names = "ACTIVE", mode = EnumSource.Mode.EXCLUDE)
    void membershipMustHaveStoredActiveStatus(MembershipStatus status) {
        var membership = membership(); membership.setStatus(status);
        assertCode("ERR_MEMBERSHIP_INACTIVE", () -> validator.validateMembership(membership, now.plusSeconds(7200), now.plusSeconds(12600), now));
    }

    @Test void missingOrUnactivatedMembershipIsRejected() {
        assertCode("ERR_MEMBERSHIP_INACTIVE", () -> validator.validateMembership(null, now, now.plusSeconds(5400), now));
        var membership = membership(); membership.setStartDate(null);
        assertCode("ERR_MEMBERSHIP_INACTIVE", () -> validator.validateMembership(membership, now, now.plusSeconds(5400), now));
    }

    @Test void vietnamActivationAndExpiryUseLocalDatesRatherThanUtcDates() {
        var membership = membership();
        Instant localStart = Instant.parse("2030-01-01T17:00:00Z"); // Jan 2 00:00 +07
        assertDoesNotThrow(() -> validator.validateMembership(membership, localStart.plusSeconds(7200), localStart.plusSeconds(12600), localStart));
        assertCode("ERR_MEMBERSHIP_INACTIVE", () -> validator.validateMembership(membership, now, now.plusSeconds(5400), localStart.minusNanos(1)));
        Instant expiryExclusive = Instant.parse("2030-01-03T17:00:00Z"); // Jan 4 00:00 +07
        assertDoesNotThrow(() -> validator.validateMembership(membership, expiryExclusive.minusSeconds(5400), expiryExclusive, now));
        assertCode("ERR_MEMBERSHIP_NOT_COVERED", () -> validator.validateMembership(membership, expiryExclusive.minusSeconds(5400).plusNanos(1), expiryExclusive.plusNanos(1), now));
        assertCode("ERR_MEMBERSHIP_INACTIVE", () -> validator.validateMembership(membership, expiryExclusive.plusSeconds(7200), expiryExclusive.plusSeconds(12600), expiryExclusive));
    }

    @Test void entireSessionMustBeCoveredIncludingStartBoundary() {
        var membership = membership();
        Instant from = Instant.parse("2030-01-01T17:00:00Z");
        assertCode("ERR_MEMBERSHIP_NOT_COVERED", () -> validator.validateMembership(membership, from.minusNanos(1), from.plusSeconds(5400), now));
    }

    private Membership membership() {
        return Membership.builder().status(MembershipStatus.ACTIVE)
                .startDate(LocalDate.of(2030, 1, 2)).expiryDate(LocalDate.of(2030, 1, 3)).build();
    }

    private void assertCode(String code, Runnable operation) {
        assertEquals(code, assertThrows(BookingConflictException.class, operation::run).getCode());
    }
}
