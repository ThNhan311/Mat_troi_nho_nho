package vn.edu.tdtu.fitcenter.dto.booking;

import java.time.Instant;
import java.util.List;

public record ServiceEligibilityResponse(boolean eligible, Instant checkedAt, List<ReasonCode> reasonCodes) {
    public ServiceEligibilityResponse { reasonCodes = List.copyOf(reasonCodes); }

    public enum ReasonCode {
        BOOKING_NOT_CONFIRMED, SESSION_NOT_STARTED, SESSION_ENDED,
        MEMBER_ACCOUNT_INACTIVE, MEMBERSHIP_INACTIVE, MEMBERSHIP_NOT_COVERED
    }
}
