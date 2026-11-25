package vn.edu.tdtu.fitcenter.service;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.dto.booking.ServiceEligibilityResponse;
import vn.edu.tdtu.fitcenter.repository.*;

import java.time.Clock;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ServiceEligibilityService {
    private final UserRepository users;
    private final PersonalTrainerRepository trainers;
    private final BookingRepository bookings;
    private final MemberRepository members;
    private final MembershipRepository memberships;
    private final ServiceEligibilityValidator validator;
    private final Clock clock;

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ, timeout = 10)
    public ServiceEligibilityResponse check(String email, UUID id) {
        // First SELECT establishes the snapshot; all following reads are non-locking in that snapshot.
        var actor = users.findByEmailIgnoreCase(email).orElseThrow(() -> new BadCredentialsException("User not found"));
        var now = clock.instant();
        if (actor.getRole() != Role.PT || actor.getStatus() != AccountStatus.ACTIVE) {
            throw new AccessDeniedException("Only ACTIVE personal trainers can check service eligibility");
        }
        var trainer = trainers.findByUser_Id(actor.getId()).orElseThrow(() -> missing("PT profile not found"));
        var booking = bookings.findById(id).orElseThrow(() -> missing("Booking not found"));
        if (!trainer.getId().equals(booking.getPtId())) throw missing("Booking not found");
        var member = members.findById(booking.getMemberId()).orElseThrow(() -> missing("Member profile not found"));
        var membership = memberships.findCurrentForServiceEligibility(member.getId()).orElse(null);
        return validator.check(booking, member.getUser(), membership, now);
    }

    private static ResponseStatusException missing(String message) { return new ResponseStatusException(HttpStatus.NOT_FOUND, message); }
}
