import java.nio.file.*;import java.sql.*;import java.util.*;import java.security.SecureRandom;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
/** Only Admin+plan seed. MEMBER account and Membership are created by actual UI. */
public class AccountIntegrationDemo {
 static String secret(){byte[] b=new byte[32];new SecureRandom().nextBytes(b);return Base64.getUrlEncoder().withoutPadding().encodeToString(b);}
 public static void main(String[] args)throws Exception{
  Path dir=Path.of(args[0]).toAbsolutePath().normalize();if(!dir.startsWith(Path.of(System.getenv("LOCALAPPDATA"),"Temp").toAbsolutePath().normalize()))throw new IllegalArgumentException("Private Temp required");
  Path file=dir.resolve("demo-fixture.properties");if(Files.exists(file)||!args[1].matches("[a-f0-9]{12}"))throw new IllegalStateException("Use a new demo fixture registry");
  var target=java.net.URI.create(System.getenv("DB_URL").substring(5));if(!target.getHost().equals("127.0.0.1")||target.getPort()!=15441||!target.getPath().equals("/fitcenter_account_"+args[1]+"_history_test"))throw new IllegalStateException("Wrong isolated target");
  try(var db=DriverManager.getConnection(System.getenv("DB_URL"),System.getenv("DB_USERNAME"),System.getenv("DB_PASSWORD"))){try(var st=db.createStatement();var q=st.executeQuery("SELECT current_user,(rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls),(SELECT string_agg(version,',' ORDER BY installed_rank) FROM flyway_schema_history WHERE success) FROM pg_roles WHERE rolname=current_user")){if(!q.next()||!q.getString(1).equals("fitcenter_account_app")||q.getBoolean(2)||!q.getString(3).equals("1,2,3,4,5,6,8,9,10"))throw new IllegalStateException("Role/history mismatch");}
   var f=new Properties();UUID admin=UUID.randomUUID(),plan=UUID.randomUUID();String password=secret(),email="member-demo-admin-"+admin+"@example.invalid";
   f.setProperty("historyDatabase",target.getPath().substring(1));f.setProperty("nonce",args[1]);f.setProperty("admin.email",email);f.setProperty("admin.password",password);f.setProperty("admin.userId",admin.toString());f.setProperty("table.users",admin.toString());f.setProperty("table.membership_plans",plan.toString());f.setProperty("seeded","false");
   try(var out=Files.newOutputStream(file,StandardOpenOption.CREATE_NEW)){f.store(out,"PRIVATE demo Admin credentials and exact UUIDs; never publish");}
   db.setAutoCommit(false);try{try(var p=db.prepareStatement("INSERT INTO users(id,email,password_hash,role,status) VALUES(?,?,?,'ADMIN','ACTIVE')")){p.setObject(1,admin);p.setString(2,email);p.setString(3,new BCryptPasswordEncoder().encode(password));p.executeUpdate();}try(var p=db.prepareStatement("INSERT INTO membership_plans(id,name,duration_days,price,status) VALUES(?,'Member activation demo plan',30,100000,'ACTIVE')")){p.setObject(1,plan);p.executeUpdate();}db.commit();f.setProperty("seeded","true");try(var out=Files.newOutputStream(file)){f.store(out,"PRIVATE demo Admin credentials and exact UUIDs; never publish");}System.out.println("Seeded only synthetic Admin and plan; no Member or Membership seeded.");}catch(Exception e){db.rollback();throw e;}
  }
 }
}
