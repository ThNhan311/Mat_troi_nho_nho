package vn.edu.tdtu.fitcenter.http;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.security.SecureRandom;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

/** Committed rows are visible to real HTTP connections; cleanup only uses this instance's IDs. */
final class HttpBaselineFixture implements AutoCloseable {
    static final class Actor {
        final UUID userId = UUID.randomUUID();
        final UUID profileId = UUID.randomUUID();
        final String role;
        final String label;
        final String email;
        final String password = randomSecret();

        Actor(String role, String label) {
            this.role = role;
            this.label = label;
            this.email = "http-baseline-" + label + "-" + userId + "@example.invalid";
        }
        // Deliberately no record/toString exposing credentials in assertion output.
    }

    record Slot(UUID id, UUID ptId, OffsetDateTime start, OffsetDateTime end, String status) {}
    record Booking(UUID id, UUID memberId, Slot slot, String status,
                   String cancelledBy, String reason, OffsetDateTime cancelledAt, OffsetDateTime completedAt) {}

    final Actor admin = new Actor("ADMIN", "admin");
    final Actor memberA = new Actor("MEMBER", "member-a");
    final Actor memberB = new Actor("MEMBER", "member-b");
    final Actor ptA = new Actor("PT", "pt-a");
    final Actor ptB = new Actor("PT", "pt-b");
    final List<Actor> actors = List.of(admin, memberA, memberB, ptA, ptB);
    final UUID planId = UUID.randomUUID();
    final UUID inactivePlanId = UUID.randomUUID();
    final UUID membershipA = UUID.randomUUID();
    final UUID membershipB = UUID.randomUUID();
    final String planName = "HTTP baseline " + planId;
    final LocalDate today = LocalDate.now(ZoneId.of("Asia/Ho_Chi_Minh"));
    final LocalDate expiry = today.plusDays(29);
    final OffsetDateTime future = OffsetDateTime.now(ZoneOffset.UTC).plusDays(3).truncatedTo(ChronoUnit.DAYS);
    final OffsetDateTime past = future.minusDays(6);
    final Slot available = slot(ptA, future.plusHours(9), "AVAILABLE");
    final Slot booked = slot(ptA, future.plusHours(10), "BOOKED");
    final Slot cancelled = slot(ptA, future.plusHours(11), "AVAILABLE");
    final Slot completed = slot(ptA, past.plusHours(9), "DISABLED");
    final Slot pastAvailable = slot(ptA, past.plusHours(10), "AVAILABLE");
    final Slot other = slot(ptB, future.plusDays(1).plusHours(10), "BOOKED");
    final List<Slot> slots = List.of(available, booked, cancelled, completed, pastAvailable, other);
    final Booking confirmedA = booking(memberA, booked, "CONFIRMED", null, null, null, null);
    final Booking cancelledA = booking(memberA, cancelled, "CANCELLED", "PT", "Synthetic cancellation",
            future.minusDays(1), null);
    final Booking completedA = booking(memberA, completed, "COMPLETED", null, null, null, completed.end());
    final Booking confirmedB = booking(memberB, other, "CONFIRMED", null, null, null, null);
    final List<Booking> bookings = List.of(confirmedA, cancelledA, completedA, confirmedB);
    private final JdbcTemplate jdbc;
    private final TransactionTemplate transaction;
    private boolean seeded;

    HttpBaselineFixture(JdbcTemplate jdbc, TransactionTemplate transaction) {
        this.jdbc = jdbc;
        this.transaction = transaction;
    }

