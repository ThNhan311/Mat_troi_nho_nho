package vn.edu.tdtu.fitcenter.activation;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
@Component
public class ActivationSchemaGuard implements InitializingBean {
    private final boolean enabled,rehearsal;private final JdbcTemplate jdbc;
    public ActivationSchemaGuard(@Value("${fitcenter.activation.enabled:false}") boolean enabled,@Value("${fitcenter.activation.rehearsal:false}") boolean rehearsal,JdbcTemplate jdbc){this.enabled=enabled;this.rehearsal=rehearsal;this.jdbc=jdbc;}
    @Override public void afterPropertiesSet(){
        if(enabled&&!rehearsal)throw new IllegalStateException("PT activation is test-rehearsal only; production rollout is not authorized");
        if(enabled&&jdbc.queryForObject("SELECT to_regclass('public.pt_account_activation') IS NOT NULL",Boolean.class)!=Boolean.TRUE)throw new IllegalStateException("PT activation requires the rehearsal migration; none is applied automatically by this guard");
    }
}
