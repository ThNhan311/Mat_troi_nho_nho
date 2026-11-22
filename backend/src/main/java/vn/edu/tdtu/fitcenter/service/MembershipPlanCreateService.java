package vn.edu.tdtu.fitcenter.service;

import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.tdtu.fitcenter.domain.entity.MembershipPlan;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.MembershipPlanStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.dto.membership.MembershipPlanCreateRequest;
import vn.edu.tdtu.fitcenter.dto.membership.MembershipPlanResponse;
import vn.edu.tdtu.fitcenter.repository.MembershipPlanRepository;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

@Service
@RequiredArgsConstructor
public class MembershipPlanCreateService {
    private final UserRepository users;
    private final MembershipPlanRepository plans;

    @Transactional(timeout = 10)
    public MembershipPlanResponse create(String email, MembershipPlanCreateRequest request) {
        var actor = users.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new BadCredentialsException("User not found"));
        if (actor.getRole() != Role.ADMIN || actor.getStatus() != AccountStatus.ACTIVE
                || !users.existsByIdAndRoleAndStatus(actor.getId(), Role.ADMIN, AccountStatus.ACTIVE)) {
            throw new AccessDeniedException("Only ACTIVE admins can create plans");
        }
        var plan = plans.saveAndFlush(MembershipPlan.builder()
                .name(request.name()).description(request.description()).durationDays(request.durationDays())
                .price(request.price()).status(MembershipPlanStatus.ACTIVE).build());
        return new MembershipPlanResponse(plan.getId(), plan.getName(), plan.getDescription(),
                plan.getDurationDays(), plan.getPrice());
    }
}