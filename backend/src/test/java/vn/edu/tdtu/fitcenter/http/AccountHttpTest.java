package vn.edu.tdtu.fitcenter.http;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.*;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.ObjectMapper;
import vn.edu.tdtu.fitcenter.service.AdminAccountService;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.dto.account.AccountCreateRequest;
import java.net.*;import java.net.http.*;import java.time.*;import java.sql.*;import java.util.*;import java.util.regex.Pattern;import java.util.concurrent.*;
import static org.junit.jupiter.api.Assertions.*;
@SpringBootTest(webEnvironment=SpringBootTest.WebEnvironment.RANDOM_PORT,properties={"server.address=127.0.0.1","spring.main.banner-mode=off","fitcenter.activation.enabled=false"})
@ActiveProfiles("default") @DirtiesContext(classMode=DirtiesContext.ClassMode.AFTER_CLASS)
@TestInstance(TestInstance.Lifecycle.PER_CLASS) @EnabledIfEnvironmentVariable(named="RUN_HTTP_BASELINE_TESTS",matches="true")
class AccountHttpTest {
 @LocalServerPort int port;@Autowired JdbcTemplate jdbc;@Autowired PasswordEncoder encoder;@Autowired PlatformTransactionManager transactions;@Autowired ObjectMapper json;@Autowired AdminAccountService service;
 private HttpBaselineFixture fixture;private HttpClient client;private final Set<UUID> created=ConcurrentHashMap.newKeySet();
    @DynamicPropertySource
    static void guardedDatasource(DynamicPropertyRegistry properties) {
        if (Runtime.version().feature() != 21) throw new IllegalStateException("JDK 21 required");
        if (!"true".equals(System.getenv("HTTP_BASELINE_GUARD_VERIFIED"))) {
            throw new IllegalStateException("Run through backend/scripts/test-http-baseline.ps1");
        }
        String url = required("DB_URL"), user = required("DB_USERNAME"), password = required("DB_PASSWORD");
        String expectedDb = required("HTTP_BASELINE_EXPECTED_DATABASE");
        var matcher = Pattern.compile("^jdbc:postgresql://127\\.0\\.0\\.1:[0-9]+/(fitcenter_(?:baseline|http)_[a-z0-9_]+_test)$").matcher(url);
        if (!matcher.matches() || !matcher.group(1).equals(expectedDb)) {
            throw new IllegalStateException("Only an explicitly verified loopback test database is allowed");
        }
        // Runs before Spring creates its datasource/Flyway: do not migrate an unverified target.
        try (var connection = DriverManager.getConnection(url, user, password);
             var statement = connection.createStatement()) {
            try (var result = statement.executeQuery("SELECT current_database(),current_user,rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls FROM pg_roles WHERE rolname=current_user")) {
                if (!result.next() || !expectedDb.equals(result.getString(1)) || !user.equals(result.getString(2)) || result.getBoolean(3)) {
                    throw new IllegalStateException("Database/role verification failed");
                }
            }
            try (var result = statement.executeQuery("SELECT string_agg(version,',' ORDER BY installed_rank),bool_and(success) FROM flyway_schema_history WHERE version IS NOT NULL")) {
                if (!result.next() || !"1,2,3,4,5,6".equals(result.getString(1)) || !result.getBoolean(2)) {
                    throw new IllegalStateException("An existing verified canonical V1-V6 schema is required; V7 is forbidden");
                }
            }
        } catch (SQLException error) {
            throw new IllegalStateException("Database preflight failed; SQLSTATE=" + error.getSQLState());
        }
        properties.add("spring.datasource.url", () -> url);
        properties.add("spring.datasource.username", () -> user);
        properties.add("spring.datasource.password", () -> password);
        properties.add("spring.flyway.locations", () -> "classpath:db/migration");
        String jwtSecret = HttpBaselineFixture.randomSecret();
        properties.add("jwt.secret", () -> jwtSecret);
    }

    private static String required(String name) {
        String value = System.getenv(name);
        if (value == null || value.isBlank()) throw new IllegalStateException("Missing environment variable " + name);
        return value;
    }


