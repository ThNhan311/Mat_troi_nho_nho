package vn.edu.tdtu.fitcenter.activation;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.stereotype.Component;
import java.util.Properties;

/** Dev/test transport only. Never connects outside loopback or sends to real recipients. */
@Component
public class TestSmtpActivationMailer implements ActivationMailer {
    private final int port;
    public TestSmtpActivationMailer(@Value("${fitcenter.activation.test-smtp-port:1025}") int port){this.port=port;}
    @Override public void send(String email,String otp){
        if(!email.toLowerCase(java.util.Locale.ROOT).endsWith("@example.invalid")||email.contains("\r")||email.contains("\n"))throw new ActivationFailure(503,"ERR_TEST_MAIL_ONLY","Only synthetic test recipients are enabled");
        var sender=new JavaMailSenderImpl();sender.setHost("127.0.0.1");sender.setPort(port);
        var properties=new Properties();properties.put("mail.smtp.connectiontimeout","2000");properties.put("mail.smtp.timeout","2000");properties.put("mail.smtp.writetimeout","2000");properties.put("mail.debug","false");properties.put("mail.smtp.localhost","localhost");sender.setJavaMailProperties(properties);
        var message=new SimpleMailMessage();message.setFrom("fitcenter-test@example.invalid");message.setTo(email);message.setSubject("FitCenter account activation");message.setText("Your one-time activation code: "+otp+"\nValid for 5 minutes. Do not share it.");
        try{sender.send(message);}catch(org.springframework.mail.MailException e){throw new ActivationFailure(503,"ERR_TEST_MAIL_UNAVAILABLE","Test mail delivery unavailable");}
    }
}
