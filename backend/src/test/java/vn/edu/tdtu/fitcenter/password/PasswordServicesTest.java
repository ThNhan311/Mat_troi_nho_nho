package vn.edu.tdtu.fitcenter.password;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import vn.edu.tdtu.fitcenter.activation.ActivationFailure;
import vn.edu.tdtu.fitcenter.activation.ActivationMailer;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class PasswordServicesTest {
    private static final String EMAIL = "member@example.test";

    private Instant now = Instant.parse("2026-11-28T00:00:00Z");
    private final Clock clock = new Clock() {
        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    };
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(4);
    private final UserRepository users = mock(UserRepository.class);
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final List<String> codes = new ArrayList<>();
    private final ActivationMailer mailer = (email, otp) -> codes.add(otp);
    private final UUID id = UUID.randomUUID();
    private User user;
    private PasswordResetService resets;
    private PasswordChangeService changes;

    @BeforeEach
    void setUp() {
        user = mock(User.class);
        when(user.getId()).thenReturn(id);
        when(user.getEmail()).thenReturn(EMAIL);
        when(user.getRole()).thenReturn(Role.MEMBER);
        when(user.getStatus()).thenReturn(AccountStatus.ACTIVE);
        when(user.getPasswordHash()).thenReturn(encoder.encode("old-password"));
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.of(user));
        when(jdbc.update(anyString(), any(), eq(id))).thenReturn(1);
        resets = new PasswordResetService(users, jdbc, mailer, encoder, clock);
        changes = new PasswordChangeService(users, jdbc, encoder, clock);
    }

    private static String code(Runnable action) {
        return assertThrows(ActivationFailure.class, action::run).getCode();
    }

    private String wrongCode() {
        return codes.getFirst().equals("000000") ? "000001" : "000000";
    }

    @Test
    void resetNeedsTheMailedCodeAndWorksOnce() {
        resets.request(" Member@Example.test ");
        assertEquals(1, codes.size());
        assertEquals("ERR_OTP_INVALID", code(() -> resets.verify(EMAIL, wrongCode())));
        String grant = resets.verify(EMAIL, codes.getFirst());
        assertEquals("ERR_VALIDATION", code(() -> resets.reset(grant, "short")));
        resets.reset(grant, "brand-new-password");
        verify(jdbc, times(1)).update(anyString(), any(), eq(id));
        assertEquals("ERR_OTP_INVALID", code(() -> resets.reset(grant, "another-password")));
    }

    @Test
    void unknownAndInactiveAccountsGetNoMailButTheSameAnswer() {
        resets.request("nobody@example.test");
        when(user.getStatus()).thenReturn(AccountStatus.DISABLED);
        resets.request(EMAIL);
        assertTrue(codes.isEmpty());
        assertEquals("ERR_OTP_RESEND_TOO_SOON", code(() -> resets.request("nobody@example.test")));
    }

    @Test
    void codesExpireAndGuessingIsLimited() {
        resets.request(EMAIL);
        for (int i = 0; i < 5; i++) {
            assertEquals("ERR_OTP_INVALID", code(() -> resets.verify(EMAIL, wrongCode())));
        }
        assertEquals("ERR_OTP_ATTEMPT_LIMIT", code(() -> resets.verify(EMAIL, codes.getFirst())));
        now = now.plusSeconds(61);
        resets.request(EMAIL);
        now = now.plusSeconds(300);
        assertEquals("ERR_OTP_EXPIRED", code(() -> resets.verify(EMAIL, codes.getLast())));
    }

    @Test
    void sendsAreCappedPerHour() {
        for (int i = 0; i < 5; i++) {
            resets.request(EMAIL);
            now = now.plusSeconds(61);
        }
        assertEquals("ERR_OTP_SEND_LIMIT", code(() -> resets.request(EMAIL)));
    }

    @Test
    void changeNeedsTheCurrentPasswordAndADifferentNewOne() {
        assertEquals("ERR_PASSWORD_CURRENT", code(() -> changes.change(EMAIL, "wrong", "brand-new-password")));
        assertEquals("ERR_PASSWORD_UNCHANGED", code(() -> changes.change(EMAIL, "old-password", "old-password")));
        assertEquals("ERR_VALIDATION", code(() -> changes.change(EMAIL, "old-password", "short")));
        verify(jdbc, never()).update(anyString(), any(), eq(id));
        changes.change(EMAIL, "old-password", "brand-new-password");
        verify(jdbc, times(1)).update(anyString(), any(), eq(id));
    }

    @Test
    void guessingTheCurrentPasswordIsBlocked() {
        for (int i = 0; i < 5; i++) {
            code(() -> changes.change(EMAIL, "wrong", "brand-new-password"));
        }
        assertEquals("ERR_PASSWORD_ATTEMPT_LIMIT",
                code(() -> changes.change(EMAIL, "old-password", "brand-new-password")));
        now = now.plusSeconds(901);
        changes.change(EMAIL, "old-password", "brand-new-password");
    }
}
