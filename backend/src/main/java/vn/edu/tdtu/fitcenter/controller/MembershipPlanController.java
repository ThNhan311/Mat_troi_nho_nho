package vn.edu.tdtu.fitcenter.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vn.edu.tdtu.fitcenter.dto.membership.MembershipPlanResponse;
import vn.edu.tdtu.fitcenter.service.MembershipPlanService;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/membership-plans")
@RequiredArgsConstructor
public class MembershipPlanController {

    private final MembershipPlanService membershipPlanService;

    @GetMapping
    public ResponseEntity<List<MembershipPlanResponse>> getActivePlans() {

        return ResponseEntity.ok(
                membershipPlanService.getActivePlans()
        );
    }

    @GetMapping("/{id}")
    public ResponseEntity<MembershipPlanResponse> getPlanById(
            @PathVariable UUID id
    ) {
        return ResponseEntity.ok(
                membershipPlanService.getPlanById(id)
        );
    }
}