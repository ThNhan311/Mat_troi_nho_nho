package vn.edu.tdtu.fitcenter.http;

import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.dao.DataIntegrityViolationException;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.FlywayException;
import vn.edu.tdtu.fitcenter.activation.ActivationRehearsalConfiguration;
import java.nio.file.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

@EnabledIfEnvironmentVariable(named="RUN_ACTIVATION_POSTGRES_TESTS",matches="true")
class ActivationSchemaRehearsalTest {
    @BeforeAll static void setup(){ActivationRehearsalDatabase.prepare();}
    @Test void emptyDatabaseMigrateOneToSixThenEight(){
        var j=new JdbcTemplate(ActivationRehearsalDatabase.empty);
        assertEquals("1,2,3,4,5,6,8",j.queryForObject("SELECT string_agg(version,',' ORDER BY installed_rank) FROM flyway_schema_history WHERE success",String.class));
        assertEquals(0,j.queryForObject("SELECT count(*) FROM users",Integer.class));assertEquals(0,j.queryForObject("SELECT count(*) FROM pt_account_activation",Integer.class));
        assertEquals(11,j.queryForObject("SELECT count(*) FROM information_schema.columns WHERE table_name='pt_account_activation' AND table_schema='public'",Integer.class));
    }
    @Test void v1ToSixHistoryAndPaymentPeriodsPreserved(){
        var j=new JdbcTemplate(ActivationRehearsalDatabase.history);
        assertTrue(ActivationRehearsalDatabase.before.equals(ActivationRehearsalDatabase.snapshot(j)),"All original rows unchanged");
        assertEquals(1,j.queryForObject("SELECT count(*) FROM payment_transactions WHERE id=? AND period_start=? AND period_end=? AND status='SUCCESS'",Integer.class,ActivationRehearsalDatabase.payment,ActivationRehearsalDatabase.fixture.today,ActivationRehearsalDatabase.fixture.expiry));
        assertEquals(0,j.queryForObject("SELECT count(*) FROM flyway_schema_history WHERE version='7'",Integer.class));
    }
    @Test void appliedMigrationValidatedAndRerunDoesNotMutate(){
        var f=ActivationRehearsalDatabase.flyway(ActivationRehearsalDatabase.history,true);f.validate();assertEquals(0,f.migrate().migrationsExecuted);
    }
    private void rejected(UUID id,String values){
        var ds=ActivationRehearsalDatabase.history;var j=new JdbcTemplate(ds);var tx=new TransactionTemplate(new DataSourceTransactionManager(ds));
        assertThrows(DataIntegrityViolationException.class,()->tx.executeWithoutResult(t->j.update("INSERT INTO pt_account_activation(user_id,user_role,otp_digest,otp_expires_at,attempts,send_window_started_at,send_count,last_sent_at,grant_digest,grant_expires_at,completed_at) VALUES('"+id+"',"+values+")")));
    }
    @Test void compositeFkRejectsMemberAsPt(){rejected(ActivationRehearsalDatabase.fixture.memberA.userId,"'PT',NULL,NULL,0,now(),1,now(),NULL,NULL,NULL");}
    @Test void roleCounterAndPhaseChecksRejectInvalidPtState(){
        UUID id=ActivationRehearsalDatabase.fixture.ptA.userId;
        for(String suffix:List.of("'MEMBER',NULL,NULL,0,now(),1,now(),NULL,NULL,NULL","'PT',NULL,NULL,6,now(),1,now(),NULL,NULL,NULL","'PT','hash',NULL,0,now(),1,now(),NULL,NULL,NULL","'PT','hash',now(),0,now(),1,now(),'"+"a".repeat(64)+"',now(),NULL","'PT',NULL,NULL,0,now(),0,now(),NULL,NULL,NULL","'PT',NULL,NULL,0,now(),1,now(),'"+"b".repeat(64)+"',now(),now()"))rejected(id,suffix);
    }
    @Test void grantDigestIsUniqueAndFailedTransactionLeavesNoRows(){
        var ds=ActivationRehearsalDatabase.history;var j=new JdbcTemplate(ds);var tx=new TransactionTemplate(new DataSourceTransactionManager(ds));
        String digest="c".repeat(64);assertThrows(DataIntegrityViolationException.class,()->tx.executeWithoutResult(t->{
            for(UUID id:List.of(ActivationRehearsalDatabase.fixture.ptA.userId,ActivationRehearsalDatabase.fixture.ptB.userId))j.update("INSERT INTO pt_account_activation(user_id,send_window_started_at,send_count,last_sent_at,grant_digest,grant_expires_at) VALUES(?,now(),1,now(),?,now())",id,digest);
        }));
        assertEquals(0,j.queryForObject("SELECT count(*) FROM pt_account_activation WHERE user_id IN (?,?)",Integer.class,ActivationRehearsalDatabase.fixture.ptA.userId,ActivationRehearsalDatabase.fixture.ptB.userId));
    }
    @Test void lateVersionSevenIsRejectedWithoutOutOfOrderOrHistoryEdits() throws Exception {
        Path dir=Files.createTempDirectory(Path.of(ActivationRehearsalDatabase.env("ACTIVATION_PRIVATE_DIRECTORY")),"late-v7-");
        // A harmless migration resolver probe proves ordering; it is never applied and is not Duy's membership SQL.
        Files.writeString(dir.resolve("V7__late_order_probe.sql"),"CREATE TABLE activation_order_probe(id integer);\n");
        var f=Flyway.configure().dataSource(ActivationRehearsalDatabase.history).locations("classpath:db/migration","classpath:db/activation-rehearsal","filesystem:"+dir).outOfOrder(false).cleanDisabled(true).load();
        assertThrows(FlywayException.class,f::migrate);
        var j=new JdbcTemplate(ActivationRehearsalDatabase.history);assertEquals(false,j.queryForObject("SELECT to_regclass('public.activation_order_probe') IS NOT NULL",Boolean.class));assertEquals(0,j.queryForObject("SELECT count(*) FROM flyway_schema_history WHERE version='7'",Integer.class));
        assertTrue(ActivationRehearsalDatabase.before.equals(ActivationRehearsalDatabase.snapshot(j)));
    }
    @Test void actualDuyV7ResolverIsPendingAndNeverExecuted() {
        Path dir=Path.of(ActivationRehearsalDatabase.env("ACTIVATION_PRIVATE_DIRECTORY"),"v7-reference");assertTrue(Files.isRegularFile(dir.resolve("V7__membership_periods.sql")));
        var f=Flyway.configure().dataSource(ActivationRehearsalDatabase.history).locations("classpath:db/migration","classpath:db/activation-rehearsal","filesystem:"+dir).outOfOrder(false).cleanDisabled(true).load();
        assertFalse(f.validateWithResult().validationSuccessful);
        var j=new JdbcTemplate(ActivationRehearsalDatabase.history);assertEquals(0,j.queryForObject("SELECT count(*) FROM flyway_schema_history WHERE version='7'",Integer.class));assertTrue(ActivationRehearsalDatabase.before.equals(ActivationRehearsalDatabase.snapshot(j)));
    }
    @Test void failedForwardMigrationRollsBackDdlAndHistory() throws Exception {
        Path dir=Files.createTempDirectory(Path.of(ActivationRehearsalDatabase.env("ACTIVATION_PRIVATE_DIRECTORY")),"failed-ddl-");
        Files.writeString(dir.resolve("V9999__transaction_failure_probe.sql"),"CREATE TABLE activation_rollback_probe(id integer); SELECT 1/0;\n");
        var f=Flyway.configure().dataSource(ActivationRehearsalDatabase.empty).locations("classpath:db/migration","classpath:db/activation-rehearsal","filesystem:"+dir).outOfOrder(false).cleanDisabled(true).load();assertThrows(FlywayException.class,f::migrate);
        var j=new JdbcTemplate(ActivationRehearsalDatabase.empty);assertEquals(false,j.queryForObject("SELECT to_regclass('public.activation_rollback_probe') IS NOT NULL",Boolean.class));assertEquals(0,j.queryForObject("SELECT count(*) FROM flyway_schema_history WHERE version='9999'",Integer.class));
    }
    @Test void datasourceGuardRejectsMissingRunnerVerificationBeforeConnection(){assertThrows(IllegalStateException.class,()->ActivationRehearsalConfiguration.verify(ActivationRehearsalDatabase.history,false));}
}
