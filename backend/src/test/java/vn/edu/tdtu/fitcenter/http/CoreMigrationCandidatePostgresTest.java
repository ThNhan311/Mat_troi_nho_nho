package vn.edu.tdtu.fitcenter.http;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.flywaydb.core.Flyway;
import org.springframework.jdbc.core.JdbcTemplate;
import java.nio.file.*;import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
/** I-01: actual fresh and historical PostgreSQL upgrades; never executes the quarantined V7. */
@EnabledIfEnvironmentVariable(named="RUN_ACCOUNT_POSTGRES_TESTS",matches="true")
class CoreMigrationCandidatePostgresTest {
 @BeforeAll static void prepare(){AccountIntegrationDatabase.prepare();}
 @Test void actualHistoryChecksumsMatchFrozenCandidate()throws Exception{
  var json=new tools.jackson.databind.ObjectMapper();
  var manifest=json.readTree(Files.readString(Path.of("../database/core-integration-candidate.json")));
  for(var ds:List.of(AccountIntegrationDatabase.empty,AccountIntegrationDatabase.history)){
   var j=new JdbcTemplate(ds);assertEquals(9,j.queryForObject("SELECT count(*) FROM flyway_schema_history",Integer.class));
   for(var entry:manifest.get("entries"))assertEquals(entry.get("flywayChecksum").asInt(),j.queryForObject("SELECT checksum FROM flyway_schema_history WHERE version=? AND success",Integer.class,entry.get("version").asText()));
  }
 }
 @Test void v1to6HistorySurvivedV8V9AndThenV10(){
  var j=new JdbcTemplate(AccountIntegrationDatabase.history);
  assertEquals(6,AccountIntegrationDatabase.payments.size());
  for(var id:AccountIntegrationDatabase.payments)assertEquals(1,j.queryForObject("SELECT count(*) FROM payment_transactions WHERE id=?",Integer.class,id));
  assertTrue(AccountIntegrationDatabase.beforeAdditive.entrySet().stream().allMatch(e->e.getValue().equals(AccountIntegrationDatabase.snapshot(j).get(e.getKey()))||e.getKey().equals("users")||e.getKey().equals("members")||e.getKey().equals("memberships")||e.getKey().equals("payment_transactions")||e.getKey().equals("audit_logs")));
  assertEquals(AccountIntegrationDatabase.before,AccountIntegrationDatabase.snapshot(j));
 }
 @Test void addingPublishedV7LaterFailsValidationWithoutDdl(){
  var ds=AccountIntegrationDatabase.history;var j=new JdbcTemplate(ds);var before=AccountIntegrationDatabase.snapshot(j);
  var f=Flyway.configure().dataSource(ds).locations("classpath:db/migration","classpath:db/activation-rehearsal","classpath:db/membership-rehearsal","classpath:db/member-activation-rehearsal","filesystem:"+Path.of(AccountIntegrationDatabase.env("ACCOUNT_PRIVATE_DIRECTORY"),"v7-reference").toAbsolutePath()).outOfOrder(false).cleanDisabled(true).load();
  assertFalse(f.validateWithResult().validationSuccessful);
  assertEquals(0,j.queryForObject("SELECT count(*) FROM flyway_schema_history WHERE version='7'",Integer.class));
  assertEquals(2,j.queryForObject("SELECT count(*) FROM information_schema.columns WHERE table_name='payment_transactions' AND column_name IN ('period_start','period_end')",Integer.class));
  assertEquals(before,AccountIntegrationDatabase.snapshot(j));
 }
 @Test void postgresDdlAndDataRollbackLeavesNoHalfChange()throws Exception{
  try(var c=AccountIntegrationDatabase.history.getConnection();var s=c.createStatement()){
   c.setAutoCommit(false);s.execute("CREATE TABLE i01_rollback_probe(id integer PRIMARY KEY)");s.execute("INSERT INTO i01_rollback_probe VALUES(1)");
   assertThrows(java.sql.SQLException.class,()->s.execute("INSERT INTO i01_rollback_probe VALUES(1)"));c.rollback();
  }
  assertNull(new JdbcTemplate(AccountIntegrationDatabase.history).queryForObject("SELECT to_regclass('public.i01_rollback_probe')::text",String.class));
 }
}