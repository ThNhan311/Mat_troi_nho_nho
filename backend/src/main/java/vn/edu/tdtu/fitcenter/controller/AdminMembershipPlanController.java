package vn.edu.tdtu.fitcenter.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vn.edu.tdtu.fitcenter.dto.membership.MembershipPlanCreateRequest;
import vn.edu.tdtu.fitcenter.dto.membership.MembershipPlanResponse;
import vn.edu.tdtu.fitcenter.service.MembershipPlanCreateService;

@RestController
@RequestMapping("/api/v1/admin/membership-plans")
@RequiredArgsConstructor
public class AdminMembershipPlanController {
    private final MembershipPlanCreateService service;
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public MembershipPlanResponse create(Authentication auth, @Valid @RequestBody MembershipPlanCreateRequest request) {
        return service.create(auth.getName(), request);
    }
}