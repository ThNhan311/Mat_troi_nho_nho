import java.nio.file.*;
import java.sql.*;
import java.util.*;
import java.security.SecureRandom;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.postgresql.ds.PGSimpleDataSource;
import org.flywaydb.core.Flyway;
import tools.jackson.databind.ObjectMapper;
import vn.edu.tdtu.fitcenter.activation.AccountIntegrationRehearsalConfiguration;

/** Synthetic F01 identities only. No camera, enrollment, embeddings, or real person. */
public class EnrollmentDemo {
    static String secret(){byte[] value=new byte[32];new SecureRandom().nextBytes(value);return Base64.getUrlEncoder().withoutPadding().encodeToString(value);}
    public static void main(String[] args)throws Exception {
        Path dir=Path.of(args[0]).toRealPath(),temp=Path.of(System.getenv("LOCALAPPDATA"),"Temp").toRealPath();
        if(!dir.startsWith(temp)||!args[1].matches("[a-f0-9]{12}"))throw new IllegalArgumentException("Private guarded run required");
        Path file=dir.resolve("demo-fixture.properties"),config=dir.resolve("checkin-demo-config.json");
        if(Files.exists(file)||Files.exists(config))throw new IllegalStateException("Never overwrite fixture authority");
        PGSimpleDataSource history=null;
        for(String kind:List.of("empty","history")) {
            var ds=new PGSimpleDataSource();ds.setURL("jdbc:postgresql://127.0.0.1:15441/fitcenter_account_"+args[1]+"_"+kind+"_test");ds.setUser("fitcenter_account_app");ds.setPassword(System.getenv("DB_PASSWORD"));AccountIntegrationRehearsalConfiguration.verify(ds,true);
            try(var c=ds.getConnection();var s=c.createStatement();var r=s.executeQuery("SELECT count(*) FROM pg_tables WHERE schemaname='public'")){r.next();if(r.getInt(1)!=0)throw new IllegalStateException("Fresh DBs required; no clean/reset");}
            Flyway.configure().dataSource(ds).locations("classpath:db/migration","classpath:db/activation-rehearsal","classpath:db/membership-rehearsal","classpath:db/member-activation-rehearsal","classpath:db/renewal-rehearsal","classpath:db/checkin-rehearsal","classpath:db/enrollment-rehearsal").outOfOrder(false).cleanDisabled(true).load().migrate();
            if(kind.equals("history"))history=ds;
        }
        var f=new Properties();f.setProperty("nonce",args[1]);f.setProperty("historyDatabase",history.getDatabaseName());f.setProperty("seeded","false");f.setProperty("identityMode","SIMULATED_TEST");
        var users=new ArrayList<String>();var members=new ArrayList<String>();var profiles=new ArrayList<String>();var captures=new ArrayList<Map<String,Object>>();
        for(String actor:List.of("admin","memberA","memberB")) {
            UUID user=UUID.randomUUID();users.add(user.toString());f.setProperty(actor+".userId",user.toString());f.setProperty(actor+".password",secret());f.setProperty(actor+".email","f01-"+actor.toLowerCase()+"-"+user+"@example.invalid");
            if(!actor.equals("admin")){UUID member=UUID.randomUUID(),profile=UUID.randomUUID(),capture=UUID.randomUUID();members.add(member.toString());profiles.add(profile.toString());f.setProperty(actor+".memberId",member.toString());f.setProperty(actor+".facialProfileId",profile.toString());f.setProperty(actor+".captureRef",capture.toString());captures.add(Map.of("captureRef",capture,"outcome","MATCHED","facialProfileId",profile));}
        }
        UUID noMatch=UUID.randomUUID();f.setProperty("noMatch.captureRef",noMatch.toString());captures.add(Map.of("captureRef",noMatch,"outcome","NO_MATCH"));
        f.setProperty("table.users",String.join(",",users));f.setProperty("table.members",String.join(",",members));f.setProperty("table.facial_profiles",String.join(",",profiles));
        try(var o=Files.newOutputStream(file,StandardOpenOption.CREATE_NEW)){f.store(o,"PRIVATE F01 synthetic fixtures; no real biometric enrollment");}
        Files.writeString(config,new ObjectMapper().writeValueAsString(Map.of("mode","SIMULATED_TEST","kiosks",List.of(Map.of("id","test-kiosk-a","token",secret()),Map.of("id","test-kiosk-b","token",secret())),"captures",captures)),StandardOpenOption.CREATE_NEW);
        Files.writeString(dir.resolve("enrollment-demo-config.json"),"{\"mode\":\"SIMULATED_TEST\",\"outcomes\":{}}",StandardOpenOption.CREATE_NEW);
        try(var db=history.getConnection()) {
            db.setAutoCommit(false);
            try {
                for(String actor:List.of("admin","memberA","memberB")) {
                    UUID user=UUID.fromString(f.getProperty(actor+".userId"));
                    try(var p=db.prepareStatement("INSERT INTO users(id,email,password_hash,role,status) VALUES(?,?,?,?,'ACTIVE')")){p.setObject(1,user);p.setString(2,f.getProperty(actor+".email"));p.setString(3,new BCryptPasswordEncoder().encode(f.getProperty(actor+".password")));p.setString(4,actor.equals("admin")?"ADMIN":"MEMBER");p.executeUpdate();}
                    if(!actor.equals("admin")) {
                        UUID member=UUID.fromString(f.getProperty(actor+".memberId")),profile=UUID.fromString(f.getProperty(actor+".facialProfileId"));
                        try(var p=db.prepareStatement("INSERT INTO members(id,user_id,full_name) VALUES(?,?,'Synthetic F01 fixture Member')")){p.setObject(1,member);p.setObject(2,user);p.executeUpdate();}

                    }
                }
                db.commit();
            }catch(Exception ex){db.rollback();throw ex;}
        }
        f.setProperty("seeded","true");try(var o=Files.newOutputStream(file)){f.store(o,"PRIVATE F01 ACTIVE account/profile fixtures; not proof of activation or Face enrollment");}
        System.out.println("F01 fresh pair migrated; synthetic Admin/ACTIVE Members seeded; no FacialProfile until enrollment API. No biometric data or Membership/payment seeded.");
    }
}
