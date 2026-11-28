package vn.edu.tdtu.fitcenter.accountadmin;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import vn.edu.tdtu.fitcenter.avatar.AvatarStore;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.kiosk.KioskFaces;
import vn.edu.tdtu.fitcenter.renewal.MembershipPeriodService;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/** Edit and delete Member / PT accounts, plus what the account table shows. */
@Service
@RequiredArgsConstructor
public class AccountAdminService {
    private final UserRepository users;
    private final JdbcTemplate jdbc;
    private final MembershipPeriodService periods;
    private final Clock clock;
    private final ObjectProvider<KioskFaces> faces;
    private final ObjectProvider<AvatarStore> avatars;
    private final TrainerPhones trainerPhones;
    private final TrainerGenders trainerGenders;

    /** planState: ACTIVE, EXPIRED, UPCOMING, INACTIVE or null when there is no package. */
    public record Detail(UUID profileId, String phone, String planName, LocalDate validUntil, String planState,
            String face, String gender) {
    }

    public record Deleted(UUID userId, UUID profileId) {
    }

    private record Target(UUID userId, UUID profileId, Role role, AccountStatus status, String email, boolean pending) {
    }

    @Transactional(readOnly = true)
    public List<Detail> details(String actorEmail) {
        actor(actorEmail);
        var today = LocalDate.now(clock.withZone(ZoneId.of("Asia/Ho_Chi_Minh")));
        var registry = faces.getIfAvailable();
        var result = new ArrayList<Detail>();
        jdbc.query("""
                SELECT p.id profile_id, p.phone, p.gender, m.id membership_id, m.status, m.start_date, m.expiry_date, mp.name plan_name
                FROM members p
                LEFT JOIN memberships m ON m.member_id = p.id AND m.status <> 'CANCELLED'
                LEFT JOIN membership_plans mp ON mp.id = m.plan_id
                """, row -> {
            var profile = row.getObject("profile_id", UUID.class);
            var membership = row.getObject("membership_id", UUID.class);
            String name = row.getString("plan_name");
            var start = row.getObject("start_date", LocalDate.class);
            var expiry = row.getObject("expiry_date", LocalDate.class);
            String state = null;
            if (membership != null) {
                state = "INACTIVE";
                if ("EXPIRED".equals(row.getString("status"))) {
                    state = "EXPIRED";
                } else if ("ACTIVE".equals(row.getString("status")) && start != null && expiry != null) {
                    state = start.isAfter(today) ? "UPCOMING"
                            : expiry.isBefore(today)
                                    || (periods.enabled() && !periods.covered(membership, today, today))
                            ? "EXPIRED" : "ACTIVE";
                }
                if (periods.enabled()) {
                    var period = periods.summary(membership, today);
                    if (period != null && period.get("plan_name_snapshot") != null) {
                        name = (String) period.get("plan_name_snapshot");
                    }
                }
            }
            result.add(new Detail(profile, row.getString("phone"), name, expiry, state, face(registry, profile),
                    row.getString("gender")));
        });
        jdbc.query("SELECT id FROM personal_trainers", row -> {
            var profile = row.getObject("id", UUID.class);
            result.add(new Detail(profile, trainerPhones.find(profile).orElse(null), null, null, null,
                    face(registry, profile), trainerGenders.find(profile).orElse(null)));
        });
        return result;
    }

    @Transactional(timeout = 10)
    public void update(String actorEmail, UUID userId, String fullName, String email, String phone,
            String gender) {
        var admin = actor(actorEmail);
        var target = target(userId);
        var name = fullName.trim();
        if (name.isEmpty() || name.codePointCount(0, name.length()) > 150) {
            throw new IllegalArgumentException("fullName");
        }
        var nextEmail = email.trim();
        if (!nextEmail.equals(target.email())) {
            if (!target.pending()) {
                throw conflict("Email can only change before the account is activated");
            }
            Integer used = jdbc.queryForObject(
                    "SELECT count(*) FROM users WHERE lower(email) = lower(?) AND id <> ?", Integer.class,
                    nextEmail, userId);
            if (used != null && used > 0) {
                throw conflict("Email is already used by another account");
            }
            jdbc.update("UPDATE users SET email = ? WHERE id = ?", nextEmail, userId);
            // A code sent to the old address must stop working.
            deleteActivation(target);
        }
        jdbc.update("UPDATE " + table(target.role()) + " SET full_name = ? WHERE id = ?", name, target.profileId());
        if (phone != null && target.role() == Role.MEMBER) {
            jdbc.update("UPDATE members SET phone = ? WHERE id = ?", phone, target.profileId());
        }
        if (gender != null && target.role() == Role.MEMBER) {
            jdbc.update("UPDATE members SET gender = ? WHERE id = ?", gender, target.profileId());
        }
        audit(admin, "ACCOUNT_UPDATED", userId);
        // The files are written after every database step has passed.
        if (gender != null && target.role() == Role.PT) {
            trainerGenders.save(target.profileId(), gender);
        }
        if (phone != null && target.role() == Role.PT) {
            trainerPhones.save(target.profileId(), phone);
        }
    }

