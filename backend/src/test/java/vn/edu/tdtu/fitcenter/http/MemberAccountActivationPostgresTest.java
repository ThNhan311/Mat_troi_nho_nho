package vn.edu.tdtu.fitcenter.http;

import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.context.annotation.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.*;
import tools.jackson.databind.ObjectMapper;
import java.net.*;
import java.net.http.*;
import java.sql.*;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest(webEnvironment=SpringBootTest.WebEnvironment.RANDOM_PORT,properties={"server.address=127.0.0.1","spring.main.banner-mode=off","logging.level.org.springframework.security=ERROR"})
@ActiveProfiles("account-integration-rehearsal") @Import(MemberAccountActivationPostgresTest.TestTime.class)
@DirtiesContext(classMode=DirtiesContext.ClassMode.AFTER_CLASS)
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
@EnabledIfEnvironmentVariable(named="RUN_ACCOUNT_POSTGRES_TESTS",matches="true")
class MemberAccountActivationPostgresTest {
    private static final ActivationLoopbackMailSink mail=new ActivationLoopbackMailSink();
    private static final TestClock clock=new TestClock();
    @TestConfiguration static class TestTime {@Bean @Primary Clock activationTestClock(){return clock;}}
    static class TestClock extends Clock {
        final AtomicReference<Instant> now=new AtomicReference<>(Instant.parse("2030-01-01T00:00:00Z"));
        public ZoneId getZone(){return ZoneOffset.UTC;}public Clock withZone(ZoneId z){return this;}public Instant instant(){return now.get();}
        void add(long seconds){now.updateAndGet(t->t.plusSeconds(seconds));}
    }
    @DynamicPropertySource static void datasource(DynamicPropertyRegistry p){
        AccountIntegrationDatabase.prepare();
        p.add("spring.datasource.url",()->AccountIntegrationDatabase.env("ACCOUNT_HISTORY_DB_URL"));
        p.add("spring.datasource.username",()->"fitcenter_account_app");p.add("spring.datasource.password",()->AccountIntegrationDatabase.env("ACCOUNT_DB_PASSWORD"));
        p.add("fitcenter.account-integration.guard-verified",()->true);p.add("fitcenter.activation.test-smtp-port",mail::port);
        p.add("jwt.secret",HttpBaselineFixture::randomSecret);
    }
    @LocalServerPort int port;@Autowired JdbcTemplate jdbc;@Autowired ObjectMapper json;@Autowired PasswordEncoder encoder;
    private HttpClient client;private String admin;
    private final List<Map<String,Object>> accounts=new ArrayList<>();
    private final String password=HttpBaselineFixture.randomSecret();
    @BeforeAll void setup() throws Exception {client=HttpClient.newHttpClient();var a=AccountIntegrationDatabase.fixture.admin;admin=(String)body(post("/api/v1/auth/login",Map.of("email",a.email,"password",a.password),null)).get("accessToken");assertNotNull(admin);}
    @BeforeEach void before(){clock.now.set(Instant.parse("2030-01-01T00:00:00Z"));}
    @AfterEach void cleanup(){
        for(var a:accounts){UUID id=UUID.fromString((String)a.get("userId"));UUID member=UUID.fromString((String)a.get("profileId"));if("MEMBER".equals(a.get("role")))for(UUID ms:jdbc.queryForList("SELECT id FROM memberships WHERE member_id=?",UUID.class,member)){jdbc.update("DELETE FROM audit_logs WHERE entity_type='MEMBERSHIP' AND entity_id=?",ms);jdbc.update("DELETE FROM membership_initial_activations WHERE member_id=? AND membership_id=?",member,ms);jdbc.update("DELETE FROM payment_transactions WHERE member_id=? AND membership_id=?",member,ms);jdbc.update("DELETE FROM memberships WHERE id=? AND member_id=?",ms,member);}jdbc.update("DELETE FROM member_account_activation WHERE user_id=?",id);jdbc.update("DELETE FROM audit_logs WHERE entity_type='USER' AND entity_id=? AND action IN ('ACCOUNT_CREATED_PENDING_ACTIVATION','MEMBER_ACCOUNT_ACTIVATED')",id);jdbc.update("DELETE FROM personal_trainers WHERE user_id=?",id);jdbc.update("DELETE FROM members WHERE user_id=?",id);jdbc.update("DELETE FROM users WHERE id=?",id);}accounts.clear();
    }
    @AfterAll void close(){mail.close();client.close();}
    private HttpResponse<String> post(String path,Map<String,?> data,String token) throws Exception {
        var b=HttpRequest.newBuilder(URI.create("http://127.0.0.1:"+port+path)).timeout(Duration.ofSeconds(20)).header("Content-Type","application/json").header("X-Correlation-Id","account-integration-rehearsal");if(token!=null)b.header("Authorization","Bearer "+token);
        return client.send(b.POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(data))).build(),HttpResponse.BodyHandlers.ofString());
    }
    @SuppressWarnings("unchecked") private Map<String,Object> body(HttpResponse<String> r){return json.readValue(r.body(),Map.class);}
    private void status(HttpResponse<String> r,int status){assertEquals(status,r.statusCode());assertFalse(r.body().contains("password_hash"));}
    private void error(HttpResponse<String> r,int status,String code){status(r,status);assertEquals(code,((Map<?,?>)body(r).get("error")).get("code"));assertTrue(r.headers().firstValue("Cache-Control").orElse("").contains("no-store"));}
    private Map<String,Object> account(String role) throws Exception {
        var r=post("/api/v1/admin/"+(role.equals("PT")?"personal-trainers":"members"),Map.of("email","activation-http-"+UUID.randomUUID()+"@example.invalid","fullName","Synthetic activation PT"),admin);status(r,201);var a=body(r);accounts.add(a);try{java.nio.file.Files.writeString(java.nio.file.Path.of(AccountIntegrationDatabase.env("ACCOUNT_PRIVATE_DIRECTORY"),"account-test-ids-"+AccountIntegrationDatabase.nonce+".tsv"),"users\t"+a.get("userId")+"\n"+(role.equals("PT")?"personal_trainers":"members")+"\t"+a.get("profileId")+"\n",java.nio.file.StandardOpenOption.CREATE,java.nio.file.StandardOpenOption.APPEND);}catch(java.io.IOException e){throw new IllegalStateException("Cannot register synthetic account",e);}return a;
    }
    private UUID id(Map<String,Object> a){return UUID.fromString((String)a.get("userId"));}
    private String email(Map<String,Object> a){return (String)a.get("email");}
    private HttpResponse<String> request(Map<String,Object> a) throws Exception{return post("/api/v1/auth/member-activation/request-otp",Map.of("email",email(a)),null);}
    private HttpResponse<String> verify(Map<String,Object> a,String code) throws Exception{return post("/api/v1/auth/member-activation/verify-otp",Map.of("email",email(a),"otp",code),null);}
    private HttpResponse<String> complete(String grant) throws Exception{return post("/api/v1/auth/member-activation/password",Map.of("verificationToken",grant,"password",password),null);}
    private String issue(Map<String,Object> a) throws Exception {var r=request(a);status(r,202);assertTrue(r.headers().firstValue("Cache-Control").orElse("").contains("no-store"));return mail.take(email(a));}
    private String grant(Map<String,Object> a) throws Exception {var r=verify(a,issue(a));status(r,200);return (String)body(r).get("verificationToken");}
    private Map<String,Object> state(UUID id){return jdbc.queryForMap("SELECT * FROM member_account_activation WHERE user_id=?",id);}
    private void active(UUID id,String expected){assertEquals(expected,jdbc.queryForObject("SELECT status FROM users WHERE id=?",String.class,id));}
    @Test void inactiveAccountCannotReceiveNormalJwt() throws Exception {
        var a=account("MEMBER");var login=post("/api/v1/auth/login",Map.of("email",email(a),"password",password),null);status(login,401);assertFalse(body(login).containsKey("accessToken"));
    }
    @Test void fullActivationAndLoginPreserveMembershipAndPayment() throws Exception {
        var a=account("MEMBER");String code=issue(a);var s=state(id(a));assertTrue(encoder.matches(code,(String)s.get("otp_digest")));assertFalse(code.equals(s.get("otp_digest")));
        assertEquals(300,Duration.between(((Timestamp)s.get("last_sent_at")).toInstant(),((Timestamp)s.get("otp_expires_at")).toInstant()).toSeconds());active(id(a),"DISABLED");
        var v=verify(a,code);status(v,200);String g=(String)body(v).get("verificationToken");assertEquals(43,g.length());assertNull(state(id(a)).get("otp_digest"));assertFalse(g.equals(state(id(a)).get("grant_digest")));active(id(a),"DISABLED");
        var r=complete(g);status(r,200);assertEquals("ACTIVE",body(r).get("status"));assertFalse(body(r).containsKey("accessToken"));active(id(a),"ACTIVE");
        var done=state(id(a));assertNotNull(done.get("completed_at"));assertNull(done.get("grant_digest"));assertTrue(encoder.matches(password,jdbc.queryForObject("SELECT password_hash FROM users WHERE id=?",String.class,id(a))));
        var login=post("/api/v1/auth/login",Map.of("email",email(a),"password",password),null);status(login,200);assertEquals("MEMBER",body(login).get("role"));assertTrue(body(login).get("accessToken") instanceof String);
        error(complete(g),400,"ERR_ACTIVATION_INVALID");assertTrue(done.equals(state(id(a))),"Replay must not alter activation metadata");
        assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM audit_logs WHERE entity_id=? AND action='MEMBER_ACCOUNT_ACTIVATED'",Integer.class,id(a)));
        assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM payment_transactions WHERE id=? AND period_start=? AND period_end=?",Integer.class,AccountIntegrationDatabase.payment,AccountIntegrationDatabase.fixture.today,AccountIntegrationDatabase.fixture.expiry));
    }
    @ParameterizedTest @ValueSource(longs={299,300,301}) void fiveMinuteExpiryBoundaries(long seconds) throws Exception {
        var a=account("MEMBER");String code=issue(a);clock.add(seconds);var r=verify(a,code);if(seconds<300)status(r,200);else error(r,400,"ERR_OTP_EXPIRED");active(id(a),"DISABLED");
    }
    @Test void wrongAttemptsPersistAcrossHttpTransactionsAndBlockCorrectSixth() throws Exception {
        var a=account("MEMBER");String code=issue(a),wrong=code.equals("000000")?"999999":"000000";for(int i=0;i<5;i++)error(verify(a,wrong),400,"ERR_ACTIVATION_INVALID");assertEquals(5,((Number)state(id(a)).get("attempts")).intValue());error(verify(a,code),429,"ERR_OTP_ATTEMPT_LIMIT");
    }
    @Test void resendAtSixtySecondsResetsAttemptsAndInvalidatesOldGrant() throws Exception {
        var a=account("MEMBER");String g=grant(a);clock.add(59);error(request(a),429,"ERR_OTP_RESEND_TOO_SOON");clock.add(1);status(request(a),202);String next=mail.take(email(a));assertNull(state(id(a)).get("grant_digest"));error(complete(g),400,"ERR_ACTIVATION_INVALID");status(verify(a,next),200);
    }
    @Test void resendLimitAndHourEquality() throws Exception {
        var a=account("MEMBER");for(int i=0;i<5;i++){issue(a);clock.add(60);}error(request(a),429,"ERR_OTP_SEND_LIMIT");clock.now.set(Instant.parse("2030-01-01T01:00:00Z"));issue(a);assertEquals(1,((Number)state(id(a)).get("send_count")).intValue());
    }
    @Test void verifyIsOneUseAndExpiredGrantCannotSetPassword() throws Exception {
        var a=account("MEMBER");String code=issue(a);var v=verify(a,code);status(v,200);String g=(String)body(v).get("verificationToken");error(verify(a,code),409,"ERR_OTP_ALREADY_USED");clock.add(300);error(complete(g),400,"ERR_ACTIVATION_INVALID");active(id(a),"DISABLED");
    }
    @Test void memberUnknownLegacyAndSuspendedCannotActivate() throws Exception {
        var member=account("PT");status(request(member),202);assertTrue(mail.empty(email(member)));error(verify(member,"000000"),400,"ERR_ACTIVATION_INVALID");
        var unknown=Map.<String,Object>of("email","unknown-"+UUID.randomUUID()+"@example.invalid");status(request(unknown),202);assertTrue(mail.empty(email(unknown)));
        var a=account("MEMBER");jdbc.update("DELETE FROM audit_logs WHERE entity_id=? AND action='ACCOUNT_CREATED_PENDING_ACTIVATION'",id(a));status(request(a),202);assertTrue(mail.empty(email(a)));
        var b=account("MEMBER");String code=issue(b);jdbc.update("UPDATE users SET status='SUSPENDED' WHERE id=?",id(b));error(verify(b,code),400,"ERR_ACTIVATION_INVALID");active(id(b),"SUSPENDED");
    }
    @Test void strictJsonAndPasswordBytesDoNotMutate() throws Exception {
        var a=account("MEMBER");var bad=post("/api/v1/auth/member-activation/verify-otp",Map.of("email",email(a),"otp",123456),null);status(bad,400);
        String g=grant(a);for(String pw:List.of("short","é".repeat(37))){error(post("/api/v1/auth/member-activation/password",Map.of("verificationToken",g,"password",pw),null),400,"ERR_VALIDATION");active(id(a),"DISABLED");}status(complete(g),200);
    }
    @Test void smtpFailureRollsBackChallengeThenRetryCanIssue() throws Exception {
        var a=account("MEMBER");mail.failNext.set(true);error(request(a),503,"ERR_TEST_MAIL_UNAVAILABLE");assertEquals(0,jdbc.queryForObject("SELECT count(*) FROM member_account_activation WHERE user_id=?",Integer.class,id(a)));issue(a);assertEquals(1,((Number)state(id(a)).get("send_count")).intValue());
    }
    private String installFailure(UUID id,String condition){
        String name="activation_test_fail_"+id.toString().replace("-","");jdbc.execute("CREATE FUNCTION "+name+"() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.user_id='"+id+"'::uuid AND "+condition+" THEN RAISE EXCEPTION 'controlled rehearsal rollback' USING ERRCODE='40001'; END IF; RETURN NEW; END $$");jdbc.execute("CREATE TRIGGER "+name+" BEFORE UPDATE ON member_account_activation FOR EACH ROW EXECUTE FUNCTION "+name+"()");return name;
    }
    private void removeFailure(String name){jdbc.execute("DROP TRIGGER "+name+" ON member_account_activation");jdbc.execute("DROP FUNCTION "+name+"()");}
    @Test void passwordDatabaseFailureRollsBackUserGrantAndAudit() throws Exception {
        var a=account("MEMBER");String g=grant(a);var before=state(id(a));String name=installFailure(id(a),"NEW.completed_at IS NOT NULL");try{error(complete(g),409,"ERR_CONFLICT");}finally{removeFailure(name);}active(id(a),"DISABLED");assertTrue(before.equals(state(id(a))));assertEquals(0,jdbc.queryForObject("SELECT count(*) FROM audit_logs WHERE entity_id=? AND action='MEMBER_ACCOUNT_ACTIVATED'",Integer.class,id(a)));status(complete(g),200);
    }
    @Test void verificationDatabaseFailureDoesNotConsumeOtp() throws Exception {
        var a=account("MEMBER");String code=issue(a),name=installFailure(id(a),"NEW.grant_digest IS NOT NULL");try{error(verify(a,code),409,"ERR_CONFLICT");}finally{removeFailure(name);}assertNotNull(state(id(a)).get("otp_digest"));assertNull(state(id(a)).get("grant_digest"));status(verify(a,code),200);
    }
    private List<HttpResponse<String>> race(UUID user,List<Callable<HttpResponse<String>>> calls,Runnable beforeUnlock) throws Exception {
        try(var connection=AccountIntegrationDatabase.history.getConnection();var pool=Executors.newFixedThreadPool(calls.size())){
            connection.setAutoCommit(false);try(var lock=connection.prepareStatement("SELECT id FROM users WHERE id=? FOR UPDATE")){lock.setObject(1,user);lock.executeQuery().close();}
            var ready=new CountDownLatch(calls.size());var start=new CountDownLatch(1);var futures=new ArrayList<Future<HttpResponse<String>>>();for(var c:calls)futures.add(pool.submit(()->{ready.countDown();start.await();return c.call();}));assertTrue(ready.await(3,TimeUnit.SECONDS));start.countDown();
            try{long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(6);boolean waiting=false;while(System.nanoTime()<deadline){int count=jdbc.queryForObject("SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND pid<>pg_backend_pid() AND wait_event_type='Lock'",Integer.class);if(count>=calls.size()){waiting=true;break;}Thread.sleep(10);}assertTrue(waiting,"All contenders must really wait on the held PostgreSQL row lock");beforeUnlock.run();}finally{connection.commit();}
            var results=new ArrayList<HttpResponse<String>>();for(var f:futures)results.add(f.get(15,TimeUnit.SECONDS));return results;
        }
    }
    private List<Integer> statuses(List<HttpResponse<String>> responses){return responses.stream().map(HttpResponse::statusCode).sorted().toList();}
    @Test void concurrentOtpVerifyConsumesExactlyOnce() throws Exception {
        var a=account("MEMBER");String code=issue(a);var rs=race(id(a),List.of(()->verify(a,code),()->verify(a,code)),()->{});assertEquals(List.of(200,409),statuses(rs));assertNull(state(id(a)).get("otp_digest"));assertNotNull(state(id(a)).get("grant_digest"));
    }
    @Test void concurrentPasswordActivatesExactlyOnce() throws Exception {
        var a=account("MEMBER");String g=grant(a);assertEquals(List.of(200,400),statuses(race(id(a),List.of(()->complete(g),()->complete(g)),()->{})));active(id(a),"ACTIVE");assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM audit_logs WHERE entity_id=? AND action='MEMBER_ACCOUNT_ACTIVATED'",Integer.class,id(a)));
    }
    @Test void concurrentFirstSendHasOneChallengeAndOneMail() throws Exception {
        var a=account("MEMBER");assertEquals(List.of(202,429),statuses(race(id(a),List.of(()->request(a),()->request(a)),()->{})));mail.take(email(a));assertTrue(mail.empty(email(a)));assertEquals(1,((Number)state(id(a)).get("send_count")).intValue());
    }
    @Test void concurrentWrongAttemptsCannotLoseCounterUpdates() throws Exception {
        var a=account("MEMBER");String code=issue(a),wrong=code.equals("000000")?"999999":"000000";var calls=new ArrayList<Callable<HttpResponse<String>>>();for(int i=0;i<5;i++)calls.add(()->verify(a,wrong));assertEquals(List.of(400,400,400,400,400),statuses(race(id(a),calls,()->{})));assertEquals(5,((Number)state(id(a)).get("attempts")).intValue());error(verify(a,code),429,"ERR_OTP_ATTEMPT_LIMIT");
    }
    @Test void requestBeforeExpiryAcquiringLockAfterExpiryIsRejected() throws Exception {
        var a=account("MEMBER");String code=issue(a);clock.add(299);var rs=race(id(a),List.of(()->verify(a,code)),()->clock.add(1));error(rs.getFirst(),400,"ERR_OTP_EXPIRED");assertNotNull(state(id(a)).get("otp_digest"));
    }
    @Test void passwordAndResendRaceCannotActivateUsingRevokedGrant() throws Exception {
        var a=account("MEMBER");String g=grant(a);clock.add(60);var rs=race(id(a),List.of(()->complete(g),()->request(a)),()->{});assertTrue(statuses(rs).equals(List.of(200,202))||statuses(rs).equals(List.of(202,400)));
        String status=jdbc.queryForObject("SELECT status FROM users WHERE id=?",String.class,id(a));if(status.equals("ACTIVE")){assertNotNull(state(id(a)).get("completed_at"));assertNull(state(id(a)).get("grant_digest"));}else{assertEquals("DISABLED",status);assertNull(state(id(a)).get("grant_digest"));assertNotNull(state(id(a)).get("otp_digest"));}error(complete(g),400,"ERR_ACTIVATION_INVALID");
    }

    @Test void activationWithoutMembershipPreservesAllExistingBusinessRows() throws Exception {
        var before=business();var a=account("MEMBER");String g=grant(a);status(complete(g),200);assertEquals(before,business());
        if("MEMBER".equals("MEMBER"))assertEquals(0,jdbc.queryForObject("SELECT count(*) FROM memberships WHERE member_id=?",Integer.class,UUID.fromString((String)a.get("profileId"))));
    }
    private Map<String,List<String>> business(){var out=new TreeMap<String,List<String>>();for(String table:List.of("memberships","membership_plans","payment_transactions","membership_initial_activations","bookings","availability_slots"))out.put(table,jdbc.queryForList("SELECT to_jsonb(x)::text FROM "+table+" x ORDER BY id",String.class));return out;}
    @Test void otherRoleGrantAndChallengeCannotCrossEndpoints() throws Exception {
        var a=account("MEMBER");String code=issue(a),other="pt-activation";String path="/api/v1/auth/"+other;
        error(post(path+"/verify-otp",Map.of("email",email(a),"otp",code),null),400,"ERR_ACTIVATION_INVALID");
        var v=verify(a,code);status(v,200);String g=(String)body(v).get("verificationToken");
        error(post(path+"/password",Map.of("verificationToken",g,"password",password),null),400,"ERR_ACTIVATION_INVALID");active(id(a),"DISABLED");status(complete(g),200);
    }
    @Test void completionMarkerBlocksReactivationEvenIfDisabledAgain() throws Exception {
        var a=account("MEMBER");status(complete(grant(a)),200);var prior=state(id(a));jdbc.update("UPDATE users SET status='DISABLED' WHERE id=?",id(a));status(request(a),202);assertTrue(mail.empty(email(a)));assertTrue(prior.equals(state(id(a))));
        var list=client.send(HttpRequest.newBuilder(URI.create("http://127.0.0.1:"+port+"/api/v1/admin/"+("MEMBER".equals("PT")?"personal-trainers":"members"))).header("Authorization","Bearer "+admin).GET().build(),HttpResponse.BodyHandlers.ofString());
        var rows=json.readValue(list.body(),List.class);var row=(Map<?,?>)rows.stream().filter(x->((Map<?,?>)x).get("userId").equals(a.get("userId"))).findFirst().orElseThrow();assertEquals(false,row.get("activationPending"));
    }

    @Test void membershipGrantAndAccountPasswordCanCommitConcurrently() throws Exception {
        var a=account("MEMBER");String g=grant(a);UUID member=UUID.fromString((String)a.get("profileId"));
        var before=business();var payload=Map.of("planId",AccountIntegrationDatabase.fixture.planId,"amountCollected",jdbc.queryForObject("SELECT price FROM membership_plans WHERE id=?",java.math.BigDecimal.class,AccountIntegrationDatabase.fixture.planId),"receiptRef","RACE-MEMBER-"+member);
        try(var connection=AccountIntegrationDatabase.history.getConnection();var pool=Executors.newFixedThreadPool(2)){
            connection.setAutoCommit(false);try(var q=connection.prepareStatement("SELECT id FROM members WHERE id=? FOR NO KEY UPDATE")){q.setObject(1,member);q.executeQuery().close();}try(var q=connection.prepareStatement("SELECT id FROM users WHERE id=? FOR UPDATE")){q.setObject(1,id(a));q.executeQuery().close();}
            var barrier=new CyclicBarrier(2);var passwordCall=pool.submit(()->{barrier.await();return complete(g);});var membershipCall=pool.submit(()->{barrier.await();return client.send(HttpRequest.newBuilder(URI.create("http://127.0.0.1:"+port+"/api/v1/admin/members/"+member+"/activate-membership")).header("Content-Type","application/json").header("Authorization","Bearer "+admin).header("Idempotency-Key",UUID.randomUUID().toString()).POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(payload))).build(),HttpResponse.BodyHandlers.ofString());});
            boolean waiting=false;long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(6);while(System.nanoTime()<deadline){if(jdbc.queryForObject("SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND wait_event_type='Lock'",Integer.class)>=2){waiting=true;break;}Thread.sleep(10);}assertTrue(waiting);connection.commit();status(passwordCall.get(15,TimeUnit.SECONDS),200);status(membershipCall.get(15,TimeUnit.SECONDS),201);
        }
        active(id(a),"ACTIVE");assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM memberships WHERE member_id=?",Integer.class,member));assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM payment_transactions WHERE member_id=? AND status='SUCCESS'",Integer.class,member));
        assertEquals(before.get("bookings"),business().get("bookings"));assertEquals(before.get("membership_plans"),business().get("membership_plans"));
    }
}
