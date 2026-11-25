package vn.edu.tdtu.fitcenter.enrollment;

import java.net.URI;
import java.net.http.*;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.*;
import java.util.*;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import javax.sql.DataSource;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.env.Environment;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;
import vn.edu.tdtu.fitcenter.checkin.CheckinFailure;

/** Actual HTTP transport. V13 accepts SIMULATED_TEST only: real model admission remains closed. */
@Component
@ConditionalOnProperty(name="fitcenter.face-service.enabled",havingValue="true")
public final class RemoteEnrollmentAdapter implements EnrollmentAdapter,InitializingBean {
    private final Environment env;
    private final DataSource ds;
    private final ObjectMapper json;
    private final JdbcTemplate jdbc;
    private final Clock clock;
    private final String configPath;
    private URI base;
    private String token,signingKey;
    private final HttpClient http=HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(2))
        .followRedirects(HttpClient.Redirect.NEVER).build();

    public RemoteEnrollmentAdapter(Environment env,DataSource ds,ObjectMapper json,JdbcTemplate jdbc,Clock clock,
            @Value("${fitcenter.face-service.private-config:}")String configPath) {
        this.env=env;this.ds=ds;this.json=json;this.jdbc=jdbc;this.clock=clock;this.configPath=configPath;
    }
    public boolean enabled(){return true;}
    public void afterPropertiesSet() {
        if(!Arrays.equals(env.getActiveProfiles(),new String[]{"face-enrollment-rehearsal"})
                ||!env.getProperty("fitcenter.enrollment.enabled",Boolean.class,false)
                ||!env.getProperty("fitcenter.enrollment.guard-verified",Boolean.class,false)
                ||!env.getProperty("fitcenter.face-service.guard-verified",Boolean.class,false))
            throw new IllegalStateException("Remote Face requires guarded private enrollment rehearsal");
        vn.edu.tdtu.fitcenter.activation.AccountIntegrationRehearsalConfiguration.verify(ds,
            env.getProperty("fitcenter.account-integration.guard-verified",Boolean.class,false));
        try {
            Path path=Path.of(configPath).toRealPath(),temp=Path.of(System.getenv("LOCALAPPDATA"),"Temp").toRealPath();
            if(!path.startsWith(temp)||Files.size(path)>16384)throw new IllegalStateException();
            var d=json.readTree(Files.readString(path));base=URI.create(d.path("url").asText());
            if(!"http".equals(base.getScheme())||!"127.0.0.1".equals(base.getHost())||base.getPort()<1024
                    ||!"".equals(base.getPath())||base.getQuery()!=null||base.getFragment()!=null||base.getUserInfo()!=null)
                throw new IllegalStateException();
            token=d.path("controlToken").asText();signingKey=d.path("signingKey").asText();
            if(token.length()<32||signingKey.length()<32)throw new IllegalStateException();
        }catch(Exception ex){throw new IllegalStateException("Private loopback Face configuration required");}
    }
    private CheckinFailure unavailable(String code) {
        return new CheckinFailure(503,code,"Face service unavailable or result unverified; reconcile the same operation");
    }
    private Map<String,Object> call(String method,String path,Object body) {
        try {
            var request=HttpRequest.newBuilder(base.resolve(path)).timeout(Duration.ofSeconds(3))
                .header("X-Face-Token",token).header("Content-Type","application/json")
                .method(method,body==null?HttpRequest.BodyPublishers.noBody():HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body))).build();
            var response=http.send(request,HttpResponse.BodyHandlers.ofString());
            if(response.statusCode()!=200||response.body().length()>65536)throw unavailable("ERR_FACE_SERVICE_UNAVAILABLE");
            Map<String,Object> document=json.readValue(response.body(),Map.class);
            if(document==null)throw unavailable("ERR_FACE_SERVICE_UNAVAILABLE");
            return document;
        }catch(InterruptedException ex){Thread.currentThread().interrupt();throw unavailable("ERR_FACE_SERVICE_UNAVAILABLE");}
        catch(CheckinFailure ex){throw ex;}
        catch(Exception ex){throw unavailable("ERR_FACE_SERVICE_UNAVAILABLE");}
    }
    private static boolean generation(Object value) {
        return (value instanceof Integer||value instanceof Long)&&((Number)value).longValue()>0;
    }
    private Prepared checked(Map<String,Object> d,UUID op,UUID member,UUID profile,String reference) {
        if(!op.toString().equals(d.get("operation"))||!member.toString().equals(d.get("member"))
                ||!profile.toString().equals(d.get("profile"))||!reference.equals(d.get("reference"))
                ||!generation(d.get("generation"))
                ||!Set.of("PREPARED","STAGED","ACTIVE","REPLACED","ABORTED").contains(Objects.toString(d.get("status"),"")))
            throw unavailable("ERR_FACE_ADAPTER_BINDING");
        // Never write actual model inference as SIMULATED_TEST or widen immutable V13 constraints.
        if(!"SYNTHETIC_PROTOCOL".equals(d.get("provenance")))throw unavailable("ERR_FACE_REAL_ADMISSION_NOT_ENABLED");
        return new Prepared(op,member,profile,reference,Set.of("STAGED","ACTIVE").contains(d.get("status")),((Number)d.get("generation")).longValue());
    }
    public Prepared prepare(UUID op,UUID member,UUID profile,String reference){return prepare(op,member,profile,reference,null);}
    public Prepared prepare(UUID op,UUID member,UUID profile,String reference,String predecessor) {
        var body=new LinkedHashMap<String,Object>();body.put("operation",op);body.put("member",member);
        body.put("profile",profile);body.put("reference",reference);body.put("predecessor",predecessor);
        var d=call("POST","/v2/operations",body);var prepared=checked(d,op,member,profile,reference);
        if(!Objects.equals(predecessor,d.get("predecessor")))throw unavailable("ERR_FACE_ADAPTER_BINDING");
        if(!prepared.ready())throw unavailable("ERR_FACE_SAMPLES_REQUIRED");
        return prepared;
    }
    public void finalizeEnrollment(UUID op,UUID member,UUID profile,String reference) {
        var d=call("GET","/v2/operations/"+op,null);var p=checked(d,op,member,profile,reference);
        if(!p.ready())throw unavailable("ERR_FACE_SAMPLES_REQUIRED");
        d=call("POST","/v2/operations/"+op+"/finalize",Map.of("member",member,"profile",profile,"reference",reference,"generation",p.generation()));
        checked(d,op,member,profile,reference);
        if(!"ACTIVE".equals(d.get("status")))throw unavailable("ERR_FACE_ADAPTER_BINDING");
    }
    public void remove(String reference) {
        if(!reference.startsWith("f02:"))throw unavailable("ERR_FACE_ADAPTER_BINDING");UUID.fromString(reference.substring(4));
        var d=call("POST","/v2/references/abort",Map.of("reference",reference));
        if(!reference.equals(d.get("reference"))||!"ABORTED".equals(d.get("status")))throw unavailable("ERR_FACE_ADAPTER_BINDING");
    }
    public String identify(UUID capture){return null;}
    public String identify(UUID request,UUID capture) {
        if(request==null)return null;
        var envelope=call("GET","/v2/captures/"+request+"/"+capture,null);
        var proof=verifyAttestation(envelope,request,capture,signingKey,clock.instant());
        if(!"SYNTHETIC_PROTOCOL".equals(proof.get("provenance")))throw unavailable("ERR_FACE_REAL_ADMISSION_NOT_ENABLED");
        if(!"MATCHED".equals(proof.get("outcome")))return null;
        var rows=jdbc.queryForList("SELECT f.id FROM facial_profiles f JOIN face_enrollments e ON e.activated_profile_id=f.id AND e.member_id=f.member_id AND e.template_ref=f.template_ref WHERE f.status='ACTIVE' AND e.status='ACTIVE' AND f.id=? AND f.template_ref=?",
            UUID.fromString((String)proof.get("profile")),proof.get("reference"));
        if(rows.size()!=1)return null;
        var op=jdbc.queryForObject("SELECT id FROM face_enrollments WHERE activated_profile_id=?",UUID.class,rows.getFirst().get("id"));
        var state=call("GET","/v2/operations/"+op,null);
        if(!"ACTIVE".equals(state.get("status"))||!Objects.equals(proof.get("profile"),state.get("profile"))
                ||!Objects.equals(proof.get("reference"),state.get("reference"))||!Objects.equals(proof.get("provenance"),state.get("provenance"))
                ||!generation(state.get("generation"))||((Number)proof.get("generation")).longValue()!=((Number)state.get("generation")).longValue())return null;
        // PAD, production calibration and non-simulated schema mode are not approved: never admit.
        return null;
    }
    public Map<String,Object> verifyAttestation(Map<String,Object> envelope,UUID request,UUID capture,String key,Instant now) {
        try {
            String payload=(String)envelope.get("payload"),signature=(String)envelope.get("signature");
            if(payload==null||payload.length()>8192||signature==null||!signature.matches("[a-f0-9]{64}"))throw new IllegalArgumentException();
            Mac mac=Mac.getInstance("HmacSHA256");mac.init(new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8),"HmacSHA256"));
            if(!MessageDigest.isEqual(mac.doFinal(payload.getBytes(StandardCharsets.US_ASCII)),HexFormat.of().parseHex(signature)))throw new IllegalArgumentException();
            var d=json.readValue(new String(Base64.getUrlDecoder().decode(payload),StandardCharsets.UTF_8),Map.class);
            if(!generation(d.get("issuedAt"))||!generation(d.get("expiresAt")))throw new IllegalArgumentException();
            long issued=((Number)d.get("issuedAt")).longValue(),expiry=((Number)d.get("expiresAt")).longValue();
            if(!request.toString().equals(d.get("request"))||!capture.toString().equals(d.get("capture"))
                    ||issued>now.getEpochSecond()||expiry<=now.getEpochSecond()||expiry<=issued||expiry-issued>10
                    ||!"insightface-buffalo_s".equals(d.get("model"))
                    ||!Set.of("SYNTHETIC_PROTOCOL","MODEL_INFERENCE_UNCALIBRATED").contains(d.get("provenance"))
                    ||!"NOT_PERFORMED".equals(d.get("liveness"))||!Boolean.FALSE.equals(d.get("admissionEnabled")))throw new IllegalArgumentException();
            if("MATCHED".equals(d.get("outcome"))) {
                UUID profile=UUID.fromString((String)d.get("profile"));
                if(!("f02:"+profile).equals(d.get("reference"))||!generation(d.get("generation")))throw new IllegalArgumentException();
            }
            return d;
        }catch(Exception ex){throw unavailable("ERR_FACE_ATTESTATION_INVALID");}
    }
}
