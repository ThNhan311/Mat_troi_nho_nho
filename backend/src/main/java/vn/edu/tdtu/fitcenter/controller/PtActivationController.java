package vn.edu.tdtu.fitcenter.controller;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import vn.edu.tdtu.fitcenter.activation.PtActivationService;
import java.util.Map;
@RestController @RequestMapping("/api/v1/auth/pt-activation") @RequiredArgsConstructor
public class PtActivationController {
    private final PtActivationService service;
    public record EmailRequest(@NotBlank @Email @Size(max=255) @tools.jackson.databind.annotation.JsonDeserialize(using=vn.edu.tdtu.fitcenter.activation.StrictActivationText.class) String email){@Override public String toString(){return "EmailRequest[redacted]";}}
    public record VerifyRequest(@NotBlank @Email @Size(max=255) @tools.jackson.databind.annotation.JsonDeserialize(using=vn.edu.tdtu.fitcenter.activation.StrictActivationText.class) String email,@NotNull @Pattern(regexp="[0-9]{6}") @tools.jackson.databind.annotation.JsonDeserialize(using=vn.edu.tdtu.fitcenter.activation.StrictActivationText.class) String otp){@Override public String toString(){return "VerifyRequest[redacted]";}}
    public record PasswordRequest(@NotBlank @Size(min=43,max=43) @tools.jackson.databind.annotation.JsonDeserialize(using=vn.edu.tdtu.fitcenter.activation.StrictActivationText.class) String verificationToken,@NotBlank @tools.jackson.databind.annotation.JsonDeserialize(using=vn.edu.tdtu.fitcenter.activation.StrictActivationText.class) String password){@Override public String toString(){return "PasswordRequest[redacted]";}}
    @PostMapping("/request-otp") public ResponseEntity<?> request(@Valid @RequestBody EmailRequest r){service.request(r.email());return response(202,Map.of("message","If eligible, a code is sent to the registered email","expiresInSeconds",300,"resendAfterSeconds",60));}
    @PostMapping("/verify-otp") public ResponseEntity<?> verify(@Valid @RequestBody VerifyRequest r){return response(200,Map.of("verificationToken",service.verify(r.email(),r.otp()),"expiresInSeconds",300));}
    @PostMapping("/password") public ResponseEntity<?> password(@Valid @RequestBody PasswordRequest r){service.password(r.verificationToken(),r.password());return response(200,Map.of("status","ACTIVE"));}
    private ResponseEntity<?> response(int status,Object body){return ResponseEntity.status(status).cacheControl(CacheControl.noStore()).body(body);}
}