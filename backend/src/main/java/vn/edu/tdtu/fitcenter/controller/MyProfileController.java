package vn.edu.tdtu.fitcenter.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.repository.MemberRepository;
import vn.edu.tdtu.fitcenter.repository.PersonalTrainerRepository;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

import java.util.UUID;

/** Read only and always about the signed-in account; there is no way to name another user. */
@RestController
@RequiredArgsConstructor
public class MyProfileController {
    private final UserRepository users;
    private final MemberRepository members;
    private final PersonalTrainerRepository trainers;

    public record MyProfile(UUID profileId, String fullName) {
    }

    @GetMapping("/api/v1/profile/me")
    @PreAuthorize("hasAnyRole('MEMBER','PT')")
    public ResponseEntity<MyProfile> mine(Authentication authentication) {
        var user = users.findByEmailIgnoreCase(authentication.getName())
                .filter(found -> found.getStatus() == AccountStatus.ACTIVE)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.FORBIDDEN, "Account is not active"));
        var profile = user.getRole() == Role.PT
                ? trainers.findByUser_Id(user.getId())
                        .map(trainer -> new MyProfile(trainer.getId(), trainer.getFullName()))
                : members.findByUser_Id(user.getId())
                        .map(member -> new MyProfile(member.getId(), member.getFullName()));
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(profile.orElseThrow(
                () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Profile not found")));
    }
}
