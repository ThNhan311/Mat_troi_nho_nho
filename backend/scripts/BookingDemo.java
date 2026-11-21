import java.nio.file.*;
import java.nio.file.attribute.*;
import java.nio.charset.StandardCharsets;
import java.sql.*;
import java.time.*;
import java.util.*;
import java.security.SecureRandom;
import java.net.URI;
import java.net.http.*;
import java.util.regex.*;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/** Local demo CLI; never installed as an application endpoint. Credentials stay in the local manifest. */
public class BookingDemo {
  static final String[] ACTORS={"admin","memberA","memberB","ptA","ptB"};
  static final Properties manifest=new Properties();
  static Path file;
  static Connection db;
  static String id(String key){return manifest.getProperty(key);}
  static String random(){byte[] bytes=new byte[24];new SecureRandom().nextBytes(bytes);return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);}
  static void save() throws Exception {
    Path temp=Files.createTempFile(file.getParent(),"fixture-",".tmp");
    try(var out=Files.newOutputStream(temp)){manifest.store(out,"Private local synthetic fixture. Do not copy to Git or logs.");}
    Files.move(temp,file,StandardCopyOption.REPLACE_EXISTING,StandardCopyOption.ATOMIC_MOVE);
  }
  static void init() throws Exception {
    if(Files.exists(file)){try(var in=Files.newInputStream(file)){manifest.load(in);}return;}
    manifest.setProperty("fixture",UUID.randomUUID().toString());
    for(String a:ACTORS){
      manifest.setProperty(a+".userId",UUID.randomUUID().toString());
      manifest.setProperty(a+".profileId",UUID.randomUUID().toString());
      manifest.setProperty(a+".email","booking-demo-"+id(a+".userId")+"@example.invalid");
      manifest.setProperty(a+".password",random());
    }
    for(String key:List.of("plan","membershipA","membershipB"))manifest.setProperty(key,UUID.randomUUID().toString());
    save();
  }
  static Object uuid(String key){return UUID.fromString(id(key));}
  static int update(String sql,Object... args) throws Exception {
    try(var ps=db.prepareStatement(sql)){for(int i=0;i<args.length;i++)ps.setObject(i+1,args[i]);return ps.executeUpdate();}
  }
  static String scalar(String sql) throws Exception {try(var st=db.createStatement();var r=st.executeQuery(sql)){if(!r.next())throw new IllegalStateException("Missing verification row");return r.getString(1);}}
  static void guard() throws Exception {
    String url=System.getenv("DB_URL");
    if(!"jdbc:postgresql://127.0.0.1:15437/fitcenter_baseline_20261120_test".equals(url)
        || !"fitcenter_baseline_app".equals(System.getenv("DB_USERNAME")))throw new IllegalStateException("Unexpected demo datasource");
    db=DriverManager.getConnection(url,System.getenv("DB_USERNAME"),System.getenv("DB_PASSWORD"));
    if(!"fitcenter_baseline_20261120_test|fitcenter_baseline_app|false|1,2,3,4,5,6|true".equals(scalar("""
      SELECT current_database()||'|'||current_user||'|'||(rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)::text||'|'||
      (SELECT string_agg(version,',' ORDER BY installed_rank) FROM flyway_schema_history WHERE version IS NOT NULL)||'|'||
      (SELECT bool_and(success)::text FROM flyway_schema_history) FROM pg_roles WHERE rolname=current_user
      """)))throw new IllegalStateException("DB identity/privileges/history mismatch");
  }
  static void seed() throws Exception {
    if("true".equals(id("seeded"))){System.out.println("Fixture already seeded; no rows changed.");return;}
    if(!"0".equals(scalar("SELECT count(*) FROM booking_policy")))throw new IllegalStateException("Refusing to replace policy outside this fixture");
    db.setAutoCommit(false);
    try{
      var encoder=new BCryptPasswordEncoder();
      for(String a:ACTORS){
        String role=a.equals("admin")?"ADMIN":a.startsWith("member")?"MEMBER":"PT";
        update("INSERT INTO users(id,email,password_hash,role,status) VALUES(?,?,?,?,'ACTIVE')",uuid(a+".userId"),id(a+".email"),encoder.encode(id(a+".password")),role);
        if(role.equals("MEMBER"))update("INSERT INTO members(id,user_id,full_name) VALUES(?,?,?)",uuid(a+".profileId"),uuid(a+".userId"),"Demo "+a);
        if(role.equals("PT"))update("INSERT INTO personal_trainers(id,user_id,full_name,bio,specialization,experience_summary) VALUES(?,?,?,?,?,?)",
          uuid(a+".profileId"),uuid(a+".userId"),"Demo "+a,"Synthetic demo profile","Core 90 minutes","Fixture, not a real trainer");
      }
      update("INSERT INTO membership_plans(id,name,description,duration_days,price,status) VALUES(?,?,?,30,0,'ACTIVE')",uuid("plan"),"Booking demo "+id("fixture"),"Synthetic fixture only");
      LocalDate day=LocalDate.now(ZoneId.of("Asia/Ho_Chi_Minh"));
      for(String a:List.of("memberA","memberB"))update("INSERT INTO memberships(id,member_id,plan_id,start_date,expiry_date,status) VALUES(?,?,?,?,?,'ACTIVE')",
        uuid(a.equals("memberA")?"membershipA":"membershipB"),uuid(a+".profileId"),uuid("plan"),day,day.plusDays(30));
      db.commit();manifest.setProperty("seeded","true");save();
      System.out.println("Synthetic actors/plan/memberships seeded. Credentials only in the private local manifest.");
    }catch(Exception error){db.rollback();throw error;}finally{db.setAutoCommit(true);}
  }
  static String field(String json,String key){
    var matcher=Pattern.compile("\""+key+"\"\\s*:\\s*\"([^\"]+)\"").matcher(json);
    if(!matcher.find())throw new IllegalStateException("Expected HTTP response field missing");
    return matcher.group(1);
  }
  static void policy(String base) throws Exception {
    if(!base.matches("http://127\\.0\\.0\\.1:[0-9]+/api/v1"))throw new IllegalStateException("Only verified loopback demo server allowed");
    // A stale manifest is not authority to overwrite another fixture policy.
    try(var ps=db.prepareStatement("SELECT id,updated_by FROM booking_policy");var rs=ps.executeQuery()){
      while(rs.next())if(!rs.getString(1).equals(id("policy"))||!Objects.equals(rs.getString(2),id("admin.userId")))
        throw new IllegalStateException("Policy outside fixture ownership");
    }
    var client=HttpClient.newHttpClient();
    var login=client.send(HttpRequest.newBuilder(URI.create(base+"/auth/login")).header("Content-Type","application/json")
      .POST(HttpRequest.BodyPublishers.ofString("{\"email\":\""+id("admin.email")+"\",\"password\":\""+id("admin.password")+"\"}")).build(),HttpResponse.BodyHandlers.ofString());
    if(login.statusCode()!=200)throw new IllegalStateException("Admin demo login failed: HTTP "+login.statusCode());
    String token=field(login.body(),"accessToken");
    var response=client.send(HttpRequest.newBuilder(URI.create(base+"/admin/booking-policy")).header("Content-Type","application/json")
      .header("Authorization","Bearer "+token).PUT(HttpRequest.BodyPublishers.ofString("{\"maxAdvanceDays\":14,\"minNoticeHours\":2,\"cancelDeadlineHours\":4,\"maxFutureBookings\":5}")).build(),HttpResponse.BodyHandlers.ofString());
    if(response.statusCode()!=200)throw new IllegalStateException("Explicit Admin PUT failed: HTTP "+response.statusCode());
    manifest.setProperty("policy",UUID.fromString(field(response.body(),"id")).toString());save();
    System.out.println("Policy configured explicitly through Admin PUT; fixture policy UUID registered.");
  }
  static Set<String> registry(String kind){
    String raw=manifest.getProperty(kind,"");return new LinkedHashSet<>(raw.isEmpty()?List.of():Arrays.asList(raw.split(",")));
  }
  static void rotate() throws Exception {
    db.setAutoCommit(false);
    try {
      var encoder=new BCryptPasswordEncoder();
      for(String actor:ACTORS) {
        String password=random();
        if(update("UPDATE users SET password_hash=? WHERE id=? AND email=?",encoder.encode(password),uuid(actor+".userId"),id(actor+".email"))!=1)
          throw new IllegalStateException("Fixture actor missing");
        manifest.setProperty(actor+".password",password);
      }
      db.commit();save();
      System.out.println("Fixture credentials regenerated privately; no password/token output.");
    } catch(Exception error){db.rollback();throw error;} finally{db.setAutoCommit(true);}
  }
  static void capture() throws Exception {
    var slots=registry("slots");var bookings=registry("bookings");
    try(var ps=db.prepareStatement("SELECT id FROM availability_slots WHERE pt_id IN (?,?)")){
      ps.setObject(1,uuid("ptA.profileId"));ps.setObject(2,uuid("ptB.profileId"));
      try(var rs=ps.executeQuery()){while(rs.next())slots.add(rs.getString(1));}
    }
    try(var ps=db.prepareStatement("SELECT id,member_id,pt_id,slot_id FROM bookings WHERE pt_id IN (?,?)")){
      ps.setObject(1,uuid("ptA.profileId"));ps.setObject(2,uuid("ptB.profileId"));
      try(var rs=ps.executeQuery()){while(rs.next()){
        if(!Set.of(id("memberA.profileId"),id("memberB.profileId")).contains(rs.getString(2))||!slots.contains(rs.getString(4)))
          throw new IllegalStateException("Booking outside fixture ownership; cleanup must stop");
        bookings.add(rs.getString(1));
      }}
    }
    manifest.setProperty("slots",String.join(",",slots));manifest.setProperty("bookings",String.join(",",bookings));save();
    System.out.println("Registered exact fixture UUIDs: slots="+slots.size()+", bookings="+bookings.size());
  }
  static void audit() throws Exception {
    capture();
    try(var ps=db.prepareStatement("""
       SELECT b.id,b.member_id,b.pt_id,b.slot_id,b.start_at,b.end_at,b.status,s.status,
         (b.pt_id=s.pt_id AND b.start_at=s.start_at AND b.end_at=s.end_at)
       FROM bookings b JOIN availability_slots s ON s.id=b.slot_id WHERE b.pt_id IN (?,?) ORDER BY b.id
       """)){
      ps.setObject(1,uuid("ptA.profileId"));ps.setObject(2,uuid("ptB.profileId"));
      try(var r=ps.executeQuery()){while(r.next())System.out.println("DB booking="+r.getString(1)+" member="+r.getString(2)+" pt="+r.getString(3)+" slot="+r.getString(4)+
        " start="+r.getObject(5,OffsetDateTime.class).toInstant()+" end="+r.getObject(6,OffsetDateTime.class).toInstant()+" bookingStatus="+r.getString(7)+" slotStatus="+r.getString(8)+" timesMatch="+r.getBoolean(9));}
    }
  }
  static void cleanup() throws Exception {
    capture();db.setAutoCommit(false);
    try{
      // Revalidate stored IDs as well as freshly captured IDs inside the cleanup transaction.
      for(String value:registry("slots"))try(var ps=db.prepareStatement("SELECT pt_id FROM availability_slots WHERE id=? FOR UPDATE")){
        ps.setObject(1,UUID.fromString(value));try(var rs=ps.executeQuery()){
          if(rs.next()&&!Set.of(id("ptA.profileId"),id("ptB.profileId")).contains(rs.getString(1)))
            throw new IllegalStateException("Registered slot outside fixture ownership");
        }
      }
      for(String value:registry("bookings"))try(var ps=db.prepareStatement("SELECT member_id,pt_id,slot_id FROM bookings WHERE id=? FOR UPDATE")){
        ps.setObject(1,UUID.fromString(value));try(var rs=ps.executeQuery()){
          if(rs.next()&&(!Set.of(id("memberA.profileId"),id("memberB.profileId")).contains(rs.getString(1))
            ||!Set.of(id("ptA.profileId"),id("ptB.profileId")).contains(rs.getString(2))||!registry("slots").contains(rs.getString(3))))
            throw new IllegalStateException("Registered booking outside fixture ownership");
        }
      }
      for(String value:registry("bookings"))update("DELETE FROM bookings WHERE id=? AND member_id IN (?,?) AND pt_id IN (?,?)",UUID.fromString(value),uuid("memberA.profileId"),uuid("memberB.profileId"),uuid("ptA.profileId"),uuid("ptB.profileId"));
      for(String value:registry("slots"))update("DELETE FROM availability_slots WHERE id=? AND pt_id IN (?,?)",UUID.fromString(value),uuid("ptA.profileId"),uuid("ptB.profileId"));
      if(id("policy")!=null)update("DELETE FROM booking_policy WHERE id=? AND updated_by=?",uuid("policy"),uuid("admin.userId"));
      for(String a:List.of("memberA","memberB"))update("DELETE FROM memberships WHERE id=? AND member_id=?",uuid(a.equals("memberA")?"membershipA":"membershipB"),uuid(a+".profileId"));
      for(String a:List.of("memberA","memberB"))update("DELETE FROM members WHERE id=? AND user_id=?",uuid(a+".profileId"),uuid(a+".userId"));
      for(String a:List.of("ptA","ptB"))update("DELETE FROM personal_trainers WHERE id=? AND user_id=?",uuid(a+".profileId"),uuid(a+".userId"));
      for(String a:ACTORS)update("DELETE FROM users WHERE id=? AND email=?",uuid(a+".userId"),id(a+".email"));
      update("DELETE FROM membership_plans WHERE id=?",uuid("plan"));
      db.commit();manifest.setProperty("seeded","false");manifest.setProperty("slots","");manifest.setProperty("bookings","");manifest.remove("policy");save();
      System.out.println("Exact-UUID cleanup committed; volume and all non-fixture rows preserved.");
    }catch(Exception error){db.rollback();throw error;}finally{db.setAutoCommit(true);}
  }
  public static void main(String[] args) throws Exception {
    if(args.length<2)throw new IllegalArgumentException("Action and private manifest path required");
    file=Path.of(args[1]).toAbsolutePath().normalize();
    Path repo=Path.of("").toAbsolutePath().normalize();
    Path temp=Path.of(System.getenv("LOCALAPPDATA"),"Temp").toAbsolutePath().normalize();
    if(!file.startsWith(temp)||file.startsWith(repo)||!Files.isDirectory(file.getParent()))throw new IllegalArgumentException("Manifest must be in an existing private Temp folder outside repository");
    init();
    try{
      guard();
      switch(args[0]){case "seed"->seed();case "policy"->policy(args[2]);case "rotate"->rotate();case "capture"->capture();case "audit"->audit();case "cleanup"->cleanup();default->throw new IllegalArgumentException("Unknown action");}
    }catch(Exception error){
      // JDBC exceptions can contain parameters; do not echo secrets, SQL or stack traces.
      String diagnostic = error instanceof SQLException sql ? ", SQLSTATE="+sql.getSQLState() : "";
      if(error instanceof org.postgresql.util.PSQLException pg && pg.getServerErrorMessage()!=null)
        diagnostic += ", constraint="+pg.getServerErrorMessage().getConstraint();
      System.err.println("Demo action failed ("+error.getClass().getSimpleName()+diagnostic+"). No credential/SQL dump emitted.");
      System.exit(1);
    }finally{if(db!=null)db.close();}
  }
}
