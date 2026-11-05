
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

    @Transactional(readOnly = true)
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

        return new MembershipResponse(
                membership.getId(),
                membership.getPlan().getId(),
                membership.getPlan().getName(),
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
        return membership.getExpiryDate().isBefore(today)
                ? MembershipStatus.EXPIRED : MembershipStatus.ACTIVE;
    }
}
