package vn.edu.tdtu.fitcenter.service;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.tdtu.fitcenter.dto.booking.BookingPolicyResponse;
import vn.edu.tdtu.fitcenter.exception.BookingPolicyNotFoundException;
import vn.edu.tdtu.fitcenter.repository.BookingPolicyRepository;

import java.time.Clock;

@Service
@RequiredArgsConstructor
public class BookingPolicyService {
    private final BookingPolicyRepository repository;
    private final Clock clock;

    @Transactional(readOnly = true)
    public BookingPolicyResponse getEffectivePolicy() {
        var policy = repository.findByActiveTrueAndEffectiveFromLessThanEqual(clock.instant())
                .orElseThrow(BookingPolicyNotFoundException::new);
        return new BookingPolicyResponse(policy.getId(), policy.getMaxAdvanceDays(), policy.getMinNoticeHours(),
                policy.getCancelDeadlineHours(), policy.getMaxFutureBookings(), policy.getEffectiveFrom());
    }
}
