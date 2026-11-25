import java.sql.*;import org.postgresql.ds.PGSimpleDataSource;import org.flywaydb.core.Flyway;
/** Only used after portable container/volume/image/port guards. No business data seeded. */
public class PreparePortableBaseline {
 public static void main(String[] args)throws Exception {
  var ds=new PGSimpleDataSource();ds.setURL("jdbc:postgresql://127.0.0.1:15437/fitcenter_baseline_20261120_test");ds.setUser("fitcenter_baseline_app");ds.setPassword(System.getenv("DB_PASSWORD"));
  boolean empty;
  try(var c=ds.getConnection();var s=c.createStatement();var q=s.executeQuery("SELECT current_database(),current_user,rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls,(SELECT count(*) FROM pg_tables WHERE schemaname='public') FROM pg_roles WHERE rolname=current_user")){
   if(!q.next()||!q.getString(1).equals("fitcenter_baseline_20261120_test")||!q.getString(2).equals("fitcenter_baseline_app")||q.getBoolean(3))throw new IllegalStateException("Need verified dedicated baseline identity/role");
   empty=q.getLong(4)==0;
  }
  var flyway=Flyway.configure().dataSource(ds).locations("classpath:db/migration").outOfOrder(false).cleanDisabled(true).load();
  if(empty)flyway.migrate();else {flyway.validate();if(flyway.info().applied().length!=6||flyway.info().pending().length!=0)throw new IllegalStateException("Expected complete V1-V6 history; no automatic upgrade/reset");}

  System.out.println("Initialized/validated exact V1-V6 test baseline only; no business seed");
 }
}
