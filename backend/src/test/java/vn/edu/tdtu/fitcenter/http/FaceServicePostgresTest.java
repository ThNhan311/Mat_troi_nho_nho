package vn.edu.tdtu.fitcenter.http;

import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.*;
import tools.jackson.databind.ObjectMapper;
import java.net.*;import java.net.http.*;import java.nio.file.*;import java.time.*;import java.util.*;import java.util.concurrent.*;
import java.awt.image.BufferedImage;import javax.imageio.ImageIO;import java.io.ByteArrayOutputStream;
import static org.junit.jupiter.api.Assertions.*;

/** Real Backend TCP + PostgreSQL + Python service TCP. Images/identity are SYNTHETIC_PROTOCOL. */
@SpringBootTest(webEnvironment=SpringBootTest.WebEnvironment.RANDOM_PORT,properties={"server.address=127.0.0.1","spring.main.banner-mode=off","logging.level.org.springframework.security=ERROR"})
@ActiveProfiles("face-enrollment-rehearsal")
@DirtiesContext(classMode=DirtiesContext.ClassMode.AFTER_CLASS)
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
@EnabledIfEnvironmentVariable(named="RUN_FACE_SERVICE_POSTGRES_TESTS",matches="true")
class FaceServicePostgresTest {
    static final ObjectMapper JSON=new ObjectMapper();
    static Path config,privateDir;static Process process;static int servicePort;
    static final String control=HttpBaselineFixture.randomSecret(),captureToken=HttpBaselineFixture.randomSecret(),signingKey=HttpBaselineFixture.randomSecret();
    static synchronized void startService() {
        if(process!=null)return;
        try {
            privateDir=Path.of(FaceServiceIntegrationDatabase.env("ACCOUNT_PRIVATE_DIRECTORY"));
            try(var socket=new java.net.ServerSocket(0,0,java.net.InetAddress.getLoopbackAddress())){servicePort=socket.getLocalPort();}
            config=privateDir.resolve("face-service-"+FaceServiceIntegrationDatabase.nonce+".json");
            var value=new LinkedHashMap<String,Object>();value.put("guard","F03A_SYNTHETIC_PROTOCOL_ONLY");value.put("port",servicePort);
            value.put("controlToken",control);value.put("captureToken",captureToken);value.put("signingKey",signingKey);
            value.put("galleryKey",Base64.getUrlEncoder().encodeToString(java.security.SecureRandom.getSeed(32)));
            value.put("url","http://127.0.0.1:"+servicePort);
            Files.writeString(config,JSON.writeValueAsString(value),StandardOpenOption.CREATE_NEW);
            String python=FaceServiceIntegrationDatabase.env("FACE_SERVICE_PYTHON");Path repo=Path.of("").toAbsolutePath().getParent();
            var builder=new ProcessBuilder(python,"-m","face.service_v2.tests.protocol_host","--config",config.toString()).directory(repo.toFile());
            builder.environment().put("PYTHONDONTWRITEBYTECODE","1");builder.environment().put("PYTHONUTF8","1");
            builder.redirectErrorStream(true).redirectOutput(privateDir.resolve("face-service-"+FaceServiceIntegrationDatabase.nonce+"-private.log").toFile());
            process=builder.start();
            java.lang.Runtime.getRuntime().addShutdownHook(new Thread(()->{if(process!=null&&process.isAlive())process.destroyForcibly();}));
            Files.writeString(privateDir.resolve("face-service-process-"+FaceServiceIntegrationDatabase.nonce+".json"),JSON.writeValueAsString(Map.of("pid",process.pid(),"startInstant",process.info().startInstant().orElseThrow().toString(),"config",config.toString())),StandardOpenOption.CREATE_NEW);
            try(var http=HttpClient.newHttpClient()) {
                long until=System.nanoTime()+TimeUnit.SECONDS.toNanos(12);boolean ready=false;
                while(System.nanoTime()<until){try{var r=http.send(HttpRequest.newBuilder(URI.create("http://127.0.0.1:"+servicePort+"/v2/health")).header("X-Face-Token",control).timeout(Duration.ofSeconds(1)).build(),HttpResponse.BodyHandlers.ofString());if(r.statusCode()==200){ready=true;break;}}catch(Exception ignored){}if(!process.isAlive())break;Thread.sleep(30);}
                if(!ready)throw new IllegalStateException("Private Python service did not start");
            }
        }catch(Exception ex){if(process!=null)process.destroyForcibly();throw new IllegalStateException("Private service startup failed",ex);}
    }
    @DynamicPropertySource static void db(DynamicPropertyRegistry p) {
        FaceServiceIntegrationDatabase.prepare();startService();
        p.add("spring.datasource.url",()->FaceServiceIntegrationDatabase.env("FACE_SERVICE_HISTORY_DB_URL"));
        p.add("spring.datasource.username",()->"fitcenter_account_app");p.add("spring.datasource.password",()->FaceServiceIntegrationDatabase.env("ACCOUNT_DB_PASSWORD"));
        for(String key:List.of("account-integration","renewal","checkin","enrollment","face-service"))p.add("fitcenter."+key+".guard-verified",()->true);
        p.add("fitcenter.checkin.test-config",()->FaceServiceIntegrationDatabase.config.toString());
        p.add("fitcenter.face-service.enabled",()->true);p.add("fitcenter.face-service.private-config",()->config.toString());
        p.add("jwt.secret",HttpBaselineFixture::randomSecret);
    }
    @Autowired JdbcTemplate jdbc;@Autowired ObjectMapper json;@Autowired PasswordEncoder encoder;@LocalServerPort int port;
    HttpClient http;String admin;int index;String password=HttpBaselineFixture.randomSecret();
    @BeforeAll void setup()throws Exception{http=HttpClient.newHttpClient();var a=FaceServiceIntegrationDatabase.fixture.admin;admin=login(a.email,a.password);}
    @BeforeEach void reset()throws Exception{fault(Map.of());Files.deleteIfExists(config.resolveSibling(config.getFileName().toString().replace(".json",".entered")));Files.deleteIfExists(config.resolveSibling(config.getFileName().toString().replace(".json",".release")));}
    @AfterAll void close()throws Exception{try{fault(Map.of());for(int i=0;i<index;i++)for(String reference:jdbc.queryForList("SELECT template_ref FROM face_enrollments WHERE member_id=?",String.class,FaceServiceIntegrationDatabase.slots.get(i).member()))status(service("POST","/v2/references/abort",Map.of("reference",reference),control),200);}finally{if(http!=null)http.close();process.destroy();if(!process.waitFor(5,TimeUnit.SECONDS)){process.destroyForcibly();assertTrue(process.waitFor(5,TimeUnit.SECONDS));}assertFalse(process.isAlive());}}
    Path signal(String suffix){return config.resolveSibling(config.getFileName().toString().replace(".json",suffix));}
    void fault(Map<String,Object> value)throws Exception{Files.writeString(signal(".fault.json"),json.writeValueAsString(value));}
    record Actor(UUID user,UUID member,String token){}
    Actor actor()throws Exception{
        var a=FaceServiceIntegrationDatabase.slots.get(index++);
        Files.writeString(privateDir.resolve("enrollment-test-ids-"+FaceServiceIntegrationDatabase.nonce+".tsv"),"users\t"+a.user()+"\nmembers\t"+a.member()+"\n",StandardOpenOption.CREATE,StandardOpenOption.APPEND);
        String email="f03-"+a.user()+"@example.invalid";jdbc.update("INSERT INTO users(id,email,password_hash,role,status) VALUES(?,?,?,'MEMBER','ACTIVE')",a.user(),email,encoder.encode(password));
        jdbc.update("INSERT INTO members(id,user_id,full_name) VALUES(?,?,'Synthetic F03 Member')",a.member(),a.user());return new Actor(a.user(),a.member(),login(email,password));
    }
    HttpResponse<String> call(String method,String path,Object data,String token,UUID key)throws Exception {
        var b=HttpRequest.newBuilder(URI.create("http://127.0.0.1:"+port+"/api/v1"+path)).timeout(Duration.ofSeconds(20)).header("Content-Type","application/json");
        if(token!=null)b.header("Authorization","Bearer "+token);if(key!=null)b.header("Idempotency-Key",key.toString());
        return http.send(b.method(method,data==null?HttpRequest.BodyPublishers.noBody():HttpRequest.BodyPublishers.ofString(json.writeValueAsString(data))).build(),HttpResponse.BodyHandlers.ofString());
    }
    HttpResponse<String> service(String method,String path,Object data,String token)throws Exception {
        var b=HttpRequest.newBuilder(URI.create("http://127.0.0.1:"+servicePort+path)).header("X-Face-Token",token).header("Content-Type","application/json").timeout(Duration.ofSeconds(12));
        return http.send(b.method(method,data==null?HttpRequest.BodyPublishers.noBody():HttpRequest.BodyPublishers.ofString(json.writeValueAsString(data))).build(),HttpResponse.BodyHandlers.ofString());
    }
    Map<String,Object> body(HttpResponse<String> r){assertFalse(r.body().contains("org.postgresql"));assertFalse(r.body().contains(control));return json.readValue(r.body(),Map.class);}
    void status(HttpResponse<String> r,int code){assertEquals(code,r.statusCode(),"Unexpected HTTP status");body(r);}
    void error(HttpResponse<String> r,int code,String error){status(r,code);assertEquals(error,((Map<?,?>)body(r).get("error")).get("code"));}
    String login(String e,String p)throws Exception{var r=call("POST","/auth/login",Map.of("email",e,"password",p),null,null);status(r,200);return (String)body(r).get("accessToken");}
    String path(Actor a){return "/admin/members/"+a.member()+"/face-enrollments";}
    Map<String,Object> start(Actor a)throws Exception{var r=call("POST",path(a),Map.of("consentAccepted",true,"memberVerified",true,"atGym",true,"consentVersion","synthetic-f03-v1"),admin,UUID.randomUUID());status(r,201);return body(r);}
    String opPath(Map<String,Object> op){return "/v2/operations/"+op.get("id");}
    HttpResponse<String> complete(Actor a,Map<String,Object> op)throws Exception{return call("POST",path(a)+"/"+op.get("id")+"/complete",Map.of(),admin,null);}
    Map<String,Object> state(Map<String,Object> op)throws Exception{var r=service("GET",opPath(op),null,control);status(r,200);return body(r);}
    String image(int value)throws Exception{var image=new BufferedImage(8,8,BufferedImage.TYPE_3BYTE_BGR);for(int x=0;x<8;x++)for(int y=0;y<8;y++)image.setRGB(x,y,(value<<16)|(value<<8)|value);var out=new ByteArrayOutputStream();ImageIO.write(image,"png",out);return Base64.getEncoder().encodeToString(out.toByteArray());}
    void stage(Actor a,Map<String,Object> op,int value,String predecessor)throws Exception{
        var d=new LinkedHashMap<String,Object>();d.put("operation",op.get("id"));d.put("member",a.member());d.put("profile",op.get("proposedProfileId"));d.put("reference","f02:"+op.get("proposedProfileId"));d.put("predecessor",predecessor);
        status(service("POST","/v2/operations",d,control),200);status(service("POST",opPath(op)+"/samples",Map.of("frames",Collections.nCopies(5,image(value))),control),200);
    }
    Map<String,Object> scan(int value,UUID request,UUID capture)throws Exception{var r=service("POST","/v2/captures",Map.of("request",request,"capture",capture,"frames",List.of(image(value))),captureToken);status(r,200);return body(r);}
    Map<String,Object> proof(Map<String,Object> envelope){return json.readValue(new String(Base64.getUrlDecoder().decode((String)envelope.get("payload")),java.nio.charset.StandardCharsets.UTF_8),Map.class);}
    String dbStatus(Map<String,Object> op){return jdbc.queryForObject("SELECT status FROM face_enrollments WHERE id=?",String.class,UUID.fromString((String)op.get("id")));}
    Map<String,List<String>> business(){var out=new TreeMap<String,List<String>>();for(String t:List.of("users","members","personal_trainers","membership_plans","memberships","payment_transactions","membership_paid_periods","membership_initial_activations","pt_account_activation","member_account_activation","bookings","availability_slots","renewal_payment_quotes","renewal_payment_events","renewal_result_keys"))out.put(t,jdbc.queryForList("SELECT to_jsonb(t)::text FROM "+t+" t ORDER BY to_jsonb(t)::text",String.class));return out;}

