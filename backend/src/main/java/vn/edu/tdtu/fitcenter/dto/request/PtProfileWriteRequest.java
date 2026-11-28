package vn.edu.tdtu.fitcenter.dto.request;

import jakarta.validation.constraints.Size;

/** The whole editable profile; a blank or missing field is cleared. */
public record PtProfileWriteRequest(
        @Size(max = 1000) String bio,
        @Size(max = 200) String specialization,
        @Size(max = 500) String experienceSummary
) {
}
