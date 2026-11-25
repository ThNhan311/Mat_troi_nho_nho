package vn.edu.tdtu.fitcenter.controller;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import vn.edu.tdtu.fitcenter.activation.MemberActivationService;
import java.util.Map;
import vn.edu.tdtu.fitcenter.activation.ActivationRequests.*;
@RestController @RequestMapping("/api/v1/auth/member-activation") @RequiredArgsConstructor
public class MemberActivationController {
    private final MemberActivationService service;
    @PostMapping("/request-otp") public ResponseEntity<?> request(@Valid @RequestBody EmailRequest r){service.request(r.email());return response(202,Map.of("message","If eligible, a code is sent to the registered email","expiresInSeconds",300,"resendAfterSeconds",60));}
    @PostMapping("/verify-otp") public ResponseEntity<?> verify(@Valid @RequestBody VerifyRequest r){return response(200,Map.of("verificationToken",service.verify(r.email(),r.otp()),"expiresInSeconds",300));}
    @PostMapping("/password") public ResponseEntity<?> password(@Valid @RequestBody PasswordRequest r){service.password(r.verificationToken(),r.password());return response(200,Map.of("status","ACTIVE"));}
    private ResponseEntity<?> response(int status,Object body){return ResponseEntity.status(status).cacheControl(CacheControl.noStore()).body(body);}
}
