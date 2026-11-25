
package vn.edu.tdtu.fitcenter.dto.membership;

import vn.edu.tdtu.fitcenter.domain.enums.MembershipStatus;

import java.time.LocalDate;
import java.util.UUID;

public record MembershipResponse(
        UUID id,
        UUID planId,
        String planName,
        LocalDate startDate,
        LocalDate endDate,
        MembershipStatus status
) {
}