    @Test @Order(1) void migrationsPreserveEmptyAndHistoricalData(){assertEquals(FaceServiceIntegrationDatabase.beforeV13,FaceServiceIntegrationDatabase.snapshotAll(jdbc));for(var ds:List.of(FaceServiceIntegrationDatabase.empty,FaceServiceIntegrationDatabase.history))assertEquals(0,FaceServiceIntegrationDatabase.enrollmentMigration(ds).migrate().migrationsExecuted);}
    @Test void pendingStagedCommittedPublishedAndUnverifiedEvidenceCannotAdmit()throws Exception {
        var a=actor();var before=business();var op=start(a);error(complete(a,op),503,"ERR_FACE_SAMPLES_REQUIRED");assertEquals("PENDING",dbStatus(op));stage(a,op,11,null);
        assertEquals("REJECTED",proof(scan(11,UUID.randomUUID(),UUID.randomUUID())).get("outcome"));
        var done=complete(a,op);status(done,200);assertEquals("ACTIVE",body(done).get("status"));assertEquals("SIMULATED_TEST",body(done).get("verificationMode"));assertEquals("ACTIVE",state(op).get("status"));
        UUID req=UUID.randomUUID(),capture=UUID.randomUUID();var result=proof(scan(11,req,capture));assertEquals(op.get("proposedProfileId"),result.get("profile"));assertEquals("NOT_PERFORMED",result.get("liveness"));
        var r=http.send(HttpRequest.newBuilder(URI.create("http://127.0.0.1:"+port+"/api/v1/check-ins/face")).header("X-Kiosk-Id","test-kiosk-a").header("X-Kiosk-Token",FaceServiceIntegrationDatabase.kioskA).header("Content-Type","application/json").POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(Map.of("requestId",req,"captureRef",capture)))).build(),HttpResponse.BodyHandlers.ofString());
        status(r,200);assertEquals(false,body(r).get("accessAllowed"));assertEquals(false,body(r).get("attendanceCreated"));assertEquals(before,business());
    }
    @Test void wrongBindingAndAuthAreControlledAndSameOperationRecovers()throws Exception {
        var a=actor();var op=start(a);stage(a,op,12,null);fault(Map.of("path","/v2/operations","replace",Map.of("member",UUID.randomUUID().toString())));
        error(complete(a,op),503,"ERR_FACE_ADAPTER_BINDING");assertEquals("PENDING",dbStatus(op));
        var malformed=new HashMap<String,Object>();malformed.put("status",null);fault(Map.of("path","/v2/operations","replace",malformed));error(complete(a,op),503,"ERR_FACE_ADAPTER_BINDING");assertEquals("PENDING",dbStatus(op));
        fault(Map.of("path","/v2/operations","statusBefore",401));error(complete(a,op),503,"ERR_FACE_SERVICE_UNAVAILABLE");assertEquals("PENDING",dbStatus(op));
        fault(Map.of());status(complete(a,op),200);assertEquals("ACTIVE",state(op).get("status"));status(service("GET","/v2/health",null,"wrong-private-authority"),401);
    }
    @Test void wrongGenerationAfterCommitIsNotSuccessAndRetryDoesNotDuplicate()throws Exception {
        var a=actor();var op=start(a);stage(a,op,13,null);fault(Map.of("path",opPath(op)+"/finalize","replace",Map.of("generation",0)));
        error(complete(a,op),503,"ERR_FACE_ADAPTER_BINDING");assertEquals("ACTIVE",dbStatus(op));fault(Map.of());status(complete(a,op),200);
        assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM facial_profiles WHERE member_id=?",Integer.class,a.member()));
        assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM audit_logs WHERE entity_id=? AND action='FACE_PROFILE_ACTIVATED'",Integer.class,UUID.fromString((String)op.get("proposedProfileId"))));
    }
    @Test void timeoutAfterExternalStageLeavesPendingAndExplicitRetryRecovers()throws Exception {
        var a=actor();var op=start(a);stage(a,op,14,null);fault(Map.of("path","/v2/operations","delayAfter",4));
        error(complete(a,op),503,"ERR_FACE_SERVICE_UNAVAILABLE");assertEquals("PENDING",dbStatus(op));assertEquals("STAGED",state(op).get("status"));fault(Map.of());status(complete(a,op),200);
    }
    @Test void timeoutAfterFinalizeLeavesOneMappingAndReconcilesSameOperation()throws Exception {
        var a=actor();var op=start(a);stage(a,op,15,null);fault(Map.of("path",opPath(op)+"/finalize","delayAfter",4));
        error(complete(a,op),503,"ERR_FACE_SERVICE_UNAVAILABLE");assertEquals("ACTIVE",dbStatus(op));assertEquals("ACTIVE",state(op).get("status"));fault(Map.of());status(complete(a,op),200);assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM facial_profiles WHERE member_id=?",Integer.class,a.member()));
    }
    @Test void databaseRollbackDoesNotPublishAndRecoveryKeepsOldUntilReplacement()throws Exception {
        var a=actor();var old=start(a);stage(a,old,16,null);status(complete(a,old),200);var op=start(a);stage(a,op,16,"f02:"+old.get("proposedProfileId"));
        String name="f03_fault_"+UUID.randomUUID().toString().replace("-","");
        jdbc.execute("CREATE FUNCTION "+name+"() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.id='"+op.get("proposedProfileId")+"'::uuid THEN RAISE EXCEPTION 'Synthetic rollback'; END IF; RETURN NEW; END $$");
        jdbc.execute("CREATE TRIGGER "+name+" BEFORE INSERT ON facial_profiles FOR EACH ROW EXECUTE FUNCTION "+name+"()");
        try{status(complete(a,op),500);assertEquals("PENDING",dbStatus(op));assertEquals("STAGED",state(op).get("status"));assertEquals(old.get("proposedProfileId"),proof(scan(16,UUID.randomUUID(),UUID.randomUUID())).get("profile"));}
        finally{jdbc.execute("DROP TRIGGER "+name+" ON facial_profiles");jdbc.execute("DROP FUNCTION "+name+"()");}
        status(complete(a,op),200);assertEquals(op.get("proposedProfileId"),proof(scan(16,UUID.randomUUID(),UUID.randomUUID())).get("profile"));assertEquals(2,((Number)state(op).get("generation")).intValue());
    }
    @Test void revokeWhileFinalizeWaitsTombstonesAndCannotResurrect()throws Exception {
        var a=actor();var op=start(a);stage(a,op,17,null);fault(Map.of("path",opPath(op)+"/finalize","pauseBefore",true));
        try(var pool=Executors.newSingleThreadExecutor()) {
            var future=pool.submit(()->complete(a,op));long until=System.nanoTime()+TimeUnit.SECONDS.toNanos(3);
            while(!Files.exists(signal(".entered"))&&System.nanoTime()<until)Thread.sleep(10);assertTrue(Files.exists(signal(".entered")));
            var r=call("POST",path(a)+"/profiles/"+op.get("proposedProfileId")+"/revoke",Map.of(),admin,UUID.randomUUID());status(r,200);
            Files.writeString(signal(".release"),"release");error(future.get(12,TimeUnit.SECONDS),503,"ERR_FACE_SERVICE_UNAVAILABLE");
        }finally{Files.writeString(signal(".release"),"release");fault(Map.of());}
        assertEquals("REVOKED",dbStatus(op));assertEquals("ABORTED",state(op).get("status"));assertEquals("REJECTED",proof(scan(17,UUID.randomUUID(),UUID.randomUUID())).get("outcome"));
    }
    @Test void concurrentCompletionsWaitOnPostgresAndPublishOnlyOnce()throws Exception {
        var a=actor();var op=start(a);stage(a,op,18,null);
        try(var held=FaceServiceIntegrationDatabase.history.getConnection();var pool=Executors.newFixedThreadPool(2)) {
            held.setAutoCommit(false);try(var q=held.prepareStatement("SELECT id FROM members WHERE id=? FOR NO KEY UPDATE")){q.setObject(1,a.member());q.executeQuery().close();}
            var ready=new CountDownLatch(2);var go=new CountDownLatch(1);Callable<HttpResponse<String>> task=()->{ready.countDown();assertTrue(go.await(3,TimeUnit.SECONDS));return complete(a,op);};var f=pool.submit(task);var g=pool.submit(task);assertTrue(ready.await(3,TimeUnit.SECONDS));go.countDown();
            long until=System.nanoTime()+TimeUnit.SECONDS.toNanos(5);int blocked=0;while(System.nanoTime()<until){blocked=jdbc.queryForObject("SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND wait_event_type='Lock' AND query LIKE '%FROM members%'",Integer.class);if(blocked>=2)break;Thread.sleep(10);}assertTrue(blocked>=2);held.commit();status(f.get(12,TimeUnit.SECONDS),200);status(g.get(12,TimeUnit.SECONDS),200);
        }
        assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM facial_profiles WHERE member_id=? AND status='ACTIVE'",Integer.class,a.member()));assertEquals("ACTIVE",state(op).get("status"));
    }
    @Test void realInferenceProvenanceCannotBeRecordedAsSyntheticProfile()throws Exception {
        var a=actor();var op=start(a);stage(a,op,19,null);fault(Map.of("path","/v2/operations","replace",Map.of("provenance","MODEL_INFERENCE_UNCALIBRATED")));
        error(complete(a,op),503,"ERR_FACE_REAL_ADMISSION_NOT_ENABLED");assertEquals("PENDING",dbStatus(op));assertEquals(0,jdbc.queryForObject("SELECT count(*) FROM facial_profiles WHERE member_id=?",Integer.class,a.member()));
    }
    @Test void pendingAbortCannotBeFinalizedAndDoesNotDeleteAnotherMember()throws Exception {
        var a=actor();var one=start(a);stage(a,one,20,null);status(complete(a,one),200);
        var b=actor();var two=start(b);stage(b,two,21,null);status(call("POST",path(b)+"/"+two.get("id")+"/revoke",Map.of(),admin,null),200);
        assertEquals("ABORTED",state(two).get("status"));assertEquals("ACTIVE",state(one).get("status"));assertEquals(one.get("proposedProfileId"),proof(scan(20,UUID.randomUUID(),UUID.randomUUID())).get("profile"));
        var wrong=call("POST",path(b)+"/profiles/"+one.get("proposedProfileId")+"/revoke",Map.of(),admin,UUID.randomUUID());error(wrong,404,"ERR_NOT_FOUND");
    }
    Map<String,Object> envelope(Map<String,Object> value)throws Exception {
        String payload=Base64.getUrlEncoder().withoutPadding().encodeToString(json.writeValueAsBytes(value));
        var mac=javax.crypto.Mac.getInstance("HmacSHA256");mac.init(new javax.crypto.spec.SecretKeySpec(signingKey.getBytes(java.nio.charset.StandardCharsets.UTF_8),"HmacSHA256"));
        return Map.of("payload",payload,"signature",HexFormat.of().formatHex(mac.doFinal(payload.getBytes(java.nio.charset.StandardCharsets.US_ASCII))));
    }
    HttpResponse<String> core(UUID request,UUID capture)throws Exception {
        return http.send(HttpRequest.newBuilder(URI.create("http://127.0.0.1:"+port+"/api/v1/check-ins/face")).header("X-Kiosk-Id","test-kiosk-a").header("X-Kiosk-Token",FaceServiceIntegrationDatabase.kioskA).header("Content-Type","application/json").POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(Map.of("requestId",request,"captureRef",capture)))).build(),HttpResponse.BodyHandlers.ofString());
    }
    @Test void coreChecksSignatureRequestGenerationAndCurrentProfileBeforeAnyAdmission()throws Exception {
        var a=actor();var op=start(a);stage(a,op,22,null);status(complete(a,op),200);
        for(String faultType:List.of("signature","request","generation")) {
            UUID req=UUID.randomUUID(),cap=UUID.randomUUID();var original=scan(22,req,cap);var d=proof(original);Map<String,Object> replacement;
            if(faultType.equals("signature"))replacement=Map.of("signature","0".repeat(64));
            else{d.put(faultType,faultType.equals("request")?UUID.randomUUID().toString():999);replacement=envelope(d);}
            fault(Map.of("path","/v2/captures/"+req+"/"+cap,"replace",replacement));var r=core(req,cap);
            if(faultType.equals("generation")){status(r,200);assertEquals(false,body(r).get("accessAllowed"));}
            else error(r,503,"ERR_FACE_ATTESTATION_INVALID");
            fault(Map.of());
        }
        UUID req=UUID.randomUUID(),cap=UUID.randomUUID();var stale=scan(22,req,cap);
        status(call("POST",path(a)+"/profiles/"+op.get("proposedProfileId")+"/revoke",Map.of(),admin,UUID.randomUUID()),200);
        var denied=core(req,cap);status(denied,200);assertEquals(false,body(denied).get("accessAllowed"));
        assertEquals(0,jdbc.queryForObject("SELECT count(*) FROM attendance_records WHERE member_id=?",Integer.class,a.member()));
    }
    @Test void duplicateReenrollmentStageFailsWithoutReplacingEitherMembersProfile()throws Exception {
        var a=actor();var first=start(a);stage(a,first,23,null);status(complete(a,first),200);
        var b=actor();var other=start(b);stage(b,other,24,null);status(complete(b,other),200);
        var next=start(a);var binding=new LinkedHashMap<String,Object>();binding.put("operation",next.get("id"));binding.put("member",a.member());binding.put("profile",next.get("proposedProfileId"));binding.put("reference","f02:"+next.get("proposedProfileId"));binding.put("predecessor","f02:"+first.get("proposedProfileId"));
        status(service("POST","/v2/operations",binding,control),200);error(service("POST",opPath(next)+"/samples",Map.of("frames",Collections.nCopies(5,image(24))),control),409,"DUPLICATE_IDENTITY");
        error(complete(a,next),503,"ERR_FACE_SAMPLES_REQUIRED");assertEquals("PENDING",dbStatus(next));assertEquals("ACTIVE",dbStatus(first));assertEquals("ACTIVE",dbStatus(other));
        assertEquals(first.get("proposedProfileId"),proof(scan(23,UUID.randomUUID(),UUID.randomUUID())).get("profile"));
        status(call("POST",path(a)+"/"+next.get("id")+"/revoke",Map.of(),admin,null),200);
        assertEquals("ACTIVE",state(first).get("status"));assertEquals("ACTIVE",state(other).get("status"));
    }

}
