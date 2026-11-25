package vn.edu.tdtu.fitcenter.controller;
import jakarta.validation.Valid;import org.springframework.http.*;import org.springframework.security.core.Authentication;import org.springframework.web.bind.annotation.*;import lombok.RequiredArgsConstructor;import java.util.*;import vn.edu.tdtu.fitcenter.renewal.*;import static vn.edu.tdtu.fitcenter.membershipinitial.InitialActivationRequest.uuid;
@RestController @RequestMapping("/api/v1") @RequiredArgsConstructor
public class MembershipRenewalController {
 private final RenewalService service;
 private ResponseEntity<?> response(Object value){return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(value);}
 private ResponseEntity<?> result(RenewalService.Result result){return ResponseEntity.status(result.status()).cacheControl(CacheControl.noStore()).header("Idempotency-Replayed",Boolean.toString(result.replayed())).body(result.body());}
 @PostMapping("/memberships/{id}/renewals") public ResponseEntity<?> create(Authentication actor,@PathVariable String id,@RequestHeader("Idempotency-Key")String key,@Valid @RequestBody RenewalRequests.Create request){return result(service.initiate(actor.getName(),uuid(id),uuid(key),request));}
 @GetMapping("/memberships/{id}/periods") public ResponseEntity<?> periods(Authentication actor,@PathVariable String id){return response(service.history(actor.getName(),uuid(id)));}
 @GetMapping("/payments/me") public ResponseEntity<?> mine(Authentication actor){return response(service.mine(actor.getName()));}
 @GetMapping("/payments/{id}") public ResponseEntity<?> read(Authentication actor,@PathVariable String id){return response(service.payment(actor.getName(),uuid(id)));}
 @GetMapping("/admin/payment-simulator/transactions") public ResponseEntity<?> admin(Authentication actor){return response(service.adminList(actor.getName()));}
 @GetMapping("/admin/payment-simulator/transactions/{id}/events") public ResponseEntity<?> events(Authentication actor,@PathVariable String id){return response(service.events(actor.getName(),uuid(id)));}
 @PostMapping("/admin/payment-simulator/transactions/{id}/results") public ResponseEntity<?> settle(Authentication actor,@PathVariable String id,@Valid @RequestBody RenewalRequests.Event request){return result(service.settle(actor.getName(),uuid(id),request));}
}
