package vn.edu.tdtu.fitcenter.renewal;
import org.springframework.beans.factory.InitializingBean;import org.springframework.beans.factory.annotation.Value;import org.springframework.core.env.Environment;import org.springframework.jdbc.core.JdbcTemplate;import org.springframework.stereotype.Component;import javax.sql.DataSource;import java.util.*;
@Component public class RenewalSchemaGuard implements InitializingBean {
 private final boolean enabled;private final Environment env;private final DataSource source;private final JdbcTemplate jdbc;
 public RenewalSchemaGuard(@Value("${fitcenter.renewal.enabled:false}")boolean enabled,Environment env,DataSource source,JdbcTemplate jdbc){this.enabled=enabled;this.env=env;this.source=source;this.jdbc=jdbc;}
 public void afterPropertiesSet(){if(!enabled)return;if(!(Arrays.asList(env.getActiveProfiles()).contains("core-demo") || Arrays.asList(env.getActiveProfiles()).contains("renewal-integration-rehearsal") || (Arrays.asList(env.getActiveProfiles()).contains("face-checkin-rehearsal") || Arrays.asList(env.getActiveProfiles()).contains("face-enrollment-rehearsal")))||!env.getProperty("fitcenter.renewal.guard-verified",Boolean.class,false))throw new IllegalStateException("Renewal simulator is guarded rehearsal-only");
 vn.edu.tdtu.fitcenter.activation.AccountIntegrationRehearsalConfiguration.verify(source,env.getProperty("fitcenter.account-integration.guard-verified",Boolean.class,false));
 for(String table:List.of("membership_paid_periods","renewal_payment_quotes","renewal_result_keys","renewal_payment_events"))if(!Boolean.TRUE.equals(jdbc.queryForObject("SELECT to_regclass(?) IS NOT NULL",Boolean.class,"public."+table)))throw new IllegalStateException("Missing renewal rehearsal schema");}
}
