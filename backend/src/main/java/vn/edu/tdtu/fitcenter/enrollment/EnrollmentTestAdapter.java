package vn.edu.tdtu.fitcenter.enrollment;
import java.nio.file.*;import java.nio.channels.FileChannel;import java.util.*;import javax.sql.DataSource;
import org.springframework.beans.factory.InitializingBean;import org.springframework.beans.factory.annotation.Value;import org.springframework.core.env.Environment;import org.springframework.stereotype.Component;import tools.jackson.databind.ObjectMapper;
/** Test-only external journal, no images/vectors/model/liveness. Never an enrollment attestation in production. */
@Component public final class EnrollmentTestAdapter implements EnrollmentAdapter,InitializingBean {
 private final boolean enabled;private final Environment env;private final DataSource ds;private final ObjectMapper json;private final String path;private Path config,journal,lock;
 public EnrollmentTestAdapter(@Value("${fitcenter.enrollment.enabled:false}")boolean enabled,@Value("${fitcenter.enrollment.test-config:}")String path,Environment env,DataSource ds,ObjectMapper json){this.enabled=enabled;this.path=path;this.env=env;this.ds=ds;this.json=json;}
 public boolean enabled(){return enabled;}
 public void afterPropertiesSet(){if(!enabled)return;
  if(!Arrays.equals(env.getActiveProfiles(),new String[]{"face-enrollment-rehearsal"})||!env.getProperty("fitcenter.enrollment.guard-verified",Boolean.class,false))throw new IllegalStateException("Enrollment adapter is guarded rehearsal-only");
  vn.edu.tdtu.fitcenter.activation.AccountIntegrationRehearsalConfiguration.verify(ds,env.getProperty("fitcenter.account-integration.guard-verified",Boolean.class,false));
  try{config=Path.of(path).toRealPath();Path temp=Path.of(System.getenv("LOCALAPPDATA"),"Temp").toRealPath();if(!config.startsWith(temp))throw new IllegalStateException();settings();journal=config.resolveSibling(config.getFileName()+".journal.json");lock=config.resolveSibling(config.getFileName()+".lock");}catch(Exception e){throw new IllegalStateException("Private simulated enrollment configuration required");}
 }
 private Map<String,Object> settings(){try{if(Files.size(config)>1048576)throw new IllegalStateException();var d=json.readValue(Files.readString(config),Map.class);if(!"SIMULATED_TEST".equals(d.get("mode")))throw new IllegalStateException();return d;}catch(Exception e){throw new IllegalStateException("Invalid private enrollment settings");}}
 private synchronized <T>T change(java.util.function.Function<Map<String,Map<String,Object>>,T> work){
  if(!enabled)throw new IllegalStateException("Enrollment disabled");
  try(var channel=FileChannel.open(lock,StandardOpenOption.CREATE,StandardOpenOption.WRITE);var held=channel.lock()){
   Map<String,Map<String,Object>> rows=Files.exists(journal)?json.readValue(Files.readString(journal),Map.class):new LinkedHashMap<>();T result=work.apply(rows);
   Path temporary=journal.resolveSibling(journal.getFileName()+".tmp");Files.writeString(temporary,json.writeValueAsString(rows));Files.move(temporary,journal,StandardCopyOption.ATOMIC_MOVE,StandardCopyOption.REPLACE_EXISTING);return result;
  }catch(Exception e){throw new IllegalStateException("External simulated gallery operation unavailable");}
 }
 public Prepared prepare(UUID op,UUID member,UUID profile,String reference){return change(rows->{
  var row=rows.get(op.toString());if(row==null){var rules=settings().get("outcomes");String outcome=rules instanceof Map<?,?> map?String.valueOf(map.get(member.toString())):"READY";if(outcome.equals("null"))outcome="READY";
   row=new LinkedHashMap<>();row.put("operation",op.toString());row.put("member",(outcome.equals("WRONG_MEMBER")?UUID.randomUUID():member).toString());row.put("profile",profile.toString());row.put("reference",reference);boolean tombstone=rows.containsKey("removed:"+reference);row.put("ready",!outcome.equals("FAILED")&&!tombstone);row.put("removed",tombstone);row.put("captureRef",UUID.randomUUID().toString());rows.put(op.toString(),row);
  }
  return new Prepared(UUID.fromString((String)row.get("operation")),UUID.fromString((String)row.get("member")),UUID.fromString((String)row.get("profile")),(String)row.get("reference"),Boolean.TRUE.equals(row.get("ready"))&&!Boolean.TRUE.equals(row.get("removed")));
 });}
 public void remove(String reference){change(rows->{if(Boolean.TRUE.equals(settings().get("failRemoval")))throw new IllegalStateException();for(var row:rows.values())if(reference.equals(row.get("reference")))row.put("removed",true);rows.put("removed:"+reference,new LinkedHashMap<>(Map.of("reference",reference,"removed",true,"ready",false)));return null;});}
 public String identify(UUID capture){if(!enabled)return null;return change(rows->{for(var row:rows.values())if(capture.toString().equals(row.get("captureRef"))&&Boolean.TRUE.equals(row.get("ready"))&&!Boolean.TRUE.equals(row.get("removed")))return (String)row.get("reference");return null;});}
}
