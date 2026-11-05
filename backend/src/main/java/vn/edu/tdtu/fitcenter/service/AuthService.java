package vn.edu.tdtu.fitcenter.service;

import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.dto.auth.LoginRequest;
import vn.edu.tdtu.fitcenter.dto.auth.LoginResponse;
import vn.edu.tdtu.fitcenter.dto.auth.RefreshTokenRequest;
import vn.edu.tdtu.fitcenter.repository.UserRepository;
import vn.edu.tdtu.fitcenter.security.JwtService;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public LoginResponse login(LoginRequest request) {

        User user = userRepository.findByEmailIgnoreCase(request.email().trim())
                .orElseThrow(() ->
                        new BadCredentialsException(
                                "Invalid email or password"
                        )
                );

        if (user.getStatus() != AccountStatus.ACTIVE) {
            throw new BadCredentialsException(
                    "Account is not active"
            );
        }

        boolean passwordMatches =
                passwordEncoder.matches(
                        request.password(),
                        user.getPasswordHash()
                );

        if (!passwordMatches) {
            throw new BadCredentialsException(
                    "Invalid email or password"
            );
        }

        return generateLoginResponse(user);
    }

    public LoginResponse refresh(
            RefreshTokenRequest request
    ) {

        String refreshToken =
                request.refreshToken();

        if (!jwtService.isRefreshTokenValid(refreshToken)) {
            throw new BadCredentialsException(
                    "Invalid refresh token"
            );
        }

        String userId =
                jwtService.extractUserId(refreshToken);

        UUID userUuid;

        try {
            userUuid = UUID.fromString(userId);
        } catch (IllegalArgumentException e) {
            throw new BadCredentialsException(
                    "Invalid refresh token"
            );
        }

        User user = userRepository.findById(userUuid)
                .orElseThrow(() ->
                        new BadCredentialsException(
                                "Invalid refresh token"
                        )
                );

        if (user.getStatus() != AccountStatus.ACTIVE) {
            throw new BadCredentialsException(
                    "Account is not active"
            );
        }

        return generateLoginResponse(user);
    }

    private LoginResponse generateLoginResponse(User user) {

        String accessToken =
                jwtService.generateAccessToken(user);

        String refreshToken =
                jwtService.generateRefreshToken(user);

        return new LoginResponse(
                accessToken,
                refreshToken,
                user.getRole()
        );
    }
}
