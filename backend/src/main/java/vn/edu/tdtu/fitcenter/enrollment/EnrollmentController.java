package vn.edu.tdtu.fitcenter.enrollment;
import java.util.*;import jakarta.validation.Valid;import org.springframework.http.*;import org.springframework.security.core.Authentication;import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/admin/members/{member}/face-enrollments")
public class EnrollmentController {
 private final EnrollmentService service;public EnrollmentController(EnrollmentService service){this.service=service;}
 private ResponseEntity<?> ok(Object value){return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(value);}
 @GetMapping public ResponseEntity<?> list(Authentication a,@PathVariable UUID member){return ok(service.list(a.getName(),member));}
 @PostMapping public ResponseEntity<?> start(Authentication a,@PathVariable UUID member,@RequestHeader("Idempotency-Key")UUID key,@Valid @RequestBody EnrollmentRequest body){return ResponseEntity.status(201).cacheControl(CacheControl.noStore()).body(service.start(a.getName(),member,key,body));}
 @GetMapping("/{operation}") public ResponseEntity<?> read(Authentication a,@PathVariable UUID member,@PathVariable UUID operation){return ok(service.read(a.getName(),member,operation));}
 @PostMapping("/{operation}/complete") public ResponseEntity<?> complete(Authentication a,@PathVariable UUID member,@PathVariable UUID operation,@RequestBody(required=false)Map<String,Object> body){empty(body);return ok(service.complete(a.getName(),member,operation));}
 @PostMapping("/{operation}/revoke") public ResponseEntity<?> revokePending(Authentication a,@PathVariable UUID member,@PathVariable UUID operation,@RequestBody(required=false)Map<String,Object> body){empty(body);return ok(service.revokePending(a.getName(),member,operation));}
 @PostMapping("/profiles/{profile}/revoke") public ResponseEntity<?> revoke(Authentication a,@PathVariable UUID member,@PathVariable UUID profile,@RequestHeader("Idempotency-Key")UUID key,@RequestBody(required=false)Map<String,Object> body){empty(body);return ok(service.revoke(a.getName(),member,profile,key));}
 private void empty(Map<String,Object> b){if(b!=null&&!b.isEmpty())throw new vn.edu.tdtu.fitcenter.checkin.CheckinFailure(400,"ERR_VALIDATION","No client attestation fields accepted");}
}
