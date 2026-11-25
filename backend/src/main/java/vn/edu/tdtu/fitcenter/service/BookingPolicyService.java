package vn.edu.tdtu.fitcenter.service;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.tdtu.fitcenter.dto.booking.BookingPolicyResponse;
import vn.edu.tdtu.fitcenter.exception.BookingPolicyNotFoundException;
import vn.edu.tdtu.fitcenter.repository.BookingPolicyRepository;
import vn.edu.tdtu.fitcenter.repository.BookingPolicyLock;

import java.time.Clock;
import java.time.Instant;

@Service
@RequiredArgsConstructor
public class BookingPolicyService {
    private final BookingPolicyRepository repository;
    private final Clock clock;
    private final BookingPolicyLock lock;

    public record Snapshot(Instant now, BookingPolicyResponse policy) {}

    @Transactional(readOnly = true, timeout = 10)
    public BookingPolicyResponse getEffectivePolicy() {
        return getEffectiveSnapshot().policy();
    }

    /** Hold the read lock until the caller transaction ends; sample time only after any PUT wait. */
    @Transactional(readOnly = true, timeout = 10)
    public Snapshot getEffectiveSnapshot() {
        var now = lockAndGetTime();
        return new Snapshot(now, getEffectivePolicyAt(now));
    }

    /** R03 validates membership before looking up policy, using this same locked time sample. */
    @Transactional(readOnly = true, timeout = 10)
    public Instant lockAndGetTime() {
        lock.read();
        return clock.instant();
    }

    /** Share the same time sample with a booking transaction; no fallback or write. */
    @Transactional(readOnly = true)
    public BookingPolicyResponse getEffectivePolicyAt(Instant now) {
        var policy = repository.findByActiveTrueAndEffectiveFromLessThanEqual(now)
                .orElseThrow(BookingPolicyNotFoundException::new);
        return new BookingPolicyResponse(policy.getId(), policy.getMaxAdvanceDays(), policy.getMinNoticeHours(),
                policy.getCancelDeadlineHours(), policy.getMaxFutureBookings(), policy.getEffectiveFrom());
    }
}
