package vn.edu.tdtu.fitcenter.activation;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
@Repository
public class JdbcActivationStore extends JdbcRoleActivationStore {
 public JdbcActivationStore(JdbcTemplate jdbc){super(jdbc,ActivationRole.PT);}
}
