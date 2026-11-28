package vn.edu.tdtu.fitcenter.accountadmin;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.dto.membership.MembershipPlanCreateRequest;
import vn.edu.tdtu.fitcenter.dto.membership.MembershipPlanResponse;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

import java.util.List;
import java.util.UUID;

/**
 * Editing changes what is sold from now on; paid periods keep their own price and
 * duration snapshots. A plan somebody bought is only withdrawn from sale.
 */
@Service
@RequiredArgsConstructor
public class PlanAdminService {
    /** Tables that point at a plan. Some exist only with the rehearsal migrations. */
    private static final List<String> USERS_OF_PLANS = List.of("memberships", "payment_transactions",
            "membership_paid_periods", "renewal_payment_quotes");

    private final UserRepository users;
    private final JdbcTemplate jdbc;

    public enum Removal { DELETED, ARCHIVED }

    @Transactional(timeout = 10)
    public MembershipPlanResponse update(String actorEmail, UUID id, MembershipPlanCreateRequest request) {
        var admin = actor(actorEmail);
        int changed = jdbc.update(
                "UPDATE membership_plans SET name = ?, description = ?, duration_days = ?, price = ? "
                        + "WHERE id = ? AND status = 'ACTIVE'",
                request.name(), request.description(), request.durationDays(), request.price(), id);
        if (changed != 1) {
            throw missing();
        }
        audit(admin, "PLAN_UPDATED", id);
        return new MembershipPlanResponse(id, request.name(), request.description(), request.durationDays(),
                request.price());
    }

    @Transactional(timeout = 10)
    public Removal delete(String actorEmail, UUID id) {
        var admin = actor(actorEmail);
        // Locks the plan so that no sale can start while we decide.
        if (jdbc.queryForList("SELECT id FROM membership_plans WHERE id = ? AND status = 'ACTIVE' FOR UPDATE", id)
                .isEmpty()) {
            throw missing();
        }
        boolean used = USERS_OF_PLANS.stream().anyMatch(table -> exists(table)
                && Boolean.TRUE.equals(jdbc.queryForObject(
                        "SELECT EXISTS(SELECT 1 FROM " + table + " WHERE plan_id = ?)", Boolean.class, id)));
        if (used) {
            jdbc.update("UPDATE membership_plans SET status = 'INACTIVE' WHERE id = ?", id);
            audit(admin, "PLAN_ARCHIVED", id);
            return Removal.ARCHIVED;
        }
        jdbc.update("DELETE FROM membership_plans WHERE id = ?", id);
        audit(admin, "PLAN_DELETED", id);
        return Removal.DELETED;
    }

    private boolean exists(String table) {
        return Boolean.TRUE.equals(jdbc.queryForObject("SELECT to_regclass(?) IS NOT NULL", Boolean.class, table));
    }

    private void audit(UUID admin, String action, UUID plan) {
        jdbc.update("INSERT INTO audit_logs(actor_user_id,actor_type,action,entity_type,entity_id) "
                + "VALUES(?,'USER',?,'MEMBERSHIP_PLAN',?)", admin, action, plan);
    }

    private UUID actor(String email) {
        var actor = users.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new BadCredentialsException("Unknown actor"));
        if (actor.getRole() != Role.ADMIN || actor.getStatus() != AccountStatus.ACTIVE) {
            throw new AccessDeniedException("ACTIVE ADMIN required");
        }
        return actor.getId();
    }

    private static ResponseStatusException missing() {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, "Membership plan not found");
    }
}
