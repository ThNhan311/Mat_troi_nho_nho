package vn.edu.tdtu.fitcenter.activation;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.stereotype.Component;
import java.util.ArrayList;
import java.util.Locale;
import java.util.Properties;
import java.util.regex.Pattern;

/** Real SMTP delivery (Gmail by default). Off unless fitcenter.mail.smtp.enabled=true; credentials come only from the environment. */
@Component
@ConditionalOnProperty(name="fitcenter.mail.smtp.enabled",havingValue="true")
public class SmtpActivationMailer implements ActivationMailer {
    private static final Logger log=LoggerFactory.getLogger(SmtpActivationMailer.class);
    private final JavaMailSenderImpl sender=new JavaMailSenderImpl();
    public SmtpActivationMailer(@Value("${fitcenter.mail.smtp.host:smtp.gmail.com}") String host,
            @Value("${fitcenter.mail.smtp.port:587}") int port,
            @Value("${FITCENTER_SMTP_USER:}") String username,
            @Value("${FITCENTER_SMTP_APP_PASSWORD:}") String password){
        String secret=password.replace(" ",""); // Google displays app passwords in groups of four.
        if(username.isBlank()||secret.isEmpty())throw new IllegalStateException("SMTP delivery is enabled but FITCENTER_SMTP_USER or FITCENTER_SMTP_APP_PASSWORD is missing");
        sender.setHost(host);sender.setPort(port);sender.setUsername(username.trim());sender.setPassword(secret);sender.setDefaultEncoding("UTF-8");
        var properties=new Properties();
        // STARTTLS is mandatory: never send credentials or codes over a plain connection.
        properties.put("mail.smtp.auth","true");properties.put("mail.smtp.starttls.enable","true");properties.put("mail.smtp.starttls.required","true");properties.put("mail.smtp.ssl.checkserveridentity","true");
        properties.put("mail.smtp.connectiontimeout","10000");properties.put("mail.smtp.timeout","10000");properties.put("mail.smtp.writetimeout","10000");properties.put("mail.debug","false");
        sender.setJavaMailProperties(properties);
    }
    JavaMailSenderImpl sender(){return sender;}
    SimpleMailMessage message(String email,String otp){
        var message=new SimpleMailMessage();message.setFrom(sender.getUsername());message.setTo(email);
        message.setSubject("FitCenter - Mã kích hoạt tài khoản");
        message.setText("Xin chào,\n\nMã kích hoạt tài khoản FitCenter của bạn là: "+otp
                +"\n\nMã có hiệu lực trong 5 phút. Vui lòng không chia sẻ mã này cho bất kỳ ai."
                +"\nNếu bạn không yêu cầu mã này, hãy bỏ qua email.\n\nFitCenter");
        return message;
    }
    private static final Pattern SMTP_STATUS=Pattern.compile("^\\s*([245]\\d\\d)(?:[ -]([245]\\.\\d{1,3}\\.\\d{1,3}))?");
    /** Exception types and SMTP status numbers only: server and library messages can contain addresses. */
    static String describe(Throwable failure){
        if(failure instanceof org.springframework.mail.MailSendException send&&send.getCause()==null&&send.getMessageExceptions().length>0)failure=send.getMessageExceptions()[0];
        var parts=new ArrayList<String>();
        for(Throwable t=failure;t!=null&&parts.size()<6;t=t.getCause()){
            var status=SMTP_STATUS.matcher(String.valueOf(t.getMessage()));
            parts.add(t.getClass().getSimpleName()+(status.find()?"["+status.group(1)+(status.group(2)==null?"":" "+status.group(2))+"]":""));
        }
        return String.join(" <- ",parts);
    }
    SimpleMailMessage resetMessage(String email,String otp){
        var message=new SimpleMailMessage();message.setFrom(sender.getUsername());message.setTo(email);
        message.setSubject("FitCenter - Mã đặt lại mật khẩu");
        message.setText("Xin chào,\n\nMã đặt lại mật khẩu FitCenter của bạn là: "+otp
                +"\n\nMã có hiệu lực trong 5 phút. Vui lòng không chia sẻ mã này cho bất kỳ ai."
                +"\nNếu bạn không yêu cầu mã này, hãy bỏ qua email, mật khẩu của bạn không thay đổi.\n\nFitCenter");
        return message;
    }
    @Override public void send(String email,String otp){deliver(email,message(email,otp));}
    @Override public void sendPasswordReset(String email,String otp){deliver(email,resetMessage(email,otp));}
    private void deliver(String email,SimpleMailMessage message){
        String lower=email.toLowerCase(Locale.ROOT);
        if(lower.endsWith(".invalid")||email.contains("\r")||email.contains("\n"))throw new ActivationFailure(503,"ERR_MAIL_RECIPIENT","Recipient address cannot receive mail");
        try{sender.send(message);}
        catch(org.springframework.mail.MailException e){
            log.warn("Activation mail delivery failed: {} cause={}",e.getClass().getSimpleName(),describe(e)); // never log recipient, code or SMTP dialogue
            throw new ActivationFailure(503,"ERR_MAIL_UNAVAILABLE","Mail delivery unavailable");
        }
    }
}
