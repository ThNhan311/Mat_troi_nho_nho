package vn.edu.tdtu.fitcenter.activation;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.time.*;
import java.util.*;
@Service
public class PtActivationService {
    private final ActivationStore store; private final ActivationMailer mailer; private final PasswordEncoder encoder;
    private final Clock clock; private final boolean enabled;
    private final SecureRandom random=new SecureRandom();
    public PtActivationService(ActivationStore store,ActivationMailer mailer,PasswordEncoder encoder,Clock clock,@Value("${fitcenter.activation.enabled:false}") boolean enabled){this.store=store;this.mailer=mailer;this.encoder=encoder;this.clock=clock;this.enabled=enabled;}
    private void ready(){if(!enabled)throw new ActivationFailure(503,"ERR_ACTIVATION_NOT_READY","PT activation awaits approved schema");}
    private boolean eligible(ActivationStore.Account a){return a!=null&&a.role().equals("PT")&&a.status().equals("DISABLED")&&a.pending();}
    private ActivationFailure invalid(){return new ActivationFailure(400,"ERR_ACTIVATION_INVALID","Activation details are invalid");}
    @Transactional(timeout=10)
    public void request(String email){
        ready();var id=store.findUser(email.trim());if(id.isEmpty())return;
        var a=store.lockUser(id.get());if(!eligible(a))return;
        var s=store.lockState(a.id());Instant now=clock.instant();
        if(s!=null&&s.completedAt!=null)return;
        if(s!=null&&now.isBefore(s.lastSentAt.plusSeconds(60)))throw new ActivationFailure(429,"ERR_OTP_RESEND_TOO_SOON","Wait before requesting another code");
        if(s==null){s=new ActivationStore.State();s.userId=a.id();s.windowStartedAt=now;}
        if(!now.isBefore(s.windowStartedAt.plusSeconds(3600))){s.windowStartedAt=now;s.sendCount=0;}
        if(s.sendCount>=5)throw new ActivationFailure(429,"ERR_OTP_SEND_LIMIT","Code request limit reached");
        String otp=String.format(Locale.ROOT,"%06d",random.nextInt(1_000_000));
        s.otpDigest=encoder.encode(otp);s.otpExpiresAt=now.plusSeconds(300);s.attempts=0;s.grantDigest=null;s.grantExpiresAt=null;s.lastSentAt=now;s.sendCount++;
        store.save(s);mailer.send(a.email(),otp); // mail failure rolls back DB state; never log OTP or SMTP body.
    }
    @Transactional(timeout=10,noRollbackFor=ActivationFailure.class)
    public String verify(String email,String otp){
        ready();UUID id=store.findUser(email.trim()).orElseThrow(this::invalid);
        var a=store.lockUser(id);if(!eligible(a))throw invalid();var s=store.lockState(id);Instant now=clock.instant();
        if(s==null||s.completedAt!=null)throw invalid();
        if(s.otpDigest==null)throw new ActivationFailure(409,"ERR_OTP_ALREADY_USED","Request a new code");
        if(!now.isBefore(s.otpExpiresAt))throw new ActivationFailure(400,"ERR_OTP_EXPIRED","Code expired");
        if(s.attempts>=5)throw new ActivationFailure(429,"ERR_OTP_ATTEMPT_LIMIT","Code attempt limit reached");
        if(!encoder.matches(otp,s.otpDigest)){s.attempts++;store.save(s);throw invalid();} // commit failed-attempt count
        byte[] bytes=new byte[32];random.nextBytes(bytes);String grant=Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        s.otpDigest=null;s.otpExpiresAt=null;s.grantDigest=digest(grant);s.grantExpiresAt=now.plusSeconds(300);store.save(s);return grant;
    }
    @Transactional(timeout=10)
    public void password(String grant,String password){
        ready();if(password==null||password.codePointCount(0,password.length())<8||password.getBytes(StandardCharsets.UTF_8).length>72||password.isBlank())throw new ActivationFailure(400,"ERR_VALIDATION","Password requires at least 8 characters and at most 72 UTF-8 bytes");
        String hash=digest(grant);UUID id=store.findGrant(hash).orElseThrow(this::invalid);
        var a=store.lockUser(id);if(!eligible(a))throw invalid();var s=store.lockState(id);Instant now=clock.instant();
        if(s==null||s.completedAt!=null||!hash.equals(s.grantDigest)||!now.isBefore(s.grantExpiresAt))throw invalid();
        store.activate(id,encoder.encode(password));s.completedAt=now;s.grantDigest=null;s.grantExpiresAt=null;s.otpDigest=null;s.otpExpiresAt=null;store.save(s);
    }
    static String digest(String value){try{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));}catch(NoSuchAlgorithmException e){throw new IllegalStateException(e);}}
}