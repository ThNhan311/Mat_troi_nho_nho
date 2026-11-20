package vn.edu.tdtu.fitcenter.service;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import vn.edu.tdtu.fitcenter.domain.entity.Booking;
import vn.edu.tdtu.fitcenter.domain.entity.Membership;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.BookingStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.dto.booking.ServiceEligibilityResponse;
import vn.edu.tdtu.fitcenter.exception.BookingConflictException;

import java.time.Instant;
import java.util.ArrayList;

import static vn.edu.tdtu.fitcenter.dto.booking.ServiceEligibilityResponse.ReasonCode.*;

@Component
@RequiredArgsConstructor
public class ServiceEligibilityValidator {
    private final BookingEligibilityValidator membershipValidator;

    public ServiceEligibilityResponse check(Booking booking, User memberAccount, Membership membership, Instant now) {
        var reasons = new ArrayList<ServiceEligibilityResponse.ReasonCode>();
        if (booking.getStatus() != BookingStatus.CONFIRMED) reasons.add(BOOKING_NOT_CONFIRMED);
        var start = booking.getStartAt().toInstant();
        var end = booking.getEndAt().toInstant();
        if (now.isBefore(start)) reasons.add(SESSION_NOT_STARTED);
        if (!now.isBefore(end)) reasons.add(SESSION_ENDED);
        if (memberAccount.getRole() != Role.MEMBER || memberAccount.getStatus() != AccountStatus.ACTIVE) reasons.add(MEMBER_ACCOUNT_INACTIVE);
        try {
            // Reuse only R03's membership DATE rules, never its create window/count/policy checks.
            membershipValidator.validateMembership(membership, start, end, now);
        } catch (BookingConflictException error) {
            reasons.add(switch (error.getCode()) {
                case "ERR_MEMBERSHIP_INACTIVE" -> MEMBERSHIP_INACTIVE;
                case "ERR_MEMBERSHIP_NOT_COVERED" -> MEMBERSHIP_NOT_COVERED;
                default -> throw error;
            });
        }
        return new ServiceEligibilityResponse(reasons.isEmpty(), now, reasons);
    }
}
