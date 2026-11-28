package vn.edu.tdtu.fitcenter.password;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import vn.edu.tdtu.fitcenter.activation.ActivationFailure;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

import java.time.Clock;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/** Changes the password of the signed-in account after checking the current one. */
@Service
public class PasswordChangeService {
    private static final int MAX_WRONG = 5;
    private static final long WRONG_WINDOW_SECONDS = 900;

    private record Wrong(Instant since, int count) {
    }

    private final UserRepository users;
    private final JdbcTemplate jdbc;
    private final PasswordEncoder encoder;
    private final Clock clock;
    /** Slows down guessing the current password with a stolen session. */
    private final Map<UUID, Wrong> wrong = new HashMap<>();

    public PasswordChangeService(UserRepository users, JdbcTemplate jdbc, PasswordEncoder encoder, Clock clock) {
        this.users = users;
        this.jdbc = jdbc;
        this.encoder = encoder;
        this.clock = clock;
    }

    public synchronized void change(String email, String currentPassword, String newPassword) {
        var user = users.findByEmailIgnoreCase(email)
                .filter(found -> found.getStatus() == AccountStatus.ACTIVE)
                .orElseThrow(() -> new ActivationFailure(403, "ERR_ACCOUNT_INACTIVE", "Tài khoản không hoạt động."));
        Instant now = clock.instant();
        var failed = wrong.get(user.getId());
        if (failed != null && !now.isBefore(failed.since().plusSeconds(WRONG_WINDOW_SECONDS))) {
            failed = null;
        }
        if (failed != null && failed.count() >= MAX_WRONG) {
            throw new ActivationFailure(429, "ERR_PASSWORD_ATTEMPT_LIMIT",
                    "Nhập sai quá nhiều lần. Hãy thử lại sau 15 phút.");
        }
        if (!encoder.matches(currentPassword, user.getPasswordHash())) {
            wrong.put(user.getId(), failed == null ? new Wrong(now, 1) : new Wrong(failed.since(), failed.count() + 1));
            // Not 401: the app would treat that as an expired session.
            throw new ActivationFailure(400, "ERR_PASSWORD_CURRENT", "Mật khẩu hiện tại không đúng.");
        }
        PasswordRules.check(newPassword);
        if (encoder.matches(newPassword, user.getPasswordHash())) {
            throw new ActivationFailure(400, "ERR_PASSWORD_UNCHANGED", "Mật khẩu mới phải khác mật khẩu hiện tại.");
        }
        if (jdbc.update("UPDATE users SET password_hash=? WHERE id=? AND status='ACTIVE'",
                encoder.encode(newPassword), user.getId()) != 1) {
            throw new ActivationFailure(409, "ERR_PASSWORD_CONFLICT", "Tài khoản vừa thay đổi. Hãy thử lại.");
        }
        wrong.remove(user.getId());
    }
}
