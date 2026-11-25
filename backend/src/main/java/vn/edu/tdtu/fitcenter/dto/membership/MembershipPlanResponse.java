package vn.edu.tdtu.fitcenter.dto.membership;

import java.math.BigDecimal;
import java.util.UUID;

public record MembershipPlanResponse(
        UUID id,
        String name,
        String description,
        Integer durationDays,
        BigDecimal price
) {
}