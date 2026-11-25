package vn.edu.tdtu.fitcenter.membershipinitial;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import javax.sql.DataSource;
import java.util.Arrays;
@Component
public class InitialMembershipSchemaGuard implements InitializingBean {
 private final boolean enabled;private final Environment env;private final DataSource source;private final JdbcTemplate jdbc;
 public InitialMembershipSchemaGuard(@Value("${fitcenter.membership-initial.enabled:false}")boolean enabled,Environment env,DataSource source,JdbcTemplate jdbc){this.enabled=enabled;this.env=env;this.source=source;this.jdbc=jdbc;}
 public void afterPropertiesSet(){if(!enabled)return;
  if((Arrays.asList(env.getActiveProfiles()).contains("account-integration-rehearsal") || (Arrays.asList(env.getActiveProfiles()).contains("core-demo") || Arrays.asList(env.getActiveProfiles()).contains("renewal-integration-rehearsal") || (Arrays.asList(env.getActiveProfiles()).contains("face-checkin-rehearsal") || Arrays.asList(env.getActiveProfiles()).contains("face-enrollment-rehearsal"))))) {
   vn.edu.tdtu.fitcenter.activation.AccountIntegrationRehearsalConfiguration.verify(source,env.getProperty("fitcenter.account-integration.guard-verified",Boolean.class,false));
  } else {
  if(!Arrays.asList(env.getActiveProfiles()).contains("membership-rehearsal"))throw new IllegalStateException("Initial membership is rehearsal-only pending canonical release sequencing");
  InitialMembershipRehearsalConfiguration.verify(source,env.getProperty("fitcenter.membership-initial.guard-verified",Boolean.class,false));
  }
  if(!Boolean.TRUE.equals(jdbc.queryForObject("SELECT to_regclass('public.membership_initial_activations') IS NOT NULL",Boolean.class)))throw new IllegalStateException("Missing membership rehearsal schema");
 }
}
