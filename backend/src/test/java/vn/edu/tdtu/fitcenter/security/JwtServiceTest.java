
package vn.edu.tdtu.fitcenter.security;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class JwtServiceTest {

    private JwtService jwtService;
    private User user;

    private static final String TEST_SECRET =
            "fitcenter-test-secret-key-at-least-32-bytes-long-2026";

    @BeforeEach
    void setUp() {
        jwtService = new JwtService();

        ReflectionTestUtils.setField(
                jwtService, "secret", TEST_SECRET
        );

        ReflectionTestUtils.setField(
                jwtService, "accessExpirationMs", 900000L
        );

        ReflectionTestUtils.setField(
                jwtService, "refreshExpirationMs", 604800000L
        );

        user = User.builder()
                .id(UUID.randomUUID())
                .email("member@fitcenter.local")
                .passwordHash("encoded-password")
                .role(Role.MEMBER)
                .status(AccountStatus.ACTIVE)
                .build();
    }

    @Test
    void generateAccessToken_containsCorrectClaims() {
        String token = jwtService.generateAccessToken(user);

        assertEquals(
                user.getId().toString(),
                jwtService.extractUserId(token)
        );

        assertEquals(
                user.getEmail(),
                jwtService.extractEmail(token)
        );

        assertEquals(
                "MEMBER",
                jwtService.extractRole(token)
        );

        assertEquals(
                "access",
                jwtService.extractTokenType(token)
        );
    }

    @Test
    void generateRefreshToken_containsRefreshType() {
        String token = jwtService.generateRefreshToken(user);

        assertEquals(
                "refresh",
                jwtService.extractTokenType(token)
        );
    }

    @Test
    void validAccessToken_isAccepted() {
        String token = jwtService.generateAccessToken(user);

        assertTrue(jwtService.isAccessTokenValid(token));
    }

    @Test
    void validRefreshToken_isAccepted() {
        String token = jwtService.generateRefreshToken(user);

        assertTrue(jwtService.isRefreshTokenValid(token));
    }

    @Test
    void refreshToken_cannotBeUsedAsAccessToken() {
        String token = jwtService.generateRefreshToken(user);

        assertFalse(jwtService.isAccessTokenValid(token));
    }

    @Test
    void accessToken_cannotBeUsedAsRefreshToken() {
        String token = jwtService.generateAccessToken(user);

        assertFalse(jwtService.isRefreshTokenValid(token));
    }

    @Test
    void expiredAccessToken_isRejected() {
        ReflectionTestUtils.setField(
                jwtService, "accessExpirationMs", -1000L
        );

        String token = jwtService.generateAccessToken(user);

        assertFalse(jwtService.isAccessTokenValid(token));
    }

    @Test
    void expiredRefreshToken_isRejected() {
        ReflectionTestUtils.setField(
                jwtService, "refreshExpirationMs", -1000L
        );

        String token = jwtService.generateRefreshToken(user);

        assertFalse(jwtService.isRefreshTokenValid(token));
    }

    @Test
    void tamperedToken_isRejected() {
        String token = jwtService.generateAccessToken(user);

        // Alter the signature segment.
        String[] parts = token.split("\\.");
        String signature = parts[2];

        char replacement =
                signature.charAt(0) == 'A' ? 'B' : 'A';

        parts[2] = replacement + signature.substring(1);

        String tamperedToken = String.join(".", parts);

        assertFalse(jwtService.isAccessTokenValid(tamperedToken));
    }

    @Test
    void tokenSignedWithDifferentSecret_isRejected() {
        String token = jwtService.generateAccessToken(user);

        JwtService otherJwtService = new JwtService();

        ReflectionTestUtils.setField(
                otherJwtService,
                "secret",
                "another-fitcenter-test-secret-at-least-32-bytes"
        );

        assertFalse(
                otherJwtService.isAccessTokenValid(token)
        );
    }
}
