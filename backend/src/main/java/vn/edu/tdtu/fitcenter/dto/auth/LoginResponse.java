package vn.edu.tdtu.fitcenter.dto.auth;

import vn.edu.tdtu.fitcenter.domain.enums.Role;

public record LoginResponse(
        String accessToken,
        String refreshToken,
        Role role
) {
}