package vn.edu.tdtu.fitcenter.activation;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
@Repository
public class JdbcMemberActivationStore extends JdbcRoleActivationStore {
 public JdbcMemberActivationStore(JdbcTemplate jdbc){super(jdbc,ActivationRole.MEMBER);}
}
