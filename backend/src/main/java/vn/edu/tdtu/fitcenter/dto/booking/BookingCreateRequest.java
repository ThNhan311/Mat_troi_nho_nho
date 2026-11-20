package vn.edu.tdtu.fitcenter.dto.booking;

import jakarta.validation.constraints.NotNull;
import java.util.UUID;

public record BookingCreateRequest(@NotNull UUID ptId, @NotNull UUID slotId) {}