 @BeforeAll void setup(){client=HttpClient.newHttpClient();fixture=new HttpBaselineFixture(jdbc,new TransactionTemplate(transactions));fixture.seed(encoder);}
 @AfterEach void cleanup(){
  for(UUID id:created){jdbc.update("DELETE FROM audit_logs WHERE entity_type='USER' AND entity_id=? AND action='ACCOUNT_CREATED_PENDING_ACTIVATION'",id);jdbc.update("DELETE FROM members WHERE user_id=?",id);jdbc.update("DELETE FROM personal_trainers WHERE user_id=?",id);jdbc.update("DELETE FROM users WHERE id=?",id);}created.clear();
  jdbc.update("UPDATE users SET status='ACTIVE' WHERE id=?",fixture.admin.userId);
 }
 @AfterAll void close(){fixture.close();client.close();}
 private Map<String,Object> input(String email){return Map.of("email",email,"fullName","Synthetic account");}
 private String email(){return "account-test-"+UUID.randomUUID()+"@example.invalid";}
 private HttpResponse<String> send(String method,String path,String access,Object body)throws Exception{
  var r=HttpRequest.newBuilder(URI.create("http://127.0.0.1:"+port+path)).timeout(Duration.ofSeconds(10)).header("X-Correlation-Id","account-test");
  if(access!=null)r.header("Authorization","Bearer "+access);if(body!=null)r.header("Content-Type","application/json");
  return client.send(r.method(method,body==null?HttpRequest.BodyPublishers.noBody():HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body))).build(),HttpResponse.BodyHandlers.ofString());
 }
 @SuppressWarnings("unchecked") private Map<String,Object> object(HttpResponse<String> r){return json.readValue(r.body(),Map.class);}
 private String token(HttpBaselineFixture.Actor actor)throws Exception{var r=send("POST","/api/v1/auth/login",null,Map.of("email",actor.email,"password",actor.password));assertEquals(200,r.statusCode());return (String)object(r).get("accessToken");}
 private void error(HttpResponse<String> r,int status,String code){assertEquals(status,r.statusCode());var b=object(r);assertEquals(false,b.get("success"));var e=(Map<?,?>)b.get("error");assertEquals(code,e.get("code"));assertEquals("account-test",e.get("correlationId"));assertFalse(r.body().contains("password_hash"));}
 private Map<String,Object> create(String path,String access,Map<String,Object> input)throws Exception{var r=send("POST",path,access,input);if(r.statusCode()==201)created.add(UUID.fromString((String)object(r).get("userId")));assertEquals(201,r.statusCode());return object(r);}
 @ParameterizedTest @ValueSource(strings={"members","personal-trainers"})
 void adminCreatesAtomicInactiveAccountAndReadsIt(String route)throws Exception{
  int memberships=jdbc.queryForObject("SELECT count(*) FROM memberships",Integer.class),bookings=jdbc.queryForObject("SELECT count(*) FROM bookings",Integer.class);
  var data=input(email());String admin=token(fixture.admin);var b=create("/api/v1/admin/"+route,admin,data);UUID userId=UUID.fromString((String)b.get("userId")),profile=UUID.fromString((String)b.get("profileId"));
  assertNotEquals(userId,profile);assertEquals(Set.of("userId","profileId","email","fullName","role","status","activationPending"),b.keySet());assertEquals("DISABLED",b.get("status"));assertEquals(true,b.get("activationPending"));
  String role=route.equals("members")?"MEMBER":"PT",table=route.equals("members")?"members":"personal_trainers";assertEquals(role,b.get("role"));assertEquals(data.get("email"),b.get("email"));
  assertEquals(profile,jdbc.queryForObject("SELECT id FROM "+table+" WHERE user_id=?",UUID.class,userId));
  String hash=jdbc.queryForObject("SELECT password_hash FROM users WHERE id=?",String.class,userId);assertTrue(hash.startsWith("$2"));assertFalse(b.containsKey("password"));assertFalse(b.containsKey("accessToken"));
  var list=send("GET","/api/v1/admin/"+route,admin,null);assertEquals(200,list.statusCode());assertTrue(json.readValue(list.body(),List.class).contains(b));
  error(send("POST","/api/v1/auth/login",null,Map.of("email",data.get("email"),"password","synthetic-not-a-password")),401,"ERR_UNAUTHORIZED");
  assertEquals(memberships,jdbc.queryForObject("SELECT count(*) FROM memberships",Integer.class));assertEquals(bookings,jdbc.queryForObject("SELECT count(*) FROM bookings",Integer.class));assertEquals(0,jdbc.queryForObject("SELECT count(*) FROM payment_transactions",Integer.class));
 }
 @ParameterizedTest @ValueSource(strings={"members","personal-trainers"})
 void authorizationAndInactiveAdmin(String route)throws Exception{String p="/api/v1/admin/"+route;error(send("POST",p,null,input(email())),401,"ERR_UNAUTHORIZED");for(var a:List.of(fixture.memberA,fixture.ptA)){error(send("POST",p,token(a),input(email())),403,"ERR_FORBIDDEN");error(send("GET",p,token(a),null),403,"ERR_FORBIDDEN");}String admin=token(fixture.admin);jdbc.update("UPDATE users SET status='SUSPENDED' WHERE id=?",fixture.admin.userId);error(send("POST",p,admin,input(email())),401,"ERR_UNAUTHORIZED");}
 @ParameterizedTest @ValueSource(strings={"email","fullName"})
 void requiredFields(String key)throws Exception{String access=token(fixture.admin);var m=new HashMap<String,Object>(input(email()));m.remove(key);error(send("POST","/api/v1/admin/members",access,m),400,"ERR_VALIDATION");m.put(key,null);error(send("POST","/api/v1/admin/members",access,m),400,"ERR_VALIDATION");m.put(key,7);error(send("POST","/api/v1/admin/members",access,m),400,"ERR_VALIDATION");}
 @ParameterizedTest @ValueSource(strings={"role","status","password","userId","membershipId"})
 void rejectsMassAssignment(String key)throws Exception{var m=new HashMap<String,Object>(input(email()));m.put(key,"client-controlled");error(send("POST","/api/v1/admin/members",token(fixture.admin),m),400,"ERR_VALIDATION");}
 @Test void textAndEmailValidation()throws Exception{for(var change:List.of(Map.of("email","invalid"),Map.of("email","x".repeat(256)+"@example.invalid"),Map.of("fullName"," "),Map.of("fullName","x".repeat(151)))){var m=new HashMap<String,Object>(input(email()));m.putAll(change);error(send("POST","/api/v1/admin/members",token(fixture.admin),m),400,"ERR_VALIDATION");}}
 @Test void uniqueEmailCaseInsensitiveConflictRollsBackProfile()throws Exception{String access=token(fixture.admin),email=email();create("/api/v1/admin/members",access,input(email));int count=jdbc.queryForObject("SELECT count(*) FROM users",Integer.class);error(send("POST","/api/v1/admin/personal-trainers",access,input(email.toUpperCase(Locale.ROOT))),409,"ERR_CONFLICT");assertEquals(count,jdbc.queryForObject("SELECT count(*) FROM users",Integer.class));}
 @Test void rollbackAfterCreateRemovesUserProfileAndAudit(){var id=new java.util.concurrent.atomic.AtomicReference<UUID>();assertThrows(IllegalStateException.class,()->new TransactionTemplate(transactions).executeWithoutResult(tx->{id.set(service.create(fixture.admin.email,Role.PT,new AccountCreateRequest(email(),"Synthetic rollback")).userId());throw new IllegalStateException("rollback");}));assertEquals(0,jdbc.queryForObject("SELECT count(*) FROM users WHERE id=?",Integer.class,id.get()));assertEquals(0,jdbc.queryForObject("SELECT count(*) FROM personal_trainers WHERE user_id=?",Integer.class,id.get()));assertEquals(0,jdbc.queryForObject("SELECT count(*) FROM audit_logs WHERE entity_id=?",Integer.class,id.get()));}
 @Test void concurrentDuplicateCreatesAtMostOneAccount()throws Exception{String access=token(fixture.admin),email=email();var start=new CountDownLatch(1);try(var pool=Executors.newFixedThreadPool(2)){var tasks=new ArrayList<Future<HttpResponse<String>>>();for(int i=0;i<2;i++)tasks.add(pool.submit(()->{start.await();return send("POST","/api/v1/admin/personal-trainers",access,input(email));}));start.countDown();var statuses=new ArrayList<Integer>();for(var task:tasks){var r=task.get(15,TimeUnit.SECONDS);statuses.add(r.statusCode());if(r.statusCode()==201)created.add(UUID.fromString((String)object(r).get("userId")));else error(r,409,"ERR_CONFLICT");}assertEquals(List.of(201,409),statuses.stream().sorted().toList());assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM users WHERE lower(email)=lower(?)",Integer.class,email));}}
 @Test void otpGateDoesNotQueryOrCreateUnapprovedTable()throws Exception{assertEquals(false,jdbc.queryForObject("SELECT to_regclass('public.pt_account_activation') IS NOT NULL",Boolean.class));error(send("POST","/api/v1/auth/pt-activation/request-otp",null,Map.of("email",email())),503,"ERR_ACTIVATION_NOT_READY");error(send("POST","/api/v1/auth/pt-activation/verify-otp",null,Map.of("email",email(),"otp","000000")),503,"ERR_ACTIVATION_NOT_READY");error(send("POST","/api/v1/auth/pt-activation/password",null,Map.of("verificationToken","a".repeat(43),"password","synthetic-test-password")),503,"ERR_ACTIVATION_NOT_READY");}
}
