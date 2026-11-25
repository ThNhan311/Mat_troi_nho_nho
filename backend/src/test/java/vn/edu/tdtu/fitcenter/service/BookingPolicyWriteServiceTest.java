package vn.edu.tdtu.fitcenter.service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.dto.booking.BookingPolicyResponse;
import vn.edu.tdtu.fitcenter.dto.booking.BookingPolicyWriteRequest;
import vn.edu.tdtu.fitcenter.repository.BookingPolicyLock;
import vn.edu.tdtu.fitcenter.repository.BookingPolicyWriteRepository;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class BookingPolicyWriteServiceTest {
    private final UserRepository users = mock(UserRepository.class);
    private final BookingPolicyLock lock = mock(BookingPolicyLock.class);
    private final BookingPolicyWriteRepository repository = mock(BookingPolicyWriteRepository.class);
    private final Clock clock = mock(Clock.class);
    private final BookingPolicyWriteService service = new BookingPolicyWriteService(users, lock, repository, clock);
    private final User admin = User.builder().id(UUID.randomUUID()).email("policy-unit@example.invalid").role(Role.ADMIN).status(AccountStatus.ACTIVE).build();
    private final BookingPolicyWriteRequest request = new BookingPolicyWriteRequest(21, 3, 6, 8);

    @Test void samplesTimeAfterLockAndAccountRecheckWithDatabasePrecision() {
        Instant now = Instant.parse("2030-01-02T03:04:05.123456789Z");
        var expected = new BookingPolicyResponse(UUID.randomUUID(), 21, 3, 6, 8, now.truncatedTo(ChronoUnit.MICROS));
        when(users.findByEmailIgnoreCase(admin.getEmail())).thenReturn(Optional.of(admin));
        when(users.existsByIdAndRoleAndStatus(admin.getId(), Role.ADMIN, AccountStatus.ACTIVE)).thenReturn(true);
        when(clock.instant()).thenReturn(now);
        when(repository.store(request, expected.effectiveFrom(), admin.getId())).thenReturn(expected);
        assertEquals(expected, service.update(admin.getEmail(), request));
        var ordered = inOrder(lock, users, clock, repository);
        ordered.verify(users).findByEmailIgnoreCase(admin.getEmail());
        ordered.verify(lock).write();
        ordered.verify(users).existsByIdAndRoleAndStatus(admin.getId(), Role.ADMIN, AccountStatus.ACTIVE);
        ordered.verify(clock).instant();
        ordered.verify(repository).store(request, expected.effectiveFrom(), admin.getId());
    }

    @ParameterizedTest @EnumSource(value = Role.class, names = "ADMIN", mode = EnumSource.Mode.EXCLUDE)
    void nonAdminCannotAcquireWriteLock(Role role) {
        admin.setRole(role);
        when(users.findByEmailIgnoreCase(admin.getEmail())).thenReturn(Optional.of(admin));
        assertThrows(AccessDeniedException.class, () -> service.update(admin.getEmail(), request));
        verifyNoInteractions(lock, repository, clock);
    }

    @ParameterizedTest @EnumSource(value = AccountStatus.class, names = "ACTIVE", mode = EnumSource.Mode.EXCLUDE)
    void inactiveAdminCannotWrite(AccountStatus status) {
        admin.setStatus(status);
        when(users.findByEmailIgnoreCase(admin.getEmail())).thenReturn(Optional.of(admin));
        assertThrows(AccessDeniedException.class, () -> service.update(admin.getEmail(), request));
        verifyNoInteractions(lock, repository, clock);
    }

    @Test void missingPrincipalAccountCannotWrite() {
        when(users.findByEmailIgnoreCase(admin.getEmail())).thenReturn(Optional.empty());
        assertThrows(BadCredentialsException.class, () -> service.update(admin.getEmail(), request));
        verifyNoInteractions(lock, repository, clock);
    }

    @Test void accountRevokedWhileWaitingCannotWriteOrSampleDecisionTime() {
        when(users.findByEmailIgnoreCase(admin.getEmail())).thenReturn(Optional.of(admin));
        when(users.existsByIdAndRoleAndStatus(admin.getId(), Role.ADMIN, AccountStatus.ACTIVE)).thenReturn(false);
        assertThrows(AccessDeniedException.class, () -> service.update(admin.getEmail(), request));
        verify(lock).write();
        verifyNoInteractions(repository, clock);
    }
}
