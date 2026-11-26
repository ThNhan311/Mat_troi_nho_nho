package vn.edu.tdtu.fitcenter.kiosk;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * What the front desk and the kiosk screen share. Kept in memory on purpose: one
 * pending enrolment and a short list of recent scans, all gone after a restart.
 * No face data passes through here.
 */
@Component
@ConditionalOnProperty(name = "fitcenter.kiosk.enabled", havingValue = "true")
public class KioskDesk {
    static final Duration PENDING_TTL = Duration.ofMinutes(2);
    static final Duration REPEAT_WINDOW = Duration.ofSeconds(30);
    static final int RECENT_LIMIT = 10;

    public enum Status { WAITING, SUCCESS, DUPLICATE, FAILED, CANCELLED, EXPIRED }

    public record Enrollment(UUID requestId, UUID memberId, String memberName, Status status, Instant expiresAt) {
        Enrollment with(Status next) {
            return new Enrollment(requestId, memberId, memberName, next, expiresAt);
        }
    }

    public record Scan(UUID memberId, String memberName, String role, boolean membershipValid, Instant at) {
    }

    private final Clock clock;
    private final ArrayDeque<Scan> recent = new ArrayDeque<>();
    private Enrollment enrollment;

    public KioskDesk(Clock clock) {
        this.clock = clock;
    }

    /** A new request replaces whatever was waiting: the desk serves one person at a time. */
    public synchronized Enrollment request(UUID memberId, String memberName) {
        enrollment = new Enrollment(UUID.randomUUID(), memberId, memberName, Status.WAITING,
                clock.instant().plus(PENDING_TTL));
        return enrollment;
    }

    /** Latest request, or null if there has been none. */
    public synchronized Enrollment current() {
        if (enrollment != null && enrollment.status() == Status.WAITING
                && !clock.instant().isBefore(enrollment.expiresAt())) {
            enrollment = enrollment.with(Status.EXPIRED);
        }
        return enrollment;
    }

    public synchronized void cancel() {
        if (current() != null && enrollment.status() == Status.WAITING) {
            enrollment = enrollment.with(Status.CANCELLED);
        }
    }

    /** False when the request is no longer the one waiting (replaced, cancelled or expired). */
    public synchronized boolean finish(UUID requestId, Status outcome) {
        var latest = current();
        if (latest == null || !latest.requestId().equals(requestId) || latest.status() != Status.WAITING) {
            return false;
        }
        enrollment = latest.with(outcome);
        return true;
    }

    public synchronized void scanned(UUID memberId, String memberName, String role, boolean membershipValid) {
        var now = clock.instant();
        var last = recent.peekFirst();
        if (last != null && last.memberId().equals(memberId) && last.membershipValid() == membershipValid
                && now.isBefore(last.at().plus(REPEAT_WINDOW))) {
            return;
        }
        recent.addFirst(new Scan(memberId, memberName, role, membershipValid, now));
        while (recent.size() > RECENT_LIMIT) {
            recent.removeLast();
        }
    }

    public synchronized List<Scan> recent() {
        return new ArrayList<>(recent);
    }
}
