package vn.edu.tdtu.fitcenter.dto.booking;

import java.time.OffsetDateTime;
import java.util.UUID;

public record BookingResponse(
        UUID id,
        UUID memberId,
        UUID ptId,
        UUID slotId,
        OffsetDateTime startAt,
        OffsetDateTime endAt,
        String status,
        String cancelledBy,
        String cancelReason,
        OffsetDateTime cancelledAt,
        OffsetDateTime completedAt
) {
}
