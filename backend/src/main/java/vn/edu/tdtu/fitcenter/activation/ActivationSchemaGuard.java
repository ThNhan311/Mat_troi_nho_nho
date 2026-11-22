package vn.edu.tdtu.fitcenter.activation;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
@Component
public class ActivationSchemaGuard implements InitializingBean {
    private final boolean enabled;private final JdbcTemplate jdbc;
    public ActivationSchemaGuard(@Value("${fitcenter.activation.enabled:false}") boolean enabled,JdbcTemplate jdbc){this.enabled=enabled;this.jdbc=jdbc;}
    @Override public void afterPropertiesSet(){if(enabled&&jdbc.queryForObject("SELECT to_regclass('public.pt_account_activation') IS NOT NULL",Boolean.class)!=Boolean.TRUE)throw new IllegalStateException("PT activation requires an approved schema migration; none is applied automatically");}
}