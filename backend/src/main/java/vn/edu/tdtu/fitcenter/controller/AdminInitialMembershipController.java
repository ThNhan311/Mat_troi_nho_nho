package vn.edu.tdtu.fitcenter.controller;
import jakarta.validation.Valid;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vn.edu.tdtu.fitcenter.membershipinitial.*;
import vn.edu.tdtu.fitcenter.web.CorrelationIdFilter;
@RestController @RequestMapping("/api/v1/admin/members/{memberId}") @RequiredArgsConstructor
public class AdminInitialMembershipController {
 private final InitialMembershipService service;
 @PostMapping("/activate-membership") public ResponseEntity<String> create(Authentication actor,@PathVariable String memberId,@RequestHeader("Idempotency-Key") String key,@Valid @RequestBody InitialActivationRequest request,HttpServletRequest http){return response(service.create(actor.getName(),InitialActivationRequest.uuid(memberId),InitialActivationRequest.uuid(key),request,CorrelationIdFilter.getOrCreate(http)));}
 @GetMapping("/membership-activation") public ResponseEntity<String> read(Authentication actor,@PathVariable String memberId){return response(service.read(actor.getName(),InitialActivationRequest.uuid(memberId)));}
 private ResponseEntity<String> response(InitialMembershipService.Result result){return ResponseEntity.status(result.status()).contentType(MediaType.APPLICATION_JSON).cacheControl(CacheControl.noStore()).header("Idempotency-Replayed",Boolean.toString(result.replayed())).body(result.json());}
}
