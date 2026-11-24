
package vn.edu.tdtu.fitcenter.service;

import lombok.RequiredArgsConstructor;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import vn.edu.tdtu.fitcenter.domain.entity.Member;
import vn.edu.tdtu.fitcenter.domain.entity.Membership;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.domain.enums.MembershipStatus;
import vn.edu.tdtu.fitcenter.dto.membership.MembershipResponse;
import vn.edu.tdtu.fitcenter.repository.MemberRepository;
import vn.edu.tdtu.fitcenter.repository.MembershipRepository;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

import java.util.List;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;

@Service
@RequiredArgsConstructor
public class MembershipService {

    private final MembershipRepository membershipRepository;
    private final MemberRepository memberRepository;
    private final UserRepository userRepository;
    private final Clock clock;
    private vn.edu.tdtu.fitcenter.renewal.MembershipPeriodService periods;
    @org.springframework.beans.factory.annotation.Autowired public void setPeriods(vn.edu.tdtu.fitcenter.renewal.MembershipPeriodService periods){this.periods=periods;}

    @Transactional(readOnly = true, isolation = org.springframework.transaction.annotation.Isolation.REPEATABLE_READ)
    public List<MembershipResponse> getMyMemberships(String email) {

        // 1. Tim tai khoan dang dang nhap
        User user = userRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() ->
                        new BadCredentialsException("User not found")
                );

        // 2. Kiem tra trang thai tai khoan
        if (user.getStatus() != AccountStatus.ACTIVE) {
            throw new AccessDeniedException("Account is not active");
        }

        // 3. Kiem tra vai tro
        if (user.getRole() != Role.MEMBER) {
            throw new AccessDeniedException(
                    "Only members can access this resource"
            );
        }

        // 4. Tim ho so Member tu users.id
        Member member = memberRepository.findByUser_Id(user.getId())
                .orElseThrow(() ->
                        new ResponseStatusException(
                                HttpStatus.NOT_FOUND,
                                "Member profile not found"
                        )
                );

        // 5. Lay Membership bang members.id
        return membershipRepository.findByMember_Id(member.getId())
                .stream()
                .map(this::toResponse)
                .toList();
    }

    private MembershipResponse toResponse(Membership membership) {

        var current=periods!=null&&periods.enabled()?periods.summary(membership.getId(),LocalDate.now(clock.withZone(ZoneId.of("Asia/Ho_Chi_Minh")))):null;
        return new MembershipResponse(
                membership.getId(),
                current==null?membership.getPlan().getId():(java.util.UUID)current.get("plan_id"),
                current==null||current.get("plan_name_snapshot")==null?membership.getPlan().getName():(String)current.get("plan_name_snapshot"),
                membership.getStartDate(),
                membership.getExpiryDate(),
                effectiveStatus(membership)
        );
    }

    private MembershipStatus effectiveStatus(Membership membership) {
        if (membership.getStatus() != MembershipStatus.ACTIVE) {
            return membership.getStatus();
        }
        LocalDate today = LocalDate.now(clock.withZone(ZoneId.of("Asia/Ho_Chi_Minh")));
        if (membership.getStartDate() == null || membership.getExpiryDate() == null
                || membership.getStartDate().isAfter(today)) {
            return MembershipStatus.PENDING_ACTIVATION;
        }
        if(periods!=null&&periods.enabled()&&!periods.covered(membership.getId(),today,today))return MembershipStatus.EXPIRED;
        return membership.getExpiryDate().isBefore(today)
                ? MembershipStatus.EXPIRED : MembershipStatus.ACTIVE;
    }
}
