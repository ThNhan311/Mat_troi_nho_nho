package vn.edu.tdtu.fitcenter.http;

import org.flywaydb.core.Flyway;
import org.postgresql.ds.PGSimpleDataSource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.transaction.support.TransactionTemplate;
import vn.edu.tdtu.fitcenter.activation.ActivationRehearsalConfiguration;
import java.nio.file.*;
import java.security.MessageDigest;
import java.util.*;

/** Fresh DBs are created by the guarded runner, never cleaned/repaired by Flyway. */
final class ActivationRehearsalDatabase {
    static PGSimpleDataSource empty,history;
    static HttpBaselineFixture fixture;
    static Map<String,List<String>> before;
    static UUID payment;
    static String nonce;
    private static boolean prepared;
    static String env(String n){String v=System.getenv(n);if(v==null||v.isBlank())throw new IllegalStateException("Missing rehearsal setting "+n);return v;}
    static PGSimpleDataSource source(String url){
        var d=new PGSimpleDataSource();d.setURL(url);d.setUser("fitcenter_activation_app");d.setPassword(env("ACTIVATION_DB_PASSWORD"));
        ActivationRehearsalConfiguration.verify(d,"true".equals(env("ACTIVATION_REHEARSAL_GUARD_VERIFIED")));return d;
    }
    static Flyway flyway(PGSimpleDataSource d, boolean activation){
        return Flyway.configure().dataSource(d).locations(activation?new String[]{"classpath:db/migration","classpath:db/activation-rehearsal"}:new String[]{"classpath:db/migration"}).outOfOrder(false).cleanDisabled(true).load();
    }
    static Map<String,List<String>> snapshot(JdbcTemplate j){
        var out=new TreeMap<String,List<String>>();
        for(String t:j.queryForList("SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename NOT IN ('flyway_schema_history','pt_account_activation') ORDER BY tablename",String.class)){
            if(!t.matches("[a-z_]+"))throw new IllegalStateException("Unexpected table");
            out.put(t,j.queryForList("SELECT to_jsonb(t)::text FROM "+t+" t ORDER BY id",String.class));
        }
        return out;
    }
    static synchronized void prepare(){
        if(prepared)return;
        if(Runtime.version().feature()!=21||!"true".equals(env("RUN_ACTIVATION_POSTGRES_TESTS")))throw new IllegalStateException("Guarded JDK21 run required");
        empty=source(env("ACTIVATION_EMPTY_DB_URL"));history=source(env("ACTIVATION_HISTORY_DB_URL"));
        nonce=env("ACTIVATION_HISTORY_DB_URL").replaceFirst(".*/fitcenter_activation_","").replace("_history_test","");
        for(var d:List.of(empty,history)){
            var j=new JdbcTemplate(d);
            if(j.queryForObject("SELECT count(*) FROM pg_tables WHERE schemaname='public'",Integer.class)!=0)throw new IllegalStateException("Each rehearsal needs two fresh empty DBs; do not clean existing data");
            flyway(d,false).migrate();
        }
        var j=new JdbcTemplate(history);fixture=new HttpBaselineFixture(j,new TransactionTemplate(new DataSourceTransactionManager(history)));fixture.seed(new BCryptPasswordEncoder());
        payment=UUID.randomUUID();j.update("INSERT INTO payment_transactions(id,member_id,plan_id,membership_id,provider_ref,amount,status,processed_at,period_start,period_end) VALUES(?,?,?,?,?,100000.00,'SUCCESS',now(),?,?)",payment,fixture.memberA.profileId,fixture.planId,fixture.membershipA,"activation-preserve-"+payment,fixture.today,fixture.expiry);
        before=snapshot(j);
        for(var d:List.of(empty,history))flyway(d,true).migrate();
        if(!before.equals(snapshot(j)))throw new IllegalStateException("Migration changed pre-existing data");
        saveRegistry();prepared=true;
    }
    static void saveRegistry(){
        try{
            Path dir=Path.of(env("ACTIVATION_PRIVATE_DIRECTORY")).toAbsolutePath().normalize();
            if(!dir.startsWith(Path.of(System.getenv("LOCALAPPDATA"),"Temp").toAbsolutePath().normalize()))throw new IllegalStateException("Private Temp registry required");
            var p=new Properties();p.setProperty("nonce",nonce);p.setProperty("historyDatabase",history.getDatabaseName());
            for(var a:fixture.actors){p.setProperty(a.label+".email",a.email);p.setProperty(a.label+".password",a.password);p.setProperty(a.label+".userId",a.userId.toString());p.setProperty(a.label+".profileId",a.profileId.toString());}
            p.setProperty("table.users",String.join(",",fixture.actors.stream().map(a->a.userId.toString()).toList()));
            p.setProperty("table.members",fixture.memberA.profileId+","+fixture.memberB.profileId);
            p.setProperty("table.personal_trainers",fixture.ptA.profileId+","+fixture.ptB.profileId);
            p.setProperty("table.membership_plans",fixture.planId+","+fixture.inactivePlanId);
            p.setProperty("table.memberships",fixture.membershipA+","+fixture.membershipB);
            p.setProperty("table.payment_transactions",payment.toString());
            p.setProperty("table.availability_slots",String.join(",",fixture.slots.stream().map(s->s.id().toString()).toList()));
            p.setProperty("table.bookings",String.join(",",fixture.bookings.stream().map(b->b.id().toString()).toList()));
            try(var out=Files.newOutputStream(dir.resolve("run-"+nonce+"-fixture.properties"),StandardOpenOption.CREATE_NEW)){p.store(out,"Private synthetic fixture credentials and exact UUID cleanup registry; never publish");}
        }catch(java.io.IOException e){throw new IllegalStateException("Cannot persist private fixture registry");}
    }
    static String dataHash(){try{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(before.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8)));}catch(Exception e){throw new IllegalStateException(e);}}
}
