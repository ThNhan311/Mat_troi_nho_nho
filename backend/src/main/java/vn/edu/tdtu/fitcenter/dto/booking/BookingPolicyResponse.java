package vn.edu.tdtu.fitcenter.dto.booking;

import java.time.Instant;
import java.util.UUID;

public record BookingPolicyResponse(
        UUID id,
        int maxAdvanceDays,
        int minNoticeHours,
        int cancelDeadlineHours,
        int maxFutureBookings,
        Instant effectiveFrom
) {}
