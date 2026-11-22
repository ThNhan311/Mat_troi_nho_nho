package vn.edu.tdtu.fitcenter.activation;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.*;
@Repository @RequiredArgsConstructor
public class JdbcActivationStore implements ActivationStore {
    private final JdbcTemplate jdbc;
    @Override public Optional<UUID> findUser(String email){return jdbc.queryForList("SELECT id FROM users WHERE lower(email)=lower(?)",UUID.class,email).stream().findFirst();}
    @Override public Optional<UUID> findGrant(String digest){return jdbc.queryForList("SELECT user_id FROM pt_account_activation WHERE grant_digest=?",UUID.class,digest).stream().findFirst();}
    @Override public Account lockUser(UUID id){
        var rows=jdbc.query("SELECT u.id,u.email,u.role,u.status,(EXISTS(SELECT 1 FROM audit_logs a WHERE a.entity_id=u.id AND a.entity_type='USER' AND a.action='ACCOUNT_CREATED_PENDING_ACTIVATION') AND NOT EXISTS(SELECT 1 FROM audit_logs a WHERE a.entity_id=u.id AND a.entity_type='USER' AND a.action='PT_ACCOUNT_ACTIVATED')) pending FROM users u WHERE u.id=? FOR UPDATE OF u",
                (r,i)->new Account(r.getObject("id",UUID.class),r.getString("email"),r.getString("role"),r.getString("status"),r.getBoolean("pending")),id);
        return rows.isEmpty()?null:rows.getFirst();
    }
    @Override public State lockState(UUID id){
        var rows=jdbc.query("SELECT * FROM pt_account_activation WHERE user_id=? FOR UPDATE",(r,i)->{
            var s=new State();s.userId=id;s.otpDigest=r.getString("otp_digest");s.grantDigest=r.getString("grant_digest");
            s.otpExpiresAt=instant(r.getTimestamp("otp_expires_at"));s.grantExpiresAt=instant(r.getTimestamp("grant_expires_at"));
            s.windowStartedAt=instant(r.getTimestamp("send_window_started_at"));s.lastSentAt=instant(r.getTimestamp("last_sent_at"));s.completedAt=instant(r.getTimestamp("completed_at"));
            s.attempts=r.getInt("attempts");s.sendCount=r.getInt("send_count");return s;
        },id);return rows.isEmpty()?null:rows.getFirst();
    }
    private static Instant instant(Timestamp t){return t==null?null:t.toInstant();}
    private static Timestamp stamp(Instant t){return t==null?null:Timestamp.from(t);}
    @Override public void save(State s){jdbc.update("INSERT INTO pt_account_activation(user_id,otp_digest,otp_expires_at,attempts,send_window_started_at,send_count,last_sent_at,grant_digest,grant_expires_at,completed_at) VALUES(?,?,?,?,?,?,?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET otp_digest=excluded.otp_digest,otp_expires_at=excluded.otp_expires_at,attempts=excluded.attempts,send_window_started_at=excluded.send_window_started_at,send_count=excluded.send_count,last_sent_at=excluded.last_sent_at,grant_digest=excluded.grant_digest,grant_expires_at=excluded.grant_expires_at,completed_at=excluded.completed_at",
            s.userId,s.otpDigest,stamp(s.otpExpiresAt),s.attempts,stamp(s.windowStartedAt),s.sendCount,stamp(s.lastSentAt),s.grantDigest,stamp(s.grantExpiresAt),stamp(s.completedAt));}
    @Override public void activate(UUID id,String hash){
        if(jdbc.update("UPDATE users SET password_hash=?,status='ACTIVE' WHERE id=? AND role='PT' AND status='DISABLED'",hash,id)!=1)throw new ActivationFailure(409,"ERR_ACTIVATION_CONFLICT","Account changed");
        jdbc.update("INSERT INTO audit_logs(actor_user_id,actor_type,action,entity_type,entity_id) VALUES(?,'USER','PT_ACCOUNT_ACTIVATED','USER',?)",id,id);
    }
}