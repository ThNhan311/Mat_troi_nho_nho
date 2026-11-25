
package vn.edu.tdtu.fitcenter.service;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import vn.edu.tdtu.fitcenter.domain.entity.MembershipPlan;
import vn.edu.tdtu.fitcenter.domain.enums.MembershipPlanStatus;
import vn.edu.tdtu.fitcenter.dto.membership.MembershipPlanResponse;
import vn.edu.tdtu.fitcenter.repository.MembershipPlanRepository;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class MembershipPlanService {

    private final MembershipPlanRepository membershipPlanRepository;

    @Transactional(readOnly = true)
    public List<MembershipPlanResponse> getActivePlans() {

        return membershipPlanRepository
                .findByStatus(MembershipPlanStatus.ACTIVE)
                .stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public MembershipPlanResponse getPlanById(UUID id) {

        MembershipPlan plan = membershipPlanRepository.findById(id)
                .filter(p -> p.getStatus() == MembershipPlanStatus.ACTIVE)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND,
                        "Membership plan not found"
                ));

        return toResponse(plan);
    }

    private MembershipPlanResponse toResponse(MembershipPlan plan) {

        return new MembershipPlanResponse(
                plan.getId(),
                plan.getName(),
                plan.getDescription(),
                plan.getDurationDays(),
                plan.getPrice()
        );
    }
}
