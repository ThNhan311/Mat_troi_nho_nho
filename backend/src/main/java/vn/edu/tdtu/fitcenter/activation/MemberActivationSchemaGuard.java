package vn.edu.tdtu.fitcenter.activation;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import javax.sql.DataSource;
import java.util.Arrays;
@Component
public class MemberActivationSchemaGuard implements InitializingBean {
 private final boolean enabled;private final Environment env;private final DataSource source;private final JdbcTemplate jdbc;
 public MemberActivationSchemaGuard(@Value("${fitcenter.member-activation.enabled:false}")boolean enabled,Environment env,DataSource source,JdbcTemplate jdbc){this.enabled=enabled;this.env=env;this.source=source;this.jdbc=jdbc;}
 public void afterPropertiesSet(){if(!enabled)return;
  if(!(Arrays.asList(env.getActiveProfiles()).contains("account-integration-rehearsal") || (Arrays.asList(env.getActiveProfiles()).contains("core-demo") || Arrays.asList(env.getActiveProfiles()).contains("renewal-integration-rehearsal") || (Arrays.asList(env.getActiveProfiles()).contains("face-checkin-rehearsal") || Arrays.asList(env.getActiveProfiles()).contains("face-enrollment-rehearsal")))))throw new IllegalStateException("Member activation is integrated-rehearsal only pending canonical rollout");
  AccountIntegrationRehearsalConfiguration.verify(source,env.getProperty("fitcenter.account-integration.guard-verified",Boolean.class,false));
  if(!Boolean.TRUE.equals(jdbc.queryForObject("SELECT to_regclass('public.member_account_activation') IS NOT NULL",Boolean.class)))throw new IllegalStateException("Missing Member activation rehearsal schema");
 }
}
