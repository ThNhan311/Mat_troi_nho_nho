import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.callback.*;
import org.postgresql.ds.PGSimpleDataSource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.ObjectMapper;
import vn.edu.tdtu.fitcenter.membershipinitial.*;
import vn.edu.tdtu.fitcenter.renewal.*;
import vn.edu.tdtu.fitcenter.service.*;
import vn.edu.tdtu.fitcenter.domain.entity.*;
import vn.edu.tdtu.fitcenter.domain.enums.*;
import java.nio.file.*;import java.sql.*;import java.time.*;import java.math.BigDecimal;
import java.util.*;import java.util.concurrent.*;

// Explicit private-DB migration/service rehearsal, not an application profile or release runner.
public class Db01MigrationRehearsal {
 static Path repo,root,sqlRoot;static ObjectMapper json=new ObjectMapper();
 static List<Map<String,Object>> checks=new ArrayList<>();static List<String> callbackOrder=new ArrayList<>();
 static void check(boolean ok,String label){if(!ok)throw new AssertionError(label);checks.add(Map.of("name",label,"passed",true));}
 static void equal(Object a,Object b,String label){check(Objects.equals(a,b),label);}
 static String sql(String n)throws Exception{return Files.readString(sqlRoot.resolve(n));}
 static void compat(Connection c)throws Exception{
  boolean auto=c.getAutoCommit();if(auto)c.setAutoCommit(false);
  try(var s=c.createStatement()){s.execute(sql("before-upgrade.sql"));prepareReceipts(c);if(auto)c.commit();}
  catch(Exception e){if(auto)c.rollback();throw e;}finally{if(auto)c.setAutoCommit(true);}
 }
 static void prepareReceipts(Connection c)throws Exception{
  boolean legacy;try(var s=c.createStatement();var r=s.executeQuery("SELECT EXISTS(SELECT 1 FROM pg_class WHERE oid=to_regclass('public.membership_periods') AND relkind='r')")){r.next();legacy=r.getBoolean(1);}if(!legacy)return;
  try(var s=c.createStatement();var r=s.executeQuery("SELECT id,membership_id,receipt_ref,to_jsonb(l)::text FROM membership_periods l WHERE source='ACTIVATION'")){
   while(r.next()){
    String key=new InitialActivationRequest(null,null,r.getString(3),null).receiptKey();if(key.codePointCount(0,key.length())>100)throw new SQLException("DB01_LEGACY_RECEIPT_NORMALIZATION_RANGE");
    try(var find=c.prepareStatement("SELECT legacy_period_id FROM db01_receipt_evidence WHERE receipt_key=?")){find.setString(1,key);try(var old=find.executeQuery()){if(old.next()&&!old.getObject(1).equals(r.getObject(1)))throw new SQLException("DB01_DUPLICATE_LEGACY_RECEIPT");}}
    try(var insert=c.prepareStatement("INSERT INTO db01_receipt_evidence(receipt_key,legacy_period_id,membership_id,source_row) VALUES(?,?,?,?::jsonb) ON CONFLICT(receipt_key) DO NOTHING")){insert.setString(1,key);insert.setObject(2,r.getObject(1));insert.setObject(3,r.getObject(2));insert.setString(4,r.getString(4));insert.executeUpdate();}
   }
  }
 }
 static class Bridge implements Callback {
  public String getCallbackName(){return "DB01_explicit_compatibility";}
  public boolean supports(Event e,Context c){return e==Event.BEFORE_MIGRATE||e==Event.AFTER_EACH_MIGRATE;}
  public boolean canHandleInTransaction(Event e,Context c){return true;}
  public void handle(Event e,Context c){try{
   if(e==Event.BEFORE_MIGRATE){compat(c.getConnection());callbackOrder.add("before_migrate");}
   else {String version=c.getMigrationInfo().getVersion().toString();callbackOrder.add("after_"+version);
    if(version.equals("7")){compat(c.getConnection());callbackOrder.add("restore_after_7_before_8_9_11");}}
  }catch(Exception ex){throw new IllegalStateException("DB01 compatibility callback failed",ex);}}
 }
 static List<String> locations(boolean v7,boolean v14){var l=new ArrayList<String>();
  for(String x:List.of("migrations","activation-rehearsal","membership-rehearsal","member-activation-rehearsal","renewal-rehearsal","checkin-rehearsal","enrollment-rehearsal"))l.add("filesystem:"+repo.resolve("database/"+x));
  if(v7)l.add("filesystem:"+root.resolve("source-v7"));if(v14)l.add("filesystem:"+sqlRoot.resolve("migration"));return l;
 }
 static Flyway fly(PGSimpleDataSource ds,String target,boolean v7,boolean v14,boolean bridge){var f=Flyway.configure().dataSource(ds).locations(locations(v7,v14).toArray(String[]::new)).target(target)
   .outOfOrder(false).cleanDisabled(true).baselineOnMigrate(false).validateMigrationNaming(true);
  if(bridge)f.callbacks(new Bridge());return f.load();}
 static PGSimpleDataSource connect(String db){if(!db.matches("fitcenter_db01_[a-f0-9]{12}_test"))throw new IllegalStateException("Unexpected private database");
  var ds=new PGSimpleDataSource();ds.setURL("jdbc:postgresql://127.0.0.1:15441/"+db);ds.setUser("fitcenter_account_app");ds.setPassword(System.getenv("DB_PASSWORD"));
  var j=new JdbcTemplate(ds);equal(j.queryForObject("SELECT current_database()||'|'||current_user||'|'||(rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)::text FROM pg_roles WHERE rolname=current_user",String.class),db+"|fitcenter_account_app|false","datasource/role "+db.substring(16,28));return ds;
 }
 static Map<String,String> snapshot(JdbcTemplate j){var out=new TreeMap<String,String>();for(String t:List.of("users","members","personal_trainers","membership_plans","memberships","payment_transactions","bookings","audit_logs","membership_initial_activations","pt_account_activation","member_account_activation")){
  if(Boolean.TRUE.equals(j.queryForObject("SELECT to_regclass(?) IS NOT NULL",Boolean.class,"public."+t)))out.put(t,j.queryForObject("SELECT coalesce(json_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]')::text FROM "+t+" x",String.class));}return out;}
 static UUID actor(JdbcTemplate j,String role){UUID user=UUID.randomUUID();j.update("INSERT INTO users(id,email,password_hash,role,status) VALUES(?,?,'not-a-login-credential',?,'ACTIVE')",user,"db01-"+user+"@example.invalid",role);return user;}
 static UUID member(JdbcTemplate j){UUID user=actor(j,"MEMBER"),m=UUID.randomUUID();j.update("INSERT INTO members(id,user_id,full_name) VALUES(?,?,'Synthetic DB01')",m,user);return m;}
 static String email(JdbcTemplate j,UUID member){return j.queryForObject("SELECT u.email FROM users u JOIN members m ON m.user_id=u.id WHERE m.id=?",String.class,member);}
 static UUID plan(JdbcTemplate j){UUID p=UUID.randomUUID();j.update("INSERT INTO membership_plans(id,name,duration_days,price) VALUES(?,'Synthetic DB01',2,0)",p);return p;}
 record History(UUID member,UUID membership,UUID plan,UUID payment,UUID activation){}
 static History history(JdbcTemplate j,boolean v7){UUID admin=actor(j,"ADMIN"),m=member(j),p=plan(j),ms=UUID.randomUUID(),tx=UUID.randomUUID(),activation=UUID.randomUUID();
  j.update("INSERT INTO memberships(id,member_id,plan_id,start_date,expiry_date,status) VALUES(?,?,?,'2028-02-28','2028-03-04','ACTIVE')",ms,m,p);
  if(v7){
   j.update("INSERT INTO membership_periods(id,membership_id,plan_id,source,period_start,period_end,amount_collected,confirmed_by_user_id,confirmed_at,receipt_ref) VALUES(?,?,?,'ACTIVATION','2028-02-28','2028-02-29',0,?,now(),?)",activation,ms,p,admin,"DB01-"+activation);
   j.update("INSERT INTO payment_transactions(id,member_id,plan_id,membership_id,provider_ref,amount,status) VALUES(?,?,?,?,?,0,'SUCCESS')",tx,m,p,ms,"db01:"+tx);
   j.update("INSERT INTO membership_periods(membership_id,plan_id,source,period_start,period_end,payment_transaction_id) VALUES(?,?,'RENEWAL','2028-03-02','2028-03-04',?)",ms,p,tx);
  }else{
   j.update("INSERT INTO payment_transactions(id,member_id,plan_id,membership_id,provider_ref,amount,status,period_start,period_end) VALUES(?,?,?,?,?,0,'SUCCESS','2028-02-28','2028-02-29')",tx,m,p,ms,"db01:"+tx);
   UUID tx2=UUID.randomUUID();j.update("INSERT INTO payment_transactions(id,member_id,plan_id,membership_id,provider_ref,amount,status,period_start,period_end) VALUES(?,?,?,?,?,0,'SUCCESS','2028-03-02','2028-03-04')",tx2,m,p,ms,"db01:"+tx2);
  }return new History(m,ms,p,tx,activation);
 }
 static void sourceView(JdbcTemplate j){equal(j.queryForObject("SELECT relkind::text FROM pg_class WHERE oid='membership_periods'::regclass",String.class),"v","legacy name is canonical read-only view");
  long before=j.queryForObject("SELECT count(*) FROM membership_paid_periods",Long.class);
  try{j.update("DELETE FROM membership_periods");throw new AssertionError("legacy write accepted");}catch(org.springframework.dao.DataAccessException expected){check(expected.getMessage().contains("DB01_LEGACY_PERIOD_WRITES_DISABLED"),"legacy writer rejected explicitly");}
  equal(j.queryForObject("SELECT count(*) FROM membership_paid_periods",Long.class),before,"rejected legacy write does not mutate canonical periods");}
 static void historical(PGSimpleDataSource ds,History h,Map<String,String> before,boolean v7)throws Exception{var j=new JdbcTemplate(ds);var upgraded=snapshot(j);for(var entry:before.entrySet())equal(upgraded.get(entry.getKey()),entry.getValue(),"original "+entry.getKey()+" rows unchanged by upgrade");
  var p=new MembershipPeriodService(j,true);equal(p.rows(h.membership()).size(),2,"two sourced historical periods retained");var eligibility=new BookingEligibilityValidator();eligibility.setPeriods(p);
  var ms=Membership.builder().id(h.membership()).startDate(LocalDate.parse("2028-02-28")).expiryDate(LocalDate.parse("2028-03-04")).status(MembershipStatus.ACTIVE).build();
  var account=User.builder().role(Role.MEMBER).status(AccountStatus.ACTIVE).build();var session=Booking.builder().status(BookingStatus.CONFIRMED).startAt(OffsetDateTime.parse("2028-03-01T03:00:00Z")).endAt(OffsetDateTime.parse("2028-03-01T04:30:00Z")).build();
  check(!new ServiceEligibilityValidator(eligibility).check(session,account,ms,session.getStartAt().toInstant()).eligible(),"D01 rejects unpaid gap after upgrade");
  check(!p.covered(h.membership(),LocalDate.parse("2028-02-29"),LocalDate.parse("2028-03-02")),"unpaid March1 gap is not bridged");check(p.covered(h.membership(),LocalDate.parse("2028-02-28"),LocalDate.parse("2028-02-29")),"inclusive leap-day coverage remains valid");
  equal(j.queryForObject("SELECT count(*) FROM membership_paid_periods WHERE plan_name_snapshot IS NOT NULL OR duration_days_snapshot IS NOT NULL OR currency IS NOT NULL",Long.class),0L,"legacy quote/name/currency not fabricated from current plan");
  if(v7){equal(j.queryForObject("SELECT count(*) FROM db01_legacy_membership_periods",Long.class),2L,"all original V7 rows preserved in read-only archive");equal(j.queryForObject("SELECT receipt_ref FROM membership_periods WHERE id=?",String.class,h.activation()),"DB01-"+h.activation(),"V7 receipt remains readable without inventing COUNTER transaction");}
  sourceView(j);
 }
 static String codes(Throwable e){var s=new StringBuilder();for(Throwable x=e;x!=null;x=x.getCause())s.append(x.getMessage()).append(' ');return s.toString();}
 static void expectFailure(PGSimpleDataSource ds,String expected,boolean v7)throws Exception{var j=new JdbcTemplate(ds);var before=snapshot(j);String history=j.queryForObject("SELECT string_agg(version,',' ORDER BY installed_rank) FROM flyway_schema_history",String.class);
  try{fly(ds,"14",v7,true,true).migrate();throw new AssertionError("Missing expected refusal "+expected);}catch(Exception e){check(codes(e).contains(expected),"refuses "+expected);}
  equal(snapshot(j),before,"failed compatibility upgrade rolls back business rows");equal(j.queryForObject("SELECT string_agg(version,',' ORDER BY installed_rank) FROM flyway_schema_history",String.class),history,"failure leaves Flyway history unchanged");
  check(!Boolean.TRUE.equals(j.queryForObject("SELECT to_regclass('public.db01_period_sources') IS NOT NULL",Boolean.class)),"failed upgrade does not publish second source model");
 }
 static void services(PGSimpleDataSource ds)throws Exception{var j=new JdbcTemplate(ds);UUID admin=actor(j,"ADMIN"),member=member(j),plan=plan(j);String adminEmail=j.queryForObject("SELECT email FROM users WHERE id=?",String.class,admin),memberEmail=email(j,member);var manager=new DataSourceTransactionManager(ds);var periods=new MembershipPeriodService(j,true);var clock=Clock.fixed(Instant.parse("2028-02-28T17:00:00Z"),ZoneOffset.UTC);
  var initial=new InitialMembershipService(j,json,clock,manager,true);initial.setPeriods(periods);UUID key=UUID.randomUUID();var request=new InitialActivationRequest(plan,BigDecimal.ZERO,"DB01-"+key,null);var result=initial.create(adminEmail,member,key,request,"db01");equal(result.status(),201,"M03 real service creates COUNTER+receipt+paid period");var body=json.readTree(result.json());UUID ms=UUID.fromString(body.get("membership").get("id").asText());
  if(Boolean.TRUE.equals(j.queryForObject("SELECT to_regclass('public.db01_receipt_evidence') IS NOT NULL",Boolean.class))&&j.queryForObject("SELECT count(*) FROM db01_receipt_evidence",Long.class)>0){
   String reserved=j.queryForObject("SELECT source_row->>'receipt_ref' FROM db01_receipt_evidence LIMIT 1",String.class);UUID another=member(j);long n=j.queryForObject("SELECT count(*) FROM memberships",Long.class);
   try{initial.create(adminEmail,another,UUID.randomUUID(),new InitialActivationRequest(plan,BigDecimal.ZERO,reserved,null),"db01");throw new AssertionError("legacy receipt reused");}catch(InitialActivationFailure e){equal(e.status,409,"new M03 cannot reuse an original V7 receipt");}
   equal(j.queryForObject("SELECT count(*) FROM memberships",Long.class),n,"legacy receipt conflict rolls back new Membership");
  }
  String receipt=j.queryForObject("SELECT response_snapshot::text FROM membership_initial_activations WHERE membership_id=?",String.class,ms);equal(initial.create(adminEmail,member,key,request,"db01").json(),result.json(),"M03 same-key replay retains exact response");
  var renewal=new RenewalService(j,json,clock,manager,periods,true);UUID renewalKey=UUID.randomUUID();var quote=renewal.initiate(memberEmail,ms,renewalKey,new RenewalRequests.Create(plan));UUID payment=(UUID)quote.body().get("id");equal(j.queryForObject("SELECT expiry_date::text FROM memberships WHERE id=?",String.class,ms),"2028-03-01","PENDING does not extend leap-year membership");
  j.update("UPDATE membership_plans SET price=777,duration_days=30,status='INACTIVE' WHERE id=?",plan);
  var event=new RenewalRequests.Event(UUID.randomUUID(),(String)quote.body().get("providerRef"),BigDecimal.ZERO,"VND","SUCCESS");var settled=renewal.settle(adminEmail,payment,event);equal(settled.body().get("periodStart"),"2028-03-02","renewal uses original 2-day quote after plan edit");equal(settled.body().get("periodEnd"),"2028-03-03","renewal end inclusive with snapshot duration");
  equal(json.readTree(json.writeValueAsString(renewal.settle(adminEmail,payment,event).body())),json.readTree(json.writeValueAsString(settled.body())),"duplicate SUCCESS returns original result");equal(periods.rows(ms).size(),2,"SUCCESS replay adds no duplicate period");equal(j.queryForObject("SELECT response_snapshot::text FROM membership_initial_activations WHERE membership_id=?",String.class,ms),receipt,"renewal preserves original receipt and M03 snapshots");
  if(Boolean.TRUE.equals(j.queryForObject("SELECT to_regclass('public.membership_periods') IS NOT NULL",Boolean.class)))equal(j.queryForObject("SELECT count(*) FROM membership_periods WHERE membership_id=?",Long.class,ms),2L,"V7 compatibility reader sees new canonical writes");
  var m=Membership.builder().id(ms).startDate(LocalDate.parse("2028-02-29")).expiryDate(LocalDate.parse("2028-03-03")).status(MembershipStatus.ACTIVE).build();var validator=new BookingEligibilityValidator();validator.setPeriods(periods);validator.validateMembership(m,clock.instant(),clock.instant().plusSeconds(5400),clock.instant());check(true,"Booking/D01 paid coverage works on upgraded canonical data");
  try{renewal.payment(email(j,member(j)),payment);throw new AssertionError("wrong owner accepted");}catch(RenewalFailure e){equal(e.status,404,"renewal owner isolation after upgrade");}
  UUID pendingPlan=plan(j);var pending=renewal.initiate(memberEmail,ms,UUID.randomUUID(),new RenewalRequests.Create(pendingPlan));UUID pendingId=(UUID)pending.body().get("id");var failed=new RenewalRequests.Event(UUID.randomUUID(),(String)pending.body().get("providerRef"),BigDecimal.ZERO,"VND","FAILED");renewal.settle(adminEmail,pendingId,failed);equal(periods.rows(ms).size(),2,"FAILED grants no paid coverage");
  var reconciled=renewal.initiate(memberEmail,ms,UUID.randomUUID(),new RenewalRequests.Create(pendingPlan));j.update("UPDATE memberships SET status='SUSPENDED' WHERE id=?",ms);var reconcileEvent=new RenewalRequests.Event(UUID.randomUUID(),(String)reconciled.body().get("providerRef"),BigDecimal.ZERO,"VND","SUCCESS");var reconcile=renewal.settle(adminEmail,(UUID)reconciled.body().get("id"),reconcileEvent);equal(reconcile.body().get("fulfillmentStatus"),"RECONCILIATION_REQUIRED","received funds during SUSPENDED remain reconciliation, not rights");equal(periods.rows(ms).size(),2,"reconciliation does not silently grant period");
  // Callback re-run must accept SUCCESS explicitly held for reconciliation.
  try(var c=ds.getConnection()){compat(c);}check(true,"bridge repeat accepts traced reconciliation SUCCESS without coverage");
  j.update("UPDATE memberships SET status='ACTIVE' WHERE id=?",ms);
  var qa=renewal.initiate(memberEmail,ms,UUID.randomUUID(),new RenewalRequests.Create(pendingPlan));var qb=renewal.initiate(memberEmail,ms,UUID.randomUUID(),new RenewalRequests.Create(pendingPlan));
  var barrier=new CyclicBarrier(2);try(var pool=Executors.newVirtualThreadPerTaskExecutor()){
   var futures=new ArrayList<Future<RenewalService.Result>>();for(var q:List.of(qa,qb))futures.add(pool.submit(()->{barrier.await(5,TimeUnit.SECONDS);return renewal.settle(adminEmail,(UUID)q.body().get("id"),new RenewalRequests.Event(UUID.randomUUID(),(String)q.body().get("providerRef"),BigDecimal.ZERO,"VND","SUCCESS"));}));
   for(var f:futures)equal(f.get(15,TimeUnit.SECONDS).body().get("fulfillmentStatus"),"APPLIED","concurrent independent SUCCESS applies once");
  }equal(periods.rows(ms).size(),4,"Member lock serializes two independent renewal periods");
  UUID rollbackMember=member(j),rollbackPlan=plan(j);var baseline=snapshot(j);
  j.execute("CREATE FUNCTION db01_test_failure() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'DB01_INJECTED_FAILURE'; END$$");j.execute("CREATE TRIGGER db01_test_failure BEFORE INSERT ON audit_logs FOR EACH ROW EXECUTE FUNCTION db01_test_failure()");
  try{initial.create(adminEmail,rollbackMember,UUID.randomUUID(),new InitialActivationRequest(rollbackPlan,BigDecimal.ZERO,"DB01-"+UUID.randomUUID(),null),"db01");throw new AssertionError("injected failure ignored");}catch(RuntimeException expected){check(codes(expected).contains("DB01_INJECTED_FAILURE"),"injected M03 failure propagates");}finally{j.execute("DROP TRIGGER db01_test_failure ON audit_logs");j.execute("DROP FUNCTION db01_test_failure()");}
  equal(snapshot(j),baseline,"M03 failure rolls back Membership/payment/receipt/audit atomically");
  equal(j.queryForObject("SELECT count(*) FROM bookings",Long.class),0L,"membership migration/services do not mutate Booking");
 }
 static void scenario(String name,String db)throws Exception{var ds=connect(db);var j=new JdbcTemplate(ds);equal(j.queryForObject("SELECT count(*) FROM pg_tables WHERE schemaname='public'",Long.class),0L,"new database has no preexisting tables: "+name);fly(ds,"6",false,false,false).migrate();
  if(name.equals("fresh")){fly(ds,"14",true,true,true).migrate();equal(j.queryForObject("SELECT count(*) FROM flyway_schema_history WHERE success",Long.class),14L,"fresh install uses original V1-V14 in order");services(ds);sourceView(j);return;}
  if(name.equals("v6_history")){var h=history(j,false);var before=snapshot(j);fly(ds,"14",true,true,true).migrate();historical(ds,h,before,false);check(callbackOrder.contains("restore_after_7_before_8_9_11"),"compatibility restored after V7 before dependent migrations");return;}
  if(name.equals("m03_before_v11")){
   fly(ds,"10",false,false,false).migrate();UUID admin=actor(j,"ADMIN"),m=member(j),p=plan(j);var service=new InitialMembershipService(j,json,Clock.fixed(Instant.parse("2028-02-28T17:00:00Z"),ZoneOffset.UTC),new DataSourceTransactionManager(ds),true);
   var created=service.create(j.queryForObject("SELECT email FROM users WHERE id=?",String.class,admin),m,UUID.randomUUID(),new InitialActivationRequest(p,BigDecimal.ZERO,"DB01-"+UUID.randomUUID(),null),"db01");var before=snapshot(j);
   fly(ds,"14",false,true,true).migrate();var after=snapshot(j);for(var e:before.entrySet())equal(after.get(e.getKey()),e.getValue(),"pre-V11 M03 preserves "+e.getKey());
   equal(j.queryForObject("SELECT count(*) FROM membership_paid_periods WHERE source='INITIAL_COUNTER'",Long.class),1L,"pre-V11 M03 backfills COUNTER as initial, never as renewal");sourceView(j);return;
  }
  if(name.equals("existing_legacy_core")){
   var h=history(j,false);fly(ds,"13",false,false,false).migrate();String aggregate=j.queryForObject("SELECT to_jsonb(p)::text FROM membership_paid_periods p",String.class);var before=snapshot(j);
   fly(ds,"14",false,true,true).migrate();historical(ds,h,before,false);equal(j.queryForObject("SELECT source_row::text FROM db01_generated_aggregate_archive",String.class),aggregate,"existing Core aggregate retained byte-equivalent as JSON archive");return;
  }
  if(name.equals("conflicting_evidence")){
   var h=history(j,false);try(var c=ds.getConnection()){compat(c);}fly(ds,"7",true,false,false).migrate();
   j.update("INSERT INTO membership_periods(membership_id,plan_id,source,period_start,period_end,payment_transaction_id) VALUES(?,?,'RENEWAL','2028-03-02','2028-03-04',?)",h.membership(),h.plan(),h.payment());expectFailure(ds,"DB01_CONFLICTING_PERIOD_EVIDENCE",true);return;
  }
  if(name.equals("existing_core")){fly(ds,"13",false,false,false).migrate();services(ds);for(String role:List.of("PT","MEMBER")){UUID u=actor(j,role);String table=role.equals("PT")?"pt_account_activation":"member_account_activation";j.update("INSERT INTO "+table+"(user_id,send_window_started_at,send_count,last_sent_at) VALUES(?,now(),2,now())",u);}
   var before=snapshot(j);var paid=j.queryForObject("SELECT json_agg(x ORDER BY id)::text FROM membership_paid_periods x",String.class);fly(ds,"14",false,true,true).migrate();equal(snapshot(j),before,"existing Core receipts/account/payment state unchanged");equal(j.queryForObject("SELECT json_agg(x ORDER BY id)::text FROM membership_paid_periods x",String.class),paid,"existing Core paid periods unchanged");return;}
  // V7 is applied while payments are empty, so this fixture never drops sourced payment data.
  fly(ds,"7",true,false,false).migrate();var h=history(j,true);
  if(name.equals("v7_history")){var before=snapshot(j);fly(ds,"14",true,true,true).migrate();
   // Restored columns are intentional; all prior JSON keys and values must be preserved.
   var after=snapshot(j);var old=json.readTree(before.get("payment_transactions"));var newer=json.readTree(after.get("payment_transactions"));
   ((tools.jackson.databind.node.ObjectNode)newer.get(0)).remove("period_start");((tools.jackson.databind.node.ObjectNode)newer.get(0)).remove("period_end");equal(newer,old,"V7 payment restoration preserves original columns/timestamps");before.put("payment_transactions",after.get("payment_transactions"));historical(ds,h,before,true);services(ds);
   long count=j.queryForObject("SELECT count(*) FROM membership_paid_periods",Long.class);equal(fly(ds,"14",true,true,true).migrate().migrationsExecuted,0,"second migrate does not reapply/backfill");equal(j.queryForObject("SELECT count(*) FROM membership_paid_periods",Long.class),count,"second migrate does not duplicate periods");return;}
  if(name.equals("duplicate_receipt")){
   UUID m2=member(j),ms2=UUID.randomUUID();j.update("INSERT INTO memberships(id,member_id,plan_id,start_date,expiry_date,status) VALUES(?,?,?,'2028-02-28','2028-02-29','ACTIVE')",ms2,m2,h.plan());
   UUID admin=actor(j,"ADMIN");j.update("INSERT INTO membership_periods(membership_id,plan_id,source,period_start,period_end,amount_collected,confirmed_by_user_id,confirmed_at,receipt_ref) VALUES(?,?,'ACTIVATION','2028-02-28','2028-02-29',0,?,now(),?)",ms2,h.plan(),admin," db01-"+h.activation()+" ");expectFailure(ds,"DB01_DUPLICATE_LEGACY_RECEIPT",true);return;
  }
  if(name.equals("missing_coverage")){
   fly(ds,"13",true,false,true).migrate();UUID m2=member(j);j.update("INSERT INTO memberships(member_id,plan_id,start_date,expiry_date,status) VALUES(?,?,'2028-02-28','2028-02-29','ACTIVE')",m2,h.plan());expectFailure(ds,"DB01_MEMBERSHIP_COVERAGE_PROVENANCE_MISSING",true);return;
  }
  if(name.equals("missing_provenance")){j.update("DELETE FROM membership_periods WHERE payment_transaction_id=?",h.payment());expectFailure(ds,"DB01_PAYMENT_PERIOD_PROVENANCE_MISSING",true);return;}
  if(name.equals("refunded")){j.update("UPDATE payment_transactions SET status='REFUNDED' WHERE id=?",h.payment());expectFailure(ds,"DB01_REFUND_RECONCILIATION_REQUIRED",true);return;}
  if(name.equals("wrong_binding")){j.update("UPDATE payment_transactions SET member_id=? WHERE id=?",member(j),h.payment());expectFailure(ds,"DB01_LEGACY_PAYMENT_BINDING_MISMATCH",true);return;}
  if(name.equals("overlap_rollback")){
   // Pause at V13, then introduce an independently writable legacy row inconsistent with canonical data.
   fly(ds,"13",true,false,true).migrate();j.update("UPDATE membership_paid_periods SET payment_transaction_id=? WHERE membership_id=?",h.payment(),h.membership());
   var before=snapshot(j);String rows=j.queryForObject("SELECT json_agg(x ORDER BY id)::text FROM membership_paid_periods x",String.class);
   // Ambiguous duplicate legacy activation cannot be merged by guessed identity.

   try{fly(ds,"14",true,true,true).migrate();throw new AssertionError("expected conflict");}catch(Exception e){check(codes(e).contains("DB01_PERIOD_SOURCE_CONFLICT"),"overlapping sources fail with controlled migration refusal");}
   equal(j.queryForObject("SELECT json_agg(x ORDER BY id)::text FROM membership_paid_periods x",String.class),rows,"V14 rollback restores derived aggregates and canonical rows");equal(j.queryForObject("SELECT max(installed_rank) FROM flyway_schema_history",Integer.class),13,"failed V14 does not change Flyway history");return;
  }
  throw new IllegalArgumentException("Unknown scenario");
 }
 static void ownership(tools.jackson.databind.JsonNode run)throws Exception{
  var databases=new ArrayList<Map<String,Object>>();
  for(var entry:run.get("databases")){
   String db=entry.get("database").asText();var ds=new PGSimpleDataSource();ds.setURL("jdbc:postgresql://127.0.0.1:15441/"+db);ds.setUser("fitcenter_account_app");ds.setPassword(System.getenv("DB_PASSWORD"));var j=new JdbcTemplate(ds);var tables=new TreeMap<String,Object>();
   for(var table:j.queryForList("SELECT c.relname,array_agg(a.attname ORDER BY k.ord) names FROM pg_index i JOIN pg_class c ON c.oid=i.indrelid JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN LATERAL unnest(i.indkey) WITH ORDINALITY k(attnum,ord) JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum=k.attnum WHERE i.indisprimary AND n.nspname='public' AND c.relname<>'flyway_schema_history' GROUP BY c.relname")){
    String name=(String)table.get("relname");if(!name.matches("[a-z0-9_]+"))throw new IllegalStateException("Unsafe fixture table");String[] keys=(String[])((java.sql.Array)table.get("names")).getArray();for(String key:keys)if(!key.matches("[a-z0-9_]+"))throw new IllegalStateException("Unsafe fixture key");
    tables.put(name,Map.of("keys",keys,"rows",j.queryForList("SELECT "+String.join(",",keys)+" FROM "+name)));
   }databases.add(Map.of("database",db,"tables",tables));
  }
  Files.writeString(root.resolve("db01-owned-rows.json"),json.writerWithDefaultPrettyPrinter().writeValueAsString(Map.of("containerId",run.get("containerId").asText(),"scope","New empty DBs exclusively created for this attempt; sealed before cleanup/outside-row sentinel", "databases",databases)),StandardOpenOption.CREATE_NEW);
 }
 public static void main(String[] args)throws Exception{repo=Path.of(args[0]).toAbsolutePath();root=Path.of(args[1]).toAbsolutePath();sqlRoot=repo.resolve("docs/backend-handover/proposals/db01");if(!root.startsWith(Path.of(System.getenv("LOCALAPPDATA"),"Temp"))||System.getenv("DB_PASSWORD")==null)throw new IllegalStateException("Private Temp authority and process-only password required");
  var run=json.readTree(Files.readString(root.resolve("db01-run.json")));var result=new LinkedHashMap<String,Object>();result.put("kind","PostgreSQL migration and real JDBC-service checks; not HTTP/UI/JUnit E2E");result.put("checks",checks);
  try{var scenarios=new ArrayList<Map<String,Object>>();result.put("scenarios",scenarios);for(var s:run.get("databases")){int before=checks.size();scenario(s.get("scenario").asText(),s.get("database").asText());scenarios.add(Map.of("scenario",s.get("scenario").asText(),"checks",checks.size()-before,"failed",0));}result.put("passed",checks.size());result.put("failed",0);result.put("skipped",0);result.put("callbackOrder",callbackOrder);}
  catch(Throwable e){result.put("passed",checks.size());result.put("failed",1);result.put("skipped",0);throw e;}
  finally{Files.writeString(root.resolve("db01-results.json"),json.writerWithDefaultPrettyPrinter().writeValueAsString(result));ownership(run);}
  System.out.println("DB01 checks passed="+checks.size()+", failed=0, skipped=0");
 }
}
