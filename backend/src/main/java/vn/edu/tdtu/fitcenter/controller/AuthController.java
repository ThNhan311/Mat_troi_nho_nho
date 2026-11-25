package vn.edu.tdtu.fitcenter.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vn.edu.tdtu.fitcenter.dto.auth.LoginRequest;
import vn.edu.tdtu.fitcenter.dto.auth.LoginResponse;
import vn.edu.tdtu.fitcenter.dto.auth.RefreshTokenRequest;
import vn.edu.tdtu.fitcenter.service.AuthService;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(
            @Valid @RequestBody LoginRequest request
    ) {

        LoginResponse response =
                authService.login(request);

        return ResponseEntity.ok(response);
    }

    @PostMapping("/refresh")
    public ResponseEntity<LoginResponse> refresh(
            @Valid @RequestBody RefreshTokenRequest request
    ) {

        LoginResponse response =
                authService.refresh(request);

        return ResponseEntity.ok(response);
    }
}