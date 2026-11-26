package vn.edu.tdtu.fitcenter.accountadmin;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vn.edu.tdtu.fitcenter.dto.membership.MembershipPlanCreateRequest;
import vn.edu.tdtu.fitcenter.dto.membership.MembershipPlanResponse;

import java.util.Map;
import java.util.UUID;

/** Under /api/v1/admin/**, so only ADMIN reaches these routes. */
@RestController
@RequestMapping("/api/v1/admin/membership-plans")
@RequiredArgsConstructor
public class PlanAdminController {
    private final PlanAdminService service;

    @PutMapping("/{id}")
    public MembershipPlanResponse update(Authentication admin, @PathVariable UUID id,
            @Valid @RequestBody MembershipPlanCreateRequest request) {
        return service.update(admin.getName(), id, request);
    }

    @DeleteMapping("/{id}")
    public Map<String, PlanAdminService.Removal> delete(Authentication admin, @PathVariable UUID id) {
        return Map.of("result", service.delete(admin.getName(), id));
    }
}