    /**
     * Only accounts without history can go: packages, payments, bookings and the
     * audit trail all reference the account, and the database refuses to drop them.
     */
    @Transactional(timeout = 10)
    public Deleted delete(String actorEmail, UUID userId) {
        var admin = actor(actorEmail);
        var target = target(userId);
        try {
            deleteActivation(target);
            jdbc.update("DELETE FROM " + table(target.role()) + " WHERE id = ?", target.profileId());
            jdbc.update("DELETE FROM users WHERE id = ?", userId);
        } catch (DataIntegrityViolationException e) {
            throw conflict("Account has history and cannot be deleted");
        }
        audit(admin, "ACCOUNT_DELETED", userId);
        return new Deleted(userId, target.profileId());
    }

    /** Files and the kiosk face are only touched after the database delete has committed. */
    public void cleanUp(Deleted deleted) {
        var registry = faces.getIfAvailable();
        if (registry != null) {
            registry.requestRemoval(deleted.profileId());
        }
        var store = avatars.getIfAvailable();
        if (store != null) {
            store.delete(deleted.userId());
        }
        trainerPhones.remove(deleted.profileId());
        trainerGenders.remove(deleted.profileId());
    }

    private static String face(KioskFaces registry, UUID profile) {
        return registry == null ? null : registry.state(profile).name();
    }

    private Target target(UUID userId) {
        var rows = jdbc.query("""
                SELECT u.role, u.status, u.email,
                  (u.status = 'DISABLED'
                   AND EXISTS(SELECT 1 FROM audit_logs a WHERE a.entity_type = 'USER' AND a.entity_id = u.id
                              AND a.action = 'ACCOUNT_CREATED_PENDING_ACTIVATION')
                   AND NOT EXISTS(SELECT 1 FROM audit_logs a WHERE a.entity_type = 'USER' AND a.entity_id = u.id
                              AND a.action IN ('PT_ACCOUNT_ACTIVATED', 'MEMBER_ACCOUNT_ACTIVATED'))) pending,
                  COALESCE(m.id, t.id) profile_id
                FROM users u
                LEFT JOIN members m ON m.user_id = u.id
                LEFT JOIN personal_trainers t ON t.user_id = u.id
                WHERE u.id = ? AND u.role IN ('MEMBER', 'PT')
                FOR UPDATE OF u
                """, (row, i) -> new Target(userId, row.getObject("profile_id", UUID.class),
                Role.valueOf(row.getString("role")), AccountStatus.valueOf(row.getString("status")),
                row.getString("email"), row.getBoolean("pending")), userId);
        if (rows.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Account not found");
        }
        return rows.get(0);
    }

    private void deleteActivation(Target target) {
        var name = target.role() == Role.PT ? "pt_account_activation" : "member_account_activation";
        // These tables only exist where the activation migrations are applied.
        if (Boolean.TRUE.equals(jdbc.queryForObject("SELECT to_regclass(?) IS NOT NULL", Boolean.class, name))) {
            jdbc.update("DELETE FROM " + name + " WHERE user_id = ?", target.userId());
        }
    }

    private static String table(Role role) {
        return role == Role.PT ? "personal_trainers" : "members";
    }

    private void audit(UUID admin, String action, UUID userId) {
        jdbc.update("INSERT INTO audit_logs(actor_user_id,actor_type,action,entity_type,entity_id) VALUES(?,'USER',?,'USER',?)",
                admin, action, userId);
    }

    private UUID actor(String email) {
        var actor = users.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new BadCredentialsException("Unknown actor"));
        if (actor.getRole() != Role.ADMIN || actor.getStatus() != AccountStatus.ACTIVE) {
            throw new AccessDeniedException("ACTIVE ADMIN required");
        }
        return actor.getId();
    }

    private static ResponseStatusException conflict(String reason) {
        return new ResponseStatusException(HttpStatus.CONFLICT, reason);
    }
}
