package vn.edu.tdtu.fitcenter.password;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import vn.edu.tdtu.fitcenter.activation.ActivationFailure;
import vn.edu.tdtu.fitcenter.activation.ActivationMailer;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

/**
 * Forgotten password: email, six digit code, new password. Codes live only in
 * memory (no schema change), so a restart simply means asking for a new one.
 * Every address is answered alike, whether or not it has an account.
 */
@Service
public class PasswordResetService {
    static final int CODE_SECONDS = 300;
    private static final int RESEND_SECONDS = 60;
    private static final int SENDS_PER_HOUR = 5;
    private static final int MAX_ATTEMPTS = 5;

    private static final class State {
        Instant lastSentAt;
        Instant windowStartedAt;
        int sendCount;
        UUID userId;
        String otpDigest;
        Instant otpExpiresAt;
        int attempts;
        String grantDigest;
        Instant grantExpiresAt;

        void clearSecrets() {
            otpDigest = null;
            otpExpiresAt = null;
            grantDigest = null;
            grantExpiresAt = null;
            attempts = 0;
        }
    }

    private record Delivery(String email, String otp) {
    }

    private final UserRepository users;
    private final JdbcTemplate jdbc;
    private final ActivationMailer mailer;
    private final PasswordEncoder encoder;
    private final Clock clock;
    private final SecureRandom random = new SecureRandom();
    private final Map<String, State> states = new HashMap<>();

    public PasswordResetService(UserRepository users, JdbcTemplate jdbc, ActivationMailer mailer,
            PasswordEncoder encoder, Clock clock) {
        this.users = users;
        this.jdbc = jdbc;
        this.mailer = mailer;
        this.encoder = encoder;
        this.clock = clock;
    }

    public void request(String email) {
        String key = key(email);
        var delivery = prepare(key);
        if (delivery == null) {
            return;
        }
        try {
            // Outside the lock: a slow mail server must not stall other requests.
            mailer.sendPasswordReset(delivery.email(), delivery.otp());
        } catch (RuntimeException failure) {
            // Nothing arrived, so the person may ask again right away.
            forget(key);
            throw failure;
        }
    }

    private synchronized Delivery prepare(String key) {
        Instant now = clock.instant();
        states.values().removeIf(s -> !now.isBefore(s.windowStartedAt.plusSeconds(3600)));
        var state = states.get(key);
        if (state == null) {
            state = new State();
            state.windowStartedAt = now;
            states.put(key, state);
        } else if (state.lastSentAt != null && now.isBefore(state.lastSentAt.plusSeconds(RESEND_SECONDS))) {
            throw new ActivationFailure(429, "ERR_OTP_RESEND_TOO_SOON", "Hãy đợi 1 phút rồi gửi lại mã.");
        }
        if (state.sendCount >= SENDS_PER_HOUR) {
            throw new ActivationFailure(429, "ERR_OTP_SEND_LIMIT", "Bạn đã xin mã quá nhiều lần. Hãy thử lại sau.");
        }
        state.lastSentAt = now;
        state.sendCount++;
        state.clearSecrets();
        var user = users.findByEmailIgnoreCase(key).filter(PasswordResetService::mayReset).orElse(null);
        if (user == null) {
            state.userId = null;
            return null;
        }
        String otp = String.format(Locale.ROOT, "%06d", random.nextInt(1_000_000));
        state.userId = user.getId();
        state.otpDigest = encoder.encode(otp);
        state.otpExpiresAt = now.plusSeconds(CODE_SECONDS);
        return new Delivery(user.getEmail(), otp);
    }

    private synchronized void forget(String key) {
        var state = states.get(key);
        if (state != null) {
            state.clearSecrets();
            state.lastSentAt = null;
        }
    }

    public synchronized String verify(String email, String otp) {
        var state = states.get(key(email));
        if (state == null || state.otpDigest == null) {
            throw invalid();
        }
        Instant now = clock.instant();
        if (!now.isBefore(state.otpExpiresAt)) {
            throw new ActivationFailure(400, "ERR_OTP_EXPIRED", "Mã đã hết hạn. Hãy gửi lại mã.");
        }
        if (state.attempts >= MAX_ATTEMPTS) {
            throw new ActivationFailure(429, "ERR_OTP_ATTEMPT_LIMIT", "Nhập sai quá nhiều lần. Hãy gửi lại mã.");
        }
        if (!encoder.matches(otp, state.otpDigest)) {
            state.attempts++;
            throw invalid();
        }
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        String grant = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        state.clearSecrets();
        state.grantDigest = digest(grant);
        state.grantExpiresAt = now.plusSeconds(CODE_SECONDS);
        return grant;
    }

    public synchronized void reset(String grant, String password) {
        PasswordRules.check(password);
        String hash = digest(grant);
        Instant now = clock.instant();
        var state = states.values().stream()
                .filter(s -> hash.equals(s.grantDigest) && now.isBefore(s.grantExpiresAt))
                .findFirst().orElseThrow(PasswordResetService::invalid);
        if (jdbc.update("UPDATE users SET password_hash=? WHERE id=? AND status='ACTIVE' AND role IN ('MEMBER','PT')",
                encoder.encode(password), state.userId) != 1) {
            throw invalid();
        }
        state.clearSecrets();
    }

    private static boolean mayReset(User user) {
        return user.getStatus() == AccountStatus.ACTIVE
                && (user.getRole() == Role.MEMBER || user.getRole() == Role.PT);
    }

    private static ActivationFailure invalid() {
        return new ActivationFailure(400, "ERR_OTP_INVALID", "Mã hoặc phiên đặt lại mật khẩu không hợp lệ.");
    }

    private static String key(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }

    private static String digest(String value) {
        try {
            return HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
