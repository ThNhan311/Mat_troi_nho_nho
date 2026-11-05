
package vn.edu.tdtu.fitcenter.dto.response;

import java.time.OffsetDateTime;
import java.util.UUID;

public record AvailabilitySlotResponse(
        UUID id,
        UUID ptId,
        OffsetDateTime startAt,
        OffsetDateTime endAt,
        String status
) {
}
