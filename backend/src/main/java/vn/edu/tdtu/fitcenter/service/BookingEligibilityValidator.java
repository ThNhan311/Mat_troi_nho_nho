package vn.edu.tdtu.fitcenter.service;

import org.springframework.stereotype.Component;
import vn.edu.tdtu.fitcenter.domain.entity.Membership;
import vn.edu.tdtu.fitcenter.domain.enums.MembershipStatus;
import vn.edu.tdtu.fitcenter.dto.booking.BookingPolicyResponse;
import vn.edu.tdtu.fitcenter.exception.BookingConflictException;

import java.time.*;

@Component
public class BookingEligibilityValidator {
    private vn.edu.tdtu.fitcenter.renewal.MembershipPeriodService periods;
    @org.springframework.beans.factory.annotation.Autowired public void setPeriods(vn.edu.tdtu.fitcenter.renewal.MembershipPeriodService periods){this.periods=periods;}
    private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Ho_Chi_Minh");

    public void validateMembership(Membership membership, Instant start, Instant end, Instant now) {
        if (membership == null || membership.getStatus() != MembershipStatus.ACTIVE
                || membership.getStartDate() == null || membership.getExpiryDate() == null) {
            throw conflict("ERR_MEMBERSHIP_INACTIVE", "An ACTIVE membership is required");
        }
        Instant from = membership.getStartDate().atStartOfDay(BUSINESS_ZONE).toInstant();
        Instant until = membership.getExpiryDate().plusDays(1).atStartOfDay(BUSINESS_ZONE).toInstant();
        if (now.isBefore(from) || !now.isBefore(until)) {
            throw conflict("ERR_MEMBERSHIP_INACTIVE", "Membership is not active on the current business date");
        }
        if(periods!=null&&periods.enabled()){
            LocalDate today=LocalDate.ofInstant(now,BUSINESS_ZONE);
            if(!periods.covered(membership.getId(),today,today))throw conflict("ERR_MEMBERSHIP_INACTIVE","No paid coverage today");
            if(!periods.covered(membership.getId(),LocalDate.ofInstant(start,BUSINESS_ZONE),LocalDate.ofInstant(end.minusNanos(1),BUSINESS_ZONE)))throw conflict("ERR_MEMBERSHIP_NOT_COVERED","Paid periods must cover the entire session without gaps");
        }
        // DATE expiry is inclusive; a half-open session may end exactly at the next local midnight.
        if (start.isBefore(from) || end.isAfter(until)) {
            throw conflict("ERR_MEMBERSHIP_NOT_COVERED", "Membership must cover the entire session");
        }
    }

    public void validateWindow(BookingPolicyResponse policy, Instant start, Instant end, Instant now) {
        if (!Duration.between(start, end).equals(Duration.ofMinutes(90))) {
            throw conflict("ERR_SLOT_INVALID_DURATION", "Core sessions must last exactly 90 minutes");
        }
        Duration notice = Duration.between(now, start);
        if (notice.isNegative() || notice.compareTo(Duration.ofHours(policy.minNoticeHours())) < 0) {
            throw conflict("ERR_BOOKING_NOTICE", "Slot does not meet minimum booking notice");
        }
        if (notice.compareTo(Duration.ofDays(policy.maxAdvanceDays())) > 0) {
            throw conflict("ERR_BOOKING_ADVANCE", "Slot exceeds maximum advance booking duration");
        }
    }

    public void validateFutureCount(BookingPolicyResponse policy, long count) {
        if (count >= policy.maxFutureBookings()) {
            throw conflict("ERR_MAX_FUTURE_BOOKINGS", "Maximum future CONFIRMED bookings reached");
        }
    }

    private static BookingConflictException conflict(String code, String message) {
        return new BookingConflictException(code, message);
    }
}
