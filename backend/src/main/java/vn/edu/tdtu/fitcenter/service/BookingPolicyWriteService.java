package vn.edu.tdtu.fitcenter.service;

import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.dto.booking.BookingPolicyResponse;
import vn.edu.tdtu.fitcenter.dto.booking.BookingPolicyWriteRequest;
import vn.edu.tdtu.fitcenter.repository.BookingPolicyLock;
import vn.edu.tdtu.fitcenter.repository.BookingPolicyWriteRepository;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

import java.time.Clock;
import java.time.temporal.ChronoUnit;

@Service
@RequiredArgsConstructor
public class BookingPolicyWriteService {
    private final UserRepository users;
    private final BookingPolicyLock lock;
    private final BookingPolicyWriteRepository repository;
    private final Clock clock;

    @Transactional(isolation = Isolation.READ_COMMITTED, timeout = 10)
    public BookingPolicyResponse update(String email, BookingPolicyWriteRequest request) {
        var user = users.findByEmailIgnoreCase(email).orElseThrow(() -> new BadCredentialsException("User not found"));
        if (user.getRole() != Role.ADMIN || user.getStatus() != AccountStatus.ACTIVE) {
            throw new AccessDeniedException("Only ACTIVE admins can configure booking policy");
        }
        lock.write();
        if (!users.existsByIdAndRoleAndStatus(user.getId(), Role.ADMIN, AccountStatus.ACTIVE)) {
            throw new AccessDeniedException("Admin account is no longer ACTIVE");
        }
        return repository.store(request, clock.instant().truncatedTo(ChronoUnit.MICROS), user.getId());
    }
}
