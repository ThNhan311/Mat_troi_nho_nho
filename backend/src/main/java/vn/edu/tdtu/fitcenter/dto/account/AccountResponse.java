package vn.edu.tdtu.fitcenter.dto.account;
import java.util.UUID;
public record AccountResponse(UUID userId, UUID profileId, String email, String fullName, String role, String status, boolean activationPending) {}