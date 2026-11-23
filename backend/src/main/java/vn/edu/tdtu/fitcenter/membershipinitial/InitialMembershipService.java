package vn.edu.tdtu.fitcenter.membershipinitial;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.ObjectMapper;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.*;
import java.util.*;
import static vn.edu.tdtu.fitcenter.membershipinitial.InitialActivationFailure.conflict;
@Service
public class InitialMembershipService {
 private final JdbcTemplate jdbc;private final ObjectMapper json;private final Clock clock;private final boolean enabled;private final TransactionTemplate tx;
 public record Result(int status,String json,boolean replayed){}
 public InitialMembershipService(JdbcTemplate jdbc,ObjectMapper json,Clock clock,PlatformTransactionManager manager,@Value("${fitcenter.membership-initial.enabled:false}") boolean enabled){this.jdbc=jdbc;this.json=json;this.clock=clock;this.enabled=enabled;tx=new TransactionTemplate(manager);tx.setIsolationLevel(TransactionDefinition.ISOLATION_READ_COMMITTED);tx.setTimeout(10);}
 private void gate(){if(!enabled)throw new InitialActivationFailure(503,"ERR_MEMBERSHIP_ACTIVATION_UNAVAILABLE","Initial activation is not enabled in this environment");}
 private UUID actor(String email){var rows=jdbc.queryForList("SELECT id FROM users WHERE lower(email)=lower(?) AND role='ADMIN' AND status='ACTIVE'",email);if(rows.size()!=1)throw new AccessDeniedException("ACTIVE ADMIN required");return (UUID)rows.getFirst().get("id");}
 public Result read(String email,UUID member){gate();return tx.execute(s->{actor(email);var rows=jdbc.queryForList("SELECT response_snapshot::text snapshot FROM membership_initial_activations WHERE member_id=?",member);if(rows.isEmpty())throw new InitialActivationFailure(404,"ERR_NOT_FOUND","No committed initial activation record");return new Result(200,(String)rows.getFirst().get("snapshot"),false);});}
 String fingerprint(UUID member,InitialActivationRequest r){try{var body=new LinkedHashMap<String,Object>();body.put("command","M03-v1");body.put("memberId",member.toString());body.put("planId",r.planId().toString());body.put("amount",r.amountCollected().setScale(2).toPlainString());body.put("receiptKey",r.receiptKey());body.put("note",r.note());return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(json.writeValueAsString(body).getBytes(StandardCharsets.UTF_8)));}catch(java.security.NoSuchAlgorithmException e){throw new IllegalStateException(e);}}
 private Result replay(UUID key,String hash){var rows=jdbc.queryForList("SELECT request_fingerprint,response_snapshot::text snapshot FROM membership_initial_activations WHERE idempotency_key=?",key);if(rows.isEmpty())return null;var row=rows.getFirst();if(!hash.equals(row.get("request_fingerprint")))throw conflict("ERR_IDEMPOTENCY_KEY_REUSED","Key already belongs to a different request");return new Result(200,(String)row.get("snapshot"),true);}
 public Result create(String email,UUID member,UUID key,InitialActivationRequest r,String correlation){gate();String hash=fingerprint(member,r);
  try{return tx.execute(s->createLocked(email,member,key,r,hash,correlation));}
  catch(DataIntegrityViolationException ex){
   // The failed transaction has rolled back before resolving committed unique-index winners.
   return tx.execute(s->{actor(email);Result old=replay(key,hash);if(old!=null)return old;
    if(Boolean.TRUE.equals(jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM membership_initial_activations WHERE receipt_key=?)",Boolean.class,r.receiptKey())))throw conflict("ERR_RECEIPT_ALREADY_USED","Receipt already recorded");
    if(Boolean.TRUE.equals(jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM memberships WHERE member_id=?)",Boolean.class,member)))throw conflict("ERR_MEMBERSHIP_ALREADY_EXISTS","Member already has membership history");
    throw conflict("ERR_CONFLICT","Concurrent data conflict; reconcile before retry");});
  }
 }
 private Result createLocked(String email,UUID member,UUID key,InitialActivationRequest r,String hash,String correlation){
  actor(email);
  var members=jdbc.queryForList("SELECT id,user_id FROM members WHERE id=? FOR NO KEY UPDATE",member);if(members.isEmpty())throw new InitialActivationFailure(404,"ERR_NOT_FOUND","Member profile not found");
  Result old=replay(key,hash);if(old!=null){actor(email);return old;}
  // All historical states count; initial activation never becomes renewal/reactivation.
  if(!jdbc.queryForList("SELECT id FROM memberships WHERE member_id=? ORDER BY id FOR UPDATE",member).isEmpty())throw conflict("ERR_MEMBERSHIP_ALREADY_EXISTS","Member already has membership history");
  var plans=jdbc.queryForList("SELECT id,name,duration_days,price,status FROM membership_plans WHERE id=? FOR SHARE",r.planId());if(plans.isEmpty())throw new InitialActivationFailure(404,"ERR_NOT_FOUND","Plan not found");var plan=plans.getFirst();
  actor(email); // Fresh scalar check after Member/plan waits. Member account status is intentionally not changed or required ACTIVE.
  if(!"ACTIVE".equals(plan.get("status")))throw conflict("ERR_PLAN_NO_LONGER_AVAILABLE","Plan no longer ACTIVE");
  BigDecimal price=(BigDecimal)plan.get("price");if(price.compareTo(r.amountCollected())!=0)throw conflict("ERR_AMOUNT_MISMATCH","Plan price changed; reload and confirm the actual receipt");
  Instant now=clock.instant();LocalDate start=LocalDate.ofInstant(now,ZoneId.of("Asia/Ho_Chi_Minh")),end;
  int days=((Number)plan.get("duration_days")).intValue();try{end=start.plusDays((long)days-1);if(end.getYear()>5874897)throw new DateTimeException("PostgreSQL DATE range");}catch(DateTimeException|ArithmeticException e){throw new InitialActivationFailure(400,"ERR_VALIDATION","Plan duration cannot be represented as a stored date");}
  UUID membership=UUID.randomUUID(),payment=UUID.randomUUID(),activation=UUID.randomUUID(),admin=actor(email);String providerRef="counter:"+payment;
  jdbc.update("INSERT INTO memberships(id,member_id,plan_id,start_date,expiry_date,status) VALUES(?,?,?,?,?,'ACTIVE')",membership,member,r.planId(),start,end);
  jdbc.update("INSERT INTO payment_transactions(id,member_id,plan_id,membership_id,provider,provider_ref,amount,status,processed_at,period_start,period_end) VALUES(?,?,?,?,'COUNTER',?,?,'SUCCESS',?,?,?)",payment,member,r.planId(),membership,providerRef,price,OffsetDateTime.ofInstant(now,ZoneOffset.UTC),start,end);
  var receipt=new LinkedHashMap<String,Object>();receipt.put("receiptRef",r.receiptRef());receipt.put("note",r.note());receipt.put("confirmedByUserId",admin);receipt.put("confirmedAt",now.toString());
  var result=Map.of("activationId",activation,"requestId",key,"memberId",member,"membership",Map.of("id",membership,"planId",r.planId(),"planName",plan.get("name"),"startDate",start.toString(),"endDate",end.toString(),"status","ACTIVE"),"payment",Map.of("id",payment,"provider","COUNTER","providerRef",providerRef,"amount",price,"status","SUCCESS","processedAt",now.toString()),"receipt",receipt,"planSnapshot",Map.of("name",plan.get("name"),"durationDays",days,"listedPrice",price,"currency","VND"));
  String snapshot=json.writeValueAsString(result);
  jdbc.update("INSERT INTO membership_initial_activations(id,member_id,membership_id,payment_transaction_id,idempotency_key,request_fingerprint,receipt_ref,receipt_key,confirmed_by_user_id,confirmed_at,listed_price_snapshot,duration_days_snapshot,currency,note,response_snapshot) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,'VND',?,?::jsonb)",activation,member,membership,payment,key,hash,r.receiptRef(),r.receiptKey(),admin,OffsetDateTime.ofInstant(now,ZoneOffset.UTC),price,days,r.note(),snapshot);
  jdbc.update("INSERT INTO audit_logs(actor_user_id,actor_type,action,entity_type,entity_id,details,correlation_id,created_at) VALUES(?,'USER','MEMBERSHIP_INITIAL_ACTIVATED','MEMBERSHIP',?,jsonb_build_object('activationId',?::text,'paymentId',?::text),?,?)",admin,membership,activation.toString(),payment.toString(),correlation,OffsetDateTime.ofInstant(now,ZoneOffset.UTC));
  return new Result(201,jdbc.queryForObject("SELECT response_snapshot::text FROM membership_initial_activations WHERE id=?",String.class,activation),false);
 }
}
