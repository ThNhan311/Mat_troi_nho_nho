package vn.edu.tdtu.fitcenter.service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.ValueSource;
import vn.edu.tdtu.fitcenter.domain.entity.Booking;
import vn.edu.tdtu.fitcenter.domain.entity.Membership;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.BookingStatus;
import vn.edu.tdtu.fitcenter.domain.enums.MembershipStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static vn.edu.tdtu.fitcenter.dto.booking.ServiceEligibilityResponse.ReasonCode.*;

class ServiceEligibilityValidatorTest {
    private final ServiceEligibilityValidator validator = new ServiceEligibilityValidator(new BookingEligibilityValidator());
    private final Instant start = Instant.parse("2030-01-02T03:04:05.123456Z");
    private final Booking booking = Booking.builder().status(BookingStatus.CONFIRMED)
            .startAt(start.atOffset(ZoneOffset.UTC)).endAt(start.plusSeconds(5400).atOffset(ZoneOffset.UTC)).build();
    private final User member = User.builder().role(Role.MEMBER).status(AccountStatus.ACTIVE).build();
    private final Membership membership = Membership.builder().status(MembershipStatus.ACTIVE)
            .startDate(LocalDate.of(2030, 1, 1)).expiryDate(LocalDate.of(2030, 1, 3)).build();

    @ParameterizedTest @ValueSource(longs = {-1, 0, 1})
    void startIncludesEquality(long delta) {
        var now = start.plusNanos(delta);
        var result = validator.check(booking, member, membership, now);
        assertEquals(now, result.checkedAt()); assertEquals(delta >= 0, result.eligible());
        assertEquals(delta < 0 ? List.of(SESSION_NOT_STARTED) : List.of(), result.reasonCodes());
    }

    @ParameterizedTest @ValueSource(longs = {-1, 0, 1})
    void endExcludesEquality(long delta) {
        var result = validator.check(booking, member, membership, start.plusSeconds(5400).plusNanos(delta));
        assertEquals(delta < 0, result.eligible());
        assertEquals(delta >= 0 ? List.of(SESSION_ENDED) : List.of(), result.reasonCodes());
    }

    @ParameterizedTest @EnumSource(value = BookingStatus.class, names = "CONFIRMED", mode = EnumSource.Mode.EXCLUDE)
    void terminalBookingsAreInformationalIneligibility(BookingStatus state) {
        booking.setStatus(state);
        assertEquals(List.of(BOOKING_NOT_CONFIRMED), validator.check(booking, member, membership, start).reasonCodes());
    }

    @Test void independentReasonsAreCompleteOrderedAndNotDuplicated() {
        booking.setStatus(BookingStatus.CANCELLED); member.setStatus(AccountStatus.DISABLED); membership.setStatus(MembershipStatus.SUSPENDED);
        var result = validator.check(booking, member, membership, start.minusNanos(1));
        assertFalse(result.eligible());
        assertEquals(List.of(BOOKING_NOT_CONFIRMED, SESSION_NOT_STARTED, MEMBER_ACCOUNT_INACTIVE, MEMBERSHIP_INACTIVE), result.reasonCodes());
    }

    @Test void nonMemberAccountIsDefensivelyRejectedInPureValidation() {
        member.setRole(Role.PT);
        assertEquals(List.of(MEMBER_ACCOUNT_INACTIVE), validator.check(booking, member, membership, start).reasonCodes());
    }

    @Test void missingMembershipIsMappedWithoutThrowingBusinessConflict() {
        assertEquals(List.of(MEMBERSHIP_INACTIVE), validator.check(booking, member, null, start).reasonCodes());
    }

    @Test void validCurrentMembershipMustStillCoverWholeSession() {
        booking.setEndAt(Instant.parse("2030-01-03T17:00:00.000001Z").atOffset(ZoneOffset.UTC));
        assertEquals(List.of(MEMBERSHIP_NOT_COVERED), validator.check(booking, member, membership, start).reasonCodes());
    }
}
