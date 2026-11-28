package vn.edu.tdtu.fitcenter.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import vn.edu.tdtu.fitcenter.dto.request.PtProfileWriteRequest;
import vn.edu.tdtu.fitcenter.dto.response.PersonalTrainerResponse;
import vn.edu.tdtu.fitcenter.service.PtProfileService;

/** Always about the signed-in trainer; there is no way to name another one. */
@RestController
@RequestMapping("/api/v1/pt/profile")
@RequiredArgsConstructor
public class PtProfileController {
    private final PtProfileService service;

    @GetMapping
    public PersonalTrainerResponse mine(Authentication authentication) {
        return service.mine(authentication.getName());
    }

    @PutMapping
    public PersonalTrainerResponse update(Authentication authentication,
            @Valid @RequestBody PtProfileWriteRequest request) {
        return service.update(authentication.getName(), request);
    }
}
