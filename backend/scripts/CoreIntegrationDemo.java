import java.nio.file.*;import java.sql.*;import java.util.*;import java.security.SecureRandom;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.postgresql.ds.PGSimpleDataSource;import org.flywaydb.core.Flyway;
import vn.edu.tdtu.fitcenter.activation.AccountIntegrationRehearsalConfiguration;
/** I-01 demo uses a separate fresh pair, not the historical test fixtures. Seeds ONLY Admin. */
public class CoreIntegrationDemo {
 static String secret(){byte[] b=new byte[32];new SecureRandom().nextBytes(b);return Base64.getUrlEncoder().withoutPadding().encodeToString(b);}
 public static void main(String[] args)throws Exception{
  Path dir=Path.of(args[0]).toAbsolutePath().normalize();if(!dir.startsWith(Path.of(System.getenv("LOCALAPPDATA"),"Temp").toAbsolutePath().normalize())||!args[1].matches("[a-f0-9]{12}"))throw new IllegalArgumentException("Private guarded run required");
  Path file=dir.resolve("demo-fixture.properties");if(Files.exists(file))throw new IllegalStateException("Do not overwrite fixture authority");
  boolean current=args.length==3 && args[2].equals("--current");
  if(args.length>2&&!current)throw new IllegalArgumentException("Unknown demo mode");
  if(current&&(Files.exists(dir.resolve("checkin-demo-config.json"))||Files.exists(dir.resolve("enrollment-demo-config.json"))))throw new IllegalStateException("Never overwrite test adapter config");
  PGSimpleDataSource history=null;
  for(String kind:List.of("empty","history")){
   var ds=new PGSimpleDataSource();ds.setURL("jdbc:postgresql://127.0.0.1:15441/fitcenter_account_"+args[1]+"_"+kind+"_test");ds.setUser("fitcenter_account_app");ds.setPassword(System.getenv("DB_PASSWORD"));AccountIntegrationRehearsalConfiguration.verify(ds,true);
   try(var c=ds.getConnection();var s=c.createStatement();var r=s.executeQuery("SELECT count(*) FROM pg_tables WHERE schemaname='public'")){r.next();if(r.getInt(1)!=0)throw new IllegalStateException("Need newly created DBs, never reset/clean existing data");}
   String[] locations=current?new String[]{"classpath:db/migration","classpath:db/activation-rehearsal","classpath:db/membership-rehearsal","classpath:db/member-activation-rehearsal","classpath:db/renewal-rehearsal","classpath:db/checkin-rehearsal","classpath:db/enrollment-rehearsal"}:new String[]{"classpath:db/migration","classpath:db/activation-rehearsal","classpath:db/membership-rehearsal","classpath:db/member-activation-rehearsal"};
   Flyway.configure().dataSource(ds).locations(locations).outOfOrder(false).cleanDisabled(true).load().migrate();
   if(kind.equals("history"))history=ds;
  }
  UUID admin=UUID.randomUUID();String password=secret(),email="core-admin-"+admin+"@example.invalid";var f=new Properties();
  f.setProperty("nonce",args[1]);f.setProperty("historyDatabase",history.getDatabaseName());f.setProperty("admin.email",email);f.setProperty("admin.password",password);f.setProperty("admin.userId",admin.toString());f.setProperty("table.users",admin.toString());f.setProperty("seeded","false");
  try(var o=Files.newOutputStream(file,StandardOpenOption.CREATE_NEW)){f.store(o,"PRIVATE I-01 Admin seed authority; never publish");}
  try(var db=history.getConnection()){
   db.setAutoCommit(false);try(var p=db.prepareStatement("INSERT INTO users(id,email,password_hash,role,status) VALUES(?,?,?,'ADMIN','ACTIVE')")){
    p.setObject(1,admin);p.setString(2,email);p.setString(3,new BCryptPasswordEncoder().encode(password));p.executeUpdate();db.commit();
   }catch(Exception e){db.rollback();throw e;}
  }
  f.setProperty("seeded","true");try(var o=Files.newOutputStream(file)){f.store(o,"PRIVATE I-01 Admin seed authority; never publish");}
  if(current){
   Files.writeString(dir.resolve("checkin-demo-config.json"),"{\"mode\":\"SIMULATED_TEST\",\"kiosks\":[{\"id\":\"core-no-captures\",\"token\":\""+secret()+"\"}],\"captures\":[]}",StandardOpenOption.CREATE_NEW);
   Files.writeString(dir.resolve("enrollment-demo-config.json"),"{\"mode\":\"SIMULATED_TEST\",\"outcomes\":{}}",StandardOpenOption.CREATE_NEW);
  }
  System.out.println("Migrated fresh candidate pair; seeded only synthetic Admin. No plan/account/Membership/payment/Booking seeded.");
 }
}