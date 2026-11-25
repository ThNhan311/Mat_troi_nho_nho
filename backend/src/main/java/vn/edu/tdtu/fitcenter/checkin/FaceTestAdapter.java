package vn.edu.tdtu.fitcenter.checkin;

import java.nio.file.*;
import java.security.MessageDigest;
import java.nio.charset.StandardCharsets;
import java.util.*;
import javax.sql.DataSource;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;

/** Test-only opaque capture lookup. Never runs recognition, liveness, or accepts client member IDs. */
@Component
public final class FaceTestAdapter implements FaceVerificationAdapter, InitializingBean {
    private final boolean enabled, simulated;
    private final Environment env;
    private final DataSource dataSource;
    private final ObjectMapper json;
    private final String configPath;
    private Map<String,byte[]> kiosks=Map.of();
    private Map<UUID,Identity> captures=Map.of();
    public FaceTestAdapter(@Value("${fitcenter.checkin.enabled:false}") boolean enabled,
            @Value("${fitcenter.checkin.test-adapter.enabled:false}") boolean simulated,
            @Value("${fitcenter.checkin.test-config:}") String configPath,
            Environment env,DataSource dataSource,ObjectMapper json) {
        this.enabled=enabled;this.simulated=simulated;this.configPath=configPath;
        this.env=env;this.dataSource=dataSource;this.json=json;
    }
    public boolean enabled() { return enabled; }
    public void requireEnabled() {
        if(!enabled)throw new CheckinFailure(503,"ERR_CHECKIN_UNAVAILABLE","Face check-in is unavailable in this environment");
    }
    public void afterPropertiesSet() {
        if(!enabled) { if(simulated)throw new IllegalStateException("Test adapter requires the check-in gate");return; }
        if(!simulated||!(Arrays.equals(env.getActiveProfiles(),new String[]{"face-checkin-rehearsal"})||Arrays.equals(env.getActiveProfiles(),new String[]{"face-enrollment-rehearsal"}))
                ||!env.getProperty("fitcenter.checkin.guard-verified",Boolean.class,false))
            throw new IllegalStateException("F01 requires its guarded rehearsal profile; no default fake recognition");
        vn.edu.tdtu.fitcenter.activation.AccountIntegrationRehearsalConfiguration.verify(dataSource,
                env.getProperty("fitcenter.account-integration.guard-verified",Boolean.class,false));
        try {
            Path path=Path.of(configPath).toRealPath(), temp=Path.of(System.getenv("LOCALAPPDATA"),"Temp").toRealPath();
            if(!path.startsWith(temp)||Files.size(path)>1048576)throw new IllegalStateException("Private test fixture file required");
            var document=json.readTree(Files.readString(path));
            if(!"SIMULATED_TEST".equals(document.path("mode").asText())||!document.path("kiosks").isArray()||!document.path("captures").isArray())
                throw new IllegalStateException("Explicit simulated identity configuration required");
            var keys=new HashMap<String,byte[]>();var ids=new HashMap<UUID,Identity>();
            for(var kiosk:document.get("kiosks")) {
                String id=kiosk.path("id").asText(), token=kiosk.path("token").asText();
                if(!id.matches("[a-z0-9][a-z0-9_-]{0,49}")||!token.matches("[A-Za-z0-9_-]{43,128}")||keys.put(id,digest(token))!=null)
                    throw new IllegalStateException("Invalid registered test kiosk");
            }
            if(keys.isEmpty())throw new IllegalStateException("Registered kiosk required");
            for(var capture:document.get("captures")) {
                UUID id=UUID.fromString(capture.path("captureRef").asText());String outcome=capture.path("outcome").asText();
                if(!Set.of("MATCHED","NO_MATCH","UNKNOWN").contains(outcome))throw new IllegalStateException("Invalid test identity outcome");
                UUID profile=capture.path("facialProfileId").isNull()||capture.path("facialProfileId").isMissingNode()?null:UUID.fromString(capture.path("facialProfileId").asText());
                if(outcome.equals("MATCHED")!=(profile!=null)||ids.put(id,new Identity(outcome,profile))!=null)
                    throw new IllegalStateException("Invalid synthetic capture binding");
            }
            kiosks=Map.copyOf(keys);captures=Map.copyOf(ids);
        } catch(Exception ex) { throw new IllegalStateException("Cannot load private simulated adapter configuration"); }
    }
    private static byte[] digest(String value) {
        try{return MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));}
        catch(Exception ex){throw new IllegalStateException("Digest unavailable");}
    }
    public boolean authenticate(String kiosk,String token) {
        if(!enabled||kiosk==null||token==null||token.length()>128)return false;
        byte[] expected=kiosks.get(kiosk);return expected!=null&&MessageDigest.isEqual(expected,digest(token));
    }
    public Identity verify(UUID capture) { requireEnabled();return captures.getOrDefault(capture,new Identity("UNKNOWN",null)); }
}