    static String randomSecret() {
        byte[] bytes = new byte[32];
        new SecureRandom().nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    void seed(PasswordEncoder encoder) {
        if (seeded) throw new IllegalStateException("Fixture already seeded");
        transaction.executeWithoutResult(status -> {
            for (Actor actor : actors) {
                String hash = encoder.encode(actor.password);
                if (!encoder.matches(actor.password, hash)) throw new IllegalStateException("BCrypt verification failed");
                jdbc.update("INSERT INTO users(id,email,password_hash,role,status) VALUES(?,?,?,?,'ACTIVE')",
                        actor.userId, actor.email, hash, actor.role);
                if (actor.role.equals("MEMBER")) {
                    jdbc.update("INSERT INTO members(id,user_id,full_name) VALUES(?,?,?)",
                            actor.profileId, actor.userId, actor.label);
                } else if (actor.role.equals("PT")) {
                    jdbc.update("INSERT INTO personal_trainers(id,user_id,full_name,bio,specialization,experience_summary) VALUES(?,?,?,?,?,?)",
                            actor.profileId, actor.userId, actor.label, "Synthetic bio", "Synthetic training", "Fixture only");
                }
            }
            jdbc.update("INSERT INTO membership_plans(id,name,description,duration_days,price,status) VALUES(?,?,?,30,?,'ACTIVE')",
                    planId, planName, "Synthetic plan", new BigDecimal("100000.00"));
            jdbc.update("INSERT INTO membership_plans(id,name,duration_days,price,status) VALUES(?,?,30,0,'INACTIVE')",
                    inactivePlanId, "Inactive HTTP baseline");
            jdbc.update("INSERT INTO memberships(id,member_id,plan_id,start_date,expiry_date,status) VALUES(?,?,?,?,?,'ACTIVE')",
                    membershipA, memberA.profileId, planId, today, expiry);
            jdbc.update("INSERT INTO memberships(id,member_id,plan_id,start_date,expiry_date,status) VALUES(?,?,?,?,?,'ACTIVE')",
                    membershipB, memberB.profileId, planId, today, expiry);
            for (Slot slot : slots) {
                jdbc.update("INSERT INTO availability_slots(id,pt_id,start_at,end_at,status) VALUES(?,?,?,?,?)",
                        slot.id(), slot.ptId(), slot.start(), slot.end(), slot.status());
            }
            for (Booking booking : bookings) {
                Slot slot = booking.slot();
                jdbc.update("INSERT INTO bookings(id,member_id,pt_id,slot_id,start_at,end_at,status,cancelled_by,cancel_reason,cancelled_at,completed_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)",
                        booking.id(), booking.memberId(), slot.ptId(), slot.id(), slot.start(), slot.end(),
                        booking.status(), booking.cancelledBy(), booking.reason(), booking.cancelledAt(), booking.completedAt());
            }
        });
        seeded = true;
    }

    @Override public void close() {
        if (!seeded) return;
        transaction.executeWithoutResult(status -> {
            for (Booking booking : bookings) deleteOne("bookings", booking.id());
            for (Slot slot : slots) deleteOne("availability_slots", slot.id());
            deleteOne("memberships", membershipA);
            deleteOne("memberships", membershipB);
            deleteOne("membership_plans", planId);
            deleteOne("membership_plans", inactivePlanId);
            for (Actor actor : actors) {
                if (actor.role.equals("MEMBER")) deleteOne("members", actor.profileId);
                if (actor.role.equals("PT")) deleteOne("personal_trainers", actor.profileId);
                // Do not cascade-delete notifications created by another writer.
                int deleted = jdbc.update("DELETE FROM users WHERE id=? AND NOT EXISTS(SELECT 1 FROM notifications WHERE user_id=?)",
                        actor.userId, actor.userId);
                if (deleted != 1) throw new IllegalStateException("Fixture user cleanup refused; transaction rolled back");
            }
        });
        seeded = false;
    }

    private void deleteOne(String table, UUID id) {
        // table is only ever a literal from this class; values remain bound parameters.
        if (jdbc.update("DELETE FROM " + table + " WHERE id=?", id) != 1) {
            throw new IllegalStateException("Fixture cleanup mismatch; transaction rolled back");
        }
    }

    private static Slot slot(Actor pt, OffsetDateTime start, String status) {
        return new Slot(UUID.randomUUID(), pt.profileId, start, start.plusHours(1), status);
    }

    private static Booking booking(Actor member, Slot slot, String status, String by, String reason,
                                   OffsetDateTime cancelledAt, OffsetDateTime completedAt) {
        return new Booking(UUID.randomUUID(), member.profileId, slot, status, by, reason, cancelledAt, completedAt);
    }
}
