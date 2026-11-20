package vn.edu.tdtu.fitcenter.service;

import org.junit.jupiter.api.Test;
import vn.edu.tdtu.fitcenter.domain.entity.BookingPolicy;
import vn.edu.tdtu.fitcenter.dto.booking.BookingPolicyResponse;
import vn.edu.tdtu.fitcenter.exception.BookingPolicyNotFoundException;
import vn.edu.tdtu.fitcenter.repository.BookingPolicyRepository;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class BookingPolicyServiceTest {
    private final Instant now = Instant.parse("2030-01-02T03:04:05.123456Z");
    private final BookingPolicyRepository repository = mock(BookingPolicyRepository.class);

    @Test void mapsDatabaseValuesAndUsesInjectedClock() {
        var policy = policy();
        when(repository.findByActiveTrueAndEffectiveFromLessThanEqual(now)).thenReturn(Optional.of(policy));
        var service = new BookingPolicyService(repository, Clock.fixed(now, ZoneOffset.UTC));

        assertEquals(new BookingPolicyResponse(policy.getId(), 21, 3, 6, 8, now), service.getEffectivePolicy());
        verify(repository).findByActiveTrueAndEffectiveFromLessThanEqual(now);
        verifyNoMoreInteractions(repository);
    }

    @Test void missingEffectivePolicyThrowsWithoutFallback() {
        when(repository.findByActiveTrueAndEffectiveFromLessThanEqual(now)).thenReturn(Optional.empty());
        var service = new BookingPolicyService(repository, Clock.fixed(now, ZoneOffset.UTC));

        assertThrows(BookingPolicyNotFoundException.class, service::getEffectivePolicy);
        verify(repository).findByActiveTrueAndEffectiveFromLessThanEqual(now);
        verifyNoMoreInteractions(repository);
    }

    @Test void reevaluatesTimeOnEachRead() {
        Clock clock = mock(Clock.class);
        Instant before = now.minusNanos(1000);
        when(clock.instant()).thenReturn(before, now);
        when(repository.findByActiveTrueAndEffectiveFromLessThanEqual(before)).thenReturn(Optional.empty());
        when(repository.findByActiveTrueAndEffectiveFromLessThanEqual(now)).thenReturn(Optional.of(policy()));
        var service = new BookingPolicyService(repository, clock);

        assertThrows(BookingPolicyNotFoundException.class, service::getEffectivePolicy);
        assertEquals(now, service.getEffectivePolicy().effectiveFrom());
        verify(clock, times(2)).instant();
    }

    private BookingPolicy policy() {
        return BookingPolicy.builder().id(UUID.randomUUID()).maxAdvanceDays(21).minNoticeHours(3)
                .cancelDeadlineHours(6).maxFutureBookings(8).effectiveFrom(now).active(true).build();
    }
}
