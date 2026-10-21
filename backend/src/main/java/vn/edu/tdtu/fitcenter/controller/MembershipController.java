
package vn.edu.tdtu.fitcenter.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import vn.edu.tdtu.fitcenter.dto.membership.MembershipResponse;
import vn.edu.tdtu.fitcenter.service.MembershipService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/memberships")
@RequiredArgsConstructor
public class MembershipController {

    private final MembershipService membershipService;

    @GetMapping("/me")
    public ResponseEntity<List<MembershipResponse>> getMyMemberships(
            Authentication authentication
    ) {
        return ResponseEntity.ok(
                membershipService.getMyMemberships(authentication.getName())
        );
    }
}
