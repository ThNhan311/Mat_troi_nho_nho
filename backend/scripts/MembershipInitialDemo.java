import java.nio.file.*;
import java.sql.*;
import java.util.*;
import java.security.SecureRandom;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
/** Synthetic M-03 demo only. Local manifest before SQL; no credentials printed. */
public class MembershipInitialDemo {
 static Properties f=new Properties();static Path file;static Connection db;
 static String get(String k){return f.getProperty(k);}static UUID id(String k){return UUID.fromString(get(k));}
 static String secret(){byte[] b=new byte[24];new SecureRandom().nextBytes(b);return Base64.getUrlEncoder().withoutPadding().encodeToString(b);}
 static void save()throws Exception{Path tmp=Files.createTempFile(file.getParent(),"m03-manifest-",".tmp");try(var out=Files.newOutputStream(tmp)){f.store(out,"Private synthetic M03 fixture and cleanup authority; never publish");}Files.move(tmp,file,StandardCopyOption.REPLACE_EXISTING,StandardCopyOption.ATOMIC_MOVE);}
 static void execute(String sql,Object...args)throws Exception{try(var p=db.prepareStatement(sql)){for(int i=0;i<args.length;i++)p.setObject(i+1,args[i]);p.executeUpdate();}}
 static List<UUID> ids(String sql,Object...args)throws Exception{try(var p=db.prepareStatement(sql)){for(int i=0;i<args.length;i++)p.setObject(i+1,args[i]);try(var rs=p.executeQuery()){List<UUID> out=new ArrayList<>();while(rs.next())out.add(rs.getObject(1,UUID.class));return out;}}}
 public static void main(String[] args)throws Exception{
  file=Path.of(args[1]).toAbsolutePath().normalize();if(!file.startsWith(Path.of(System.getenv("LOCALAPPDATA"),"Temp").toAbsolutePath().normalize()))throw new IllegalArgumentException("Private Temp manifest required");
  if(Files.exists(file))try(var in=Files.newInputStream(file)){f.load(in);}
  var url=java.net.URI.create(System.getenv("DB_URL").substring(5));if(!url.getHost().equals("127.0.0.1")||url.getPort()!=15440||!url.getPath().matches("/fitcenter_membership_[a-f0-9]{12}_history_test"))throw new IllegalStateException("Wrong test target");
  try(var connection=DriverManager.getConnection(System.getenv("DB_URL"),System.getenv("DB_USERNAME"),System.getenv("DB_PASSWORD"))){db=connection;
   try(var s=db.createStatement();var q=s.executeQuery("SELECT current_user,(rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls),(SELECT string_agg(version,',' ORDER BY installed_rank) FROM flyway_schema_history WHERE success) FROM pg_roles WHERE rolname=current_user")){if(!q.next()||!q.getString(1).equals("fitcenter_membership_app")||q.getBoolean(2)||!q.getString(3).equals("1,2,3,4,5,6,9"))throw new IllegalStateException("DB identity/history mismatch");}
   if(args[0].equals("seed")){
    if("true".equals(get("seeded")))throw new IllegalStateException("Demo already seeded; do not overwrite");
    if(Files.exists(file))throw new IllegalStateException("Use a new fixture manifest");
    var base=new Properties();try(var in=Files.newInputStream(Path.of(args[2]))){base.load(in);}for(String k:List.of("admin.email","admin.password","admin.userId"))f.setProperty(k,base.getProperty(k));
    for(String a:List.of("memberActive","memberDisabled")){f.setProperty(a+".userId",UUID.randomUUID().toString());f.setProperty(a+".profileId",UUID.randomUUID().toString());f.setProperty(a+".email","m03-ui-"+get(a+".userId")+"@example.invalid");f.setProperty(a+".password",secret());}
    f.setProperty("plan",UUID.randomUUID().toString());f.setProperty("receipt","DEMO-M03-"+UUID.randomUUID());save();db.setAutoCommit(false);
    try{var encoder=new BCryptPasswordEncoder();execute("INSERT INTO membership_plans(id,name,duration_days,price,status) VALUES(?,'M03 UI zero plan',30,0,'ACTIVE')",id("plan"));
     for(String a:List.of("memberActive","memberDisabled")){String status=a.equals("memberActive")?"ACTIVE":"DISABLED";execute("INSERT INTO users(id,email,password_hash,role,status) VALUES(?,?,?,'MEMBER',?)",id(a+".userId"),get(a+".email"),encoder.encode(get(a+".password")),status);execute("INSERT INTO members(id,user_id,full_name) VALUES(?,?,?)",id(a+".profileId"),id(a+".userId"),"M03 UI "+status);}
     db.commit();f.setProperty("seeded","true");save();System.out.println("Seeded synthetic ACTIVE/DISABLED demo Members and zero-price plan; no Member activation workflow executed.");
    }catch(Exception e){db.rollback();throw e;}
   }else if(args[0].equals("cleanup")){
    if(!"true".equals(get("seeded"))){System.out.println("Demo already cleaned; no mutations.");return;}
    db.setAutoCommit(false);try{
     for(String a:List.of("memberActive","memberDisabled"))for(UUID ms:ids("SELECT id FROM memberships WHERE member_id=?",id(a+".profileId"))){
      f.setProperty("membership."+ms,id(a+".profileId").toString());save();
      for(UUID audit:ids("SELECT id FROM audit_logs WHERE entity_type='MEMBERSHIP' AND entity_id=? AND action='MEMBERSHIP_INITIAL_ACTIVATED'",ms))execute("DELETE FROM audit_logs WHERE id=?",audit);
      for(UUID receipt:ids("SELECT id FROM membership_initial_activations WHERE membership_id=? AND member_id=?",ms,id(a+".profileId")))execute("DELETE FROM membership_initial_activations WHERE id=? AND membership_id=?",receipt,ms);
      for(UUID pay:ids("SELECT id FROM payment_transactions WHERE membership_id=? AND member_id=? AND provider='COUNTER'",ms,id(a+".profileId")))execute("DELETE FROM payment_transactions WHERE id=? AND membership_id=?",pay,ms);
      execute("DELETE FROM memberships WHERE id=? AND member_id=?",ms,id(a+".profileId"));
     }
     for(String a:List.of("memberActive","memberDisabled")){execute("DELETE FROM members WHERE id=? AND user_id=?",id(a+".profileId"),id(a+".userId"));execute("DELETE FROM users WHERE id=? AND email=?",id(a+".userId"),get(a+".email"));}
     execute("DELETE FROM membership_plans WHERE id=? AND name='M03 UI zero plan'",id("plan"));db.commit();f.setProperty("seeded","false");save();System.out.println("Cleaned exact M03 demo UUIDs; other rows retained.");
    }catch(Exception e){db.rollback();throw e;}
   }else throw new IllegalArgumentException("seed or cleanup");
  }
 }
}
