
package vn.edu.tdtu.fitcenter.dto.response;

import java.util.UUID;

public record PersonalTrainerResponse(
        UUID id,
        String fullName,
        String bio,
        String specialization,
        String experienceSummary,
        String phone,
        String gender
) {
}
