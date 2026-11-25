
package vn.edu.tdtu.fitcenter.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;

import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.dto.auth.LoginRequest;
import vn.edu.tdtu.fitcenter.dto.auth.LoginResponse;
import vn.edu.tdtu.fitcenter.dto.auth.RefreshTokenRequest;
import vn.edu.tdtu.fitcenter.repository.UserRepository;
import vn.edu.tdtu.fitcenter.security.JwtService;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtService jwtService;

    @InjectMocks
    private AuthService authService;

    private User activeUser;

    @BeforeEach
    void setUp() {
        activeUser = User.builder()
                .id(UUID.randomUUID())
                .email("member@fitcenter.local")
                .passwordHash("encoded-password")
                .role(Role.MEMBER)
                .status(AccountStatus.ACTIVE)
                .build();
    }

    // =========================================
    // LOGIN TESTS
    // =========================================

    @Test
    void login_withValidCredentials_returnsTokens() {
        LoginRequest request = new LoginRequest(
                "member@fitcenter.local",
                "correct-password"
        );

        when(userRepository.findByEmailIgnoreCase(request.email()))
                .thenReturn(Optional.of(activeUser));

        when(passwordEncoder.matches(
                request.password(),
                activeUser.getPasswordHash()
        )).thenReturn(true);

        when(jwtService.generateAccessToken(activeUser))
                .thenReturn("access-token");

        when(jwtService.generateRefreshToken(activeUser))
                .thenReturn("refresh-token");

        LoginResponse response = authService.login(request);

        assertNotNull(response);

        verify(jwtService).generateAccessToken(activeUser);
        verify(jwtService).generateRefreshToken(activeUser);
    }

    @Test
    void login_withWrongPassword_throwsBadCredentials() {
        LoginRequest request = new LoginRequest(
                "member@fitcenter.local",
                "wrong-password"
        );

        when(userRepository.findByEmailIgnoreCase(request.email()))
                .thenReturn(Optional.of(activeUser));

        when(passwordEncoder.matches(
                request.password(),
                activeUser.getPasswordHash()
        )).thenReturn(false);

        assertThrows(
                BadCredentialsException.class,
                () -> authService.login(request)
        );

        verify(jwtService, never())
                .generateAccessToken(any(User.class));
    }

    @Test
    void login_withUnknownEmail_throwsBadCredentials() {
        LoginRequest request = new LoginRequest(
                "unknown@fitcenter.local",
                "password"
        );

        when(userRepository.findByEmailIgnoreCase(request.email()))
                .thenReturn(Optional.empty());

        assertThrows(
                BadCredentialsException.class,
                () -> authService.login(request)
        );

        verifyNoInteractions(passwordEncoder, jwtService);
    }

    @Test
    void login_withSuspendedAccount_throwsBadCredentials() {
        activeUser.setStatus(AccountStatus.SUSPENDED);

        LoginRequest request = new LoginRequest(
                "member@fitcenter.local",
                "password"
        );

        when(userRepository.findByEmailIgnoreCase(request.email()))
                .thenReturn(Optional.of(activeUser));

        assertThrows(
                BadCredentialsException.class,
                () -> authService.login(request)
        );

        verifyNoInteractions(passwordEncoder, jwtService);
    }

    @Test
    void login_withDisabledAccount_throwsBadCredentials() {
        activeUser.setStatus(AccountStatus.DISABLED);

        LoginRequest request = new LoginRequest(
                "member@fitcenter.local",
                "password"
        );

        when(userRepository.findByEmailIgnoreCase(request.email()))
                .thenReturn(Optional.of(activeUser));

        assertThrows(
                BadCredentialsException.class,
                () -> authService.login(request)
        );

        verifyNoInteractions(passwordEncoder, jwtService);
    }

    // =========================================
    // REFRESH TOKEN TESTS
    // =========================================

    @Test
    void refresh_withValidToken_returnsNewTokens() {
        String refreshToken = "valid-refresh-token";

        RefreshTokenRequest request =
                new RefreshTokenRequest(refreshToken);

        when(jwtService.isRefreshTokenValid(refreshToken))
                .thenReturn(true);

        when(jwtService.extractUserId(refreshToken))
                .thenReturn(activeUser.getId().toString());

        when(userRepository.findById(activeUser.getId()))
                .thenReturn(Optional.of(activeUser));

        when(jwtService.generateAccessToken(activeUser))
                .thenReturn("new-access-token");

        when(jwtService.generateRefreshToken(activeUser))
                .thenReturn("new-refresh-token");

        LoginResponse response = authService.refresh(request);

        assertNotNull(response);

        verify(jwtService).generateAccessToken(activeUser);
        verify(jwtService).generateRefreshToken(activeUser);
    }

    @Test
    void refresh_withInvalidToken_throwsBadCredentials() {
        String invalidToken = "invalid-token";

        when(jwtService.isRefreshTokenValid(invalidToken))
                .thenReturn(false);

        assertThrows(
                BadCredentialsException.class,
                () -> authService.refresh(
                        new RefreshTokenRequest(invalidToken)
                )
        );

        verifyNoInteractions(userRepository);
    }

    @Test
    void refresh_withInvalidUserId_throwsBadCredentials() {
        String refreshToken = "valid-token-invalid-subject";

        when(jwtService.isRefreshTokenValid(refreshToken))
                .thenReturn(true);

        when(jwtService.extractUserId(refreshToken))
                .thenReturn("not-a-uuid");

        assertThrows(
                BadCredentialsException.class,
                () -> authService.refresh(
                        new RefreshTokenRequest(refreshToken)
                )
        );

        verifyNoInteractions(userRepository);
    }

    @Test
    void refresh_withUnknownUser_throwsBadCredentials() {
        String refreshToken = "valid-token-unknown-user";

        when(jwtService.isRefreshTokenValid(refreshToken))
                .thenReturn(true);

        when(jwtService.extractUserId(refreshToken))
                .thenReturn(activeUser.getId().toString());

        when(userRepository.findById(activeUser.getId()))
                .thenReturn(Optional.empty());

        assertThrows(
                BadCredentialsException.class,
                () -> authService.refresh(
                        new RefreshTokenRequest(refreshToken)
                )
        );

        verify(jwtService, never())
                .generateAccessToken(any(User.class));
    }

    @Test
    void refresh_withSuspendedAccount_throwsBadCredentials() {
        activeUser.setStatus(AccountStatus.SUSPENDED);

        String refreshToken = "valid-token-suspended-user";

        when(jwtService.isRefreshTokenValid(refreshToken))
                .thenReturn(true);

        when(jwtService.extractUserId(refreshToken))
                .thenReturn(activeUser.getId().toString());

        when(userRepository.findById(activeUser.getId()))
                .thenReturn(Optional.of(activeUser));

        assertThrows(
                BadCredentialsException.class,
                () -> authService.refresh(
                        new RefreshTokenRequest(refreshToken)
                )
        );

        verify(jwtService, never())
                .generateAccessToken(any(User.class));
    }
}
