package vn.edu.tdtu.fitcenter.kiosk;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.MembershipStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.renewal.MembershipPeriodService;
import vn.edu.tdtu.fitcenter.repository.MemberRepository;
import vn.edu.tdtu.fitcenter.repository.MembershipRepository;
import vn.edu.tdtu.fitcenter.repository.PersonalTrainerRepository;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.UUID;

/** Read-only lookups by member or trainer profile id. Nothing is written to the database. */
@Service
@RequiredArgsConstructor
@ConditionalOnProperty(name = "fitcenter.kiosk.enabled", havingValue = "true")
public class KioskMembers {
    private final MemberRepository members;
    private final PersonalTrainerRepository trainers;
    private final MembershipRepository memberships;
    private final MembershipPeriodService periods;
    private final Clock clock;

    /** For a trainer, membershipValid only means the staff account is active. */
    public record Card(UUID memberId, String fullName, Role role, boolean membershipValid, LocalDate validUntil) {
    }

    private record Person(String fullName, Role role, AccountStatus status) {
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public Card card(UUID profileId) {
        var person = find(profileId);
        if (person.role() == Role.PT) {
            if (person.status() != AccountStatus.ACTIVE) {
                throw missing();
            }
            return new Card(profileId, person.fullName(), Role.PT, true, null);
        }
        var today = LocalDate.now(clock.withZone(ZoneId.of("Asia/Ho_Chi_Minh")));
        // Same date rules the Member app shows: active, already started, not past expiry, paid.
        var valid = person.status() != AccountStatus.ACTIVE
                ? java.util.Optional.<LocalDate>empty()
                : memberships.findByMember_Id(profileId).stream()
                        .filter(m -> m.getStatus() == MembershipStatus.ACTIVE
                                && m.getStartDate() != null && m.getExpiryDate() != null
                                && !m.getStartDate().isAfter(today) && !m.getExpiryDate().isBefore(today)
                                && (!periods.enabled() || periods.covered(m.getId(), today, today)))
                        .map(m -> m.getExpiryDate())
                        .findFirst();
        return new Card(profileId, person.fullName(), Role.MEMBER, valid.isPresent(), valid.orElse(null));
    }

    /**
     * Faces are taken while the account is being created, so accounts still waiting
     * for activation are accepted. Suspended ones are not.
     */
    @Transactional(readOnly = true)
    public String nameForEnrollment(UUID profileId) {
        var person = find(profileId);
        if (person.status() == AccountStatus.SUSPENDED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Account is suspended");
        }
        return person.fullName();
    }

    private Person find(UUID profileId) {
        var member = members.findById(profileId)
                .filter(m -> m.getUser().getRole() == Role.MEMBER)
                .map(m -> new Person(m.getFullName(), Role.MEMBER, m.getUser().getStatus()));
        return member.or(() -> trainers.findById(profileId)
                        .filter(t -> t.getUser().getRole() == Role.PT)
                        .map(t -> new Person(t.getFullName(), Role.PT, t.getUser().getStatus())))
                .orElseThrow(KioskMembers::missing);
    }

    private static ResponseStatusException missing() {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, "Account not found");
    }
}
