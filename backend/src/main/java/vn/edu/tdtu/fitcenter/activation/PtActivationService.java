package vn.edu.tdtu.fitcenter.activation;
import org.springframework.beans.factory.annotation.*;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.Clock;
@Service
public class PtActivationService {
 private final AccountActivationFlow flow;
 public PtActivationService(@Qualifier("jdbcActivationStore") ActivationStore store,ActivationMailer mailer,PasswordEncoder encoder,Clock clock,@Value("${fitcenter.activation.enabled:false}") boolean enabled){flow=new AccountActivationFlow(store,mailer,encoder,clock,enabled,ActivationRole.PT);}
 @Transactional(timeout=10) public void request(String email){flow.request(email);}
 @Transactional(timeout=10,noRollbackFor=ActivationFailure.class) public String verify(String email,String otp){return flow.verify(email,otp);}
 @Transactional(timeout=10) public void password(String grant,String password){flow.password(grant,password);}
 static String digest(String value){return AccountActivationFlow.digest(value);}
}
