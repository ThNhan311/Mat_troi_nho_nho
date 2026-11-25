package vn.edu.tdtu.fitcenter.http;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.dao.DataIntegrityViolationException;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
@EnabledIfEnvironmentVariable(named="RUN_ACCOUNT_POSTGRES_TESTS",matches="true")
class MemberActivationSchemaPostgresTest {
 @BeforeAll static void prepare(){AccountIntegrationDatabase.prepare();}
 @Test void migrationEmptyAndOldPtCounterDataPreserved(){
  var j=new JdbcTemplate(AccountIntegrationDatabase.history);assertTrue(AccountIntegrationDatabase.before.equals(AccountIntegrationDatabase.snapshot(j)));assertEquals("1,2,3,4,5,6,8,9,10",j.queryForObject("SELECT string_agg(version,',' ORDER BY installed_rank) FROM flyway_schema_history",String.class));
  assertEquals(1,j.queryForObject("SELECT count(*) FROM pt_account_activation",Integer.class));assertEquals(1,j.queryForObject("SELECT count(*) FROM membership_initial_activations",Integer.class));
  var empty=new JdbcTemplate(AccountIntegrationDatabase.empty);assertEquals(0,empty.queryForObject("SELECT count(*) FROM users",Integer.class));assertEquals(0,empty.queryForObject("SELECT count(*) FROM member_account_activation",Integer.class));
 }
 @Test void ptCannotBeStoredAsMemberChallenge(){var j=new JdbcTemplate(AccountIntegrationDatabase.history);assertThrows(DataIntegrityViolationException.class,()->j.update("INSERT INTO member_account_activation(user_id,send_window_started_at,send_count,last_sent_at) VALUES(?,now(),1,now())",AccountIntegrationDatabase.fixture.ptB.userId));}
 @Test void countersAndPhaseConstraintsRemainEnforced(){var ds=AccountIntegrationDatabase.history;var j=new JdbcTemplate(ds);for(String values:List.of("'MEMBER',6,NULL,NULL,NULL,NULL","'PT',0,NULL,NULL,NULL,NULL","'MEMBER',0,'digest',NULL,NULL,NULL","'MEMBER',0,'digest',now(),'"+"a".repeat(64)+"',now()")){var tx=new TransactionTemplate(new DataSourceTransactionManager(ds));assertThrows(DataIntegrityViolationException.class,()->tx.executeWithoutResult(s->j.update("INSERT INTO member_account_activation(user_id,user_role,attempts,otp_digest,otp_expires_at,grant_digest,grant_expires_at,send_window_started_at,send_count,last_sent_at) VALUES(?,"+values+",now(),1,now())",AccountIntegrationDatabase.fixture.memberA.userId)));}}
 @Test void memberGrantUniqueAndFailedInsertRollsBack(){var ds=AccountIntegrationDatabase.history;var j=new JdbcTemplate(ds);var tx=new TransactionTemplate(new DataSourceTransactionManager(ds));assertThrows(DataIntegrityViolationException.class,()->tx.executeWithoutResult(s->{for(var a:List.of(AccountIntegrationDatabase.fixture.memberA,AccountIntegrationDatabase.fixture.memberB))j.update("INSERT INTO member_account_activation(user_id,send_window_started_at,send_count,last_sent_at,grant_digest,grant_expires_at) VALUES(?,now(),1,now(),?,now())",a.userId,"c".repeat(64));}));assertEquals(0,j.queryForObject("SELECT count(*) FROM member_account_activation",Integer.class));}
 @Test void rerunValidateDoesNotMigrateAgain(){var f=AccountIntegrationDatabase.flyway(AccountIntegrationDatabase.history,true);f.validate();assertEquals(0,f.migrate().migrationsExecuted);}
}
