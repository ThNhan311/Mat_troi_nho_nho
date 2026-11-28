package vn.edu.tdtu.fitcenter.activation;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import java.net.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;
import static org.junit.jupiter.api.Assertions.*;

class SmtpActivationMailerTest {
    private static SmtpActivationMailer gmail(){return new SmtpActivationMailer("smtp.gmail.com",587,"sender@real-domain.test","abcd efgh ijkl mnop");}

    @Test void configurationRequiresEncryptedAuthenticatedSmtp(){
        var sender=gmail().sender();var p=sender.getJavaMailProperties();
        assertEquals("smtp.gmail.com",sender.getHost());assertEquals(587,sender.getPort());
        assertEquals("abcdefghijklmnop",sender.getPassword()); // grouping spaces removed
        assertEquals("true",p.get("mail.smtp.auth"));assertEquals("true",p.get("mail.smtp.starttls.required"));
        assertEquals("true",p.get("mail.smtp.ssl.checkserveridentity"));assertEquals("false",p.get("mail.debug"));
    }

    @Test void missingCredentialsFailAtStartup(){
        assertThrows(IllegalStateException.class,()->new SmtpActivationMailer("smtp.gmail.com",587,"","secret"));
        assertThrows(IllegalStateException.class,()->new SmtpActivationMailer("smtp.gmail.com",587,"sender@real-domain.test","   "));
    }

    @Test void rejectsUndeliverableAndInjectedRecipients(){
        for(String bad:List.of("hv01@example.invalid","a@real-domain.test\r\nBcc: x@real-domain.test","a@real-domain.test\n")){
            var failure=assertThrows(ActivationFailure.class,()->gmail().send(bad,"000000"));
            assertEquals("ERR_MAIL_RECIPIENT",failure.getCode());
        }
    }

    @Test void refusesToSendCredentialsOrCodeWithoutStartTls() throws Exception {
        try(var server=new ServerSocket(0,1,InetAddress.getLoopbackAddress());var executor=Executors.newSingleThreadExecutor()){
            var received=executor.submit(()->{
                var lines=new ArrayList<String>();
                try(var socket=server.accept();var reader=new BufferedReader(new InputStreamReader(socket.getInputStream(),StandardCharsets.US_ASCII));var writer=new PrintWriter(new OutputStreamWriter(socket.getOutputStream(),StandardCharsets.US_ASCII),true)){
                    socket.setSoTimeout(15000);writer.print("220 plain test server\r\n");writer.flush();
                    for(String line;(line=reader.readLine())!=null;){
                        lines.add(line);
                        if(line.equals("QUIT")){writer.print("221 bye\r\n");writer.flush();break;}
                        writer.print("250 localhost\r\n");writer.flush(); // never offers STARTTLS
                    }
                }
                return lines;
            });
            var mailer=new SmtpActivationMailer("127.0.0.1",server.getLocalPort(),"sender@real-domain.test","app-password");
            var failure=assertThrows(ActivationFailure.class,()->mailer.send("member@real-domain.test","123456"));
            assertEquals("ERR_MAIL_UNAVAILABLE",failure.getCode());
            var lines=received.get(5,TimeUnit.SECONDS);
            assertTrue(lines.stream().noneMatch(l->l.startsWith("AUTH")||l.equals("DATA")||l.contains("123456")),()->lines.toString());
        }
    }

    @Test void connectionFailureIsControlledAndDoesNotExposeOtp(){
        var failure=assertThrows(ActivationFailure.class,()->new SmtpActivationMailer("127.0.0.1",1,"sender@real-domain.test","app-password").send("member@real-domain.test","654321"));
        assertEquals(503,failure.getStatus());assertFalse(failure.getMessage().contains("654321"));
    }

    @Test void mailIsWrittenInVietnameseWithTheCodeAndWarning(){
        var message=gmail().message("member@real-domain.test","482913");
        assertEquals("FitCenter - Mã kích hoạt tài khoản",message.getSubject());
        assertTrue(message.getText().contains("Mã kích hoạt tài khoản FitCenter của bạn là: 482913"));
        assertTrue(message.getText().contains("5 phút"));assertTrue(message.getText().contains("không chia sẻ"));
        assertEquals("sender@real-domain.test",message.getFrom());
    }

    @Test void failureDescriptionKeepsTypesAndStatusButNeverAddresses(){
        var server=new IllegalStateException("550 5.7.1 member@real-domain.test rejected, code 123456");
        var description=SmtpActivationMailer.describe(new RuntimeException("could not send to member@real-domain.test",server));
        assertEquals("RuntimeException <- IllegalStateException[550 5.7.1]",description);
    }

    @Test void testSinkStaysDefaultAndRealSmtpMustBeEnabledExplicitly(){
        var runner=new ApplicationContextRunner().withUserConfiguration(TestSmtpActivationMailer.class,SmtpActivationMailer.class);
        runner.run(context->assertInstanceOf(TestSmtpActivationMailer.class,context.getBean(ActivationMailer.class)));
        runner.withPropertyValues("fitcenter.mail.smtp.enabled=true","FITCENTER_SMTP_USER=sender@real-domain.test","FITCENTER_SMTP_APP_PASSWORD=app-password")
                .run(context->assertInstanceOf(SmtpActivationMailer.class,context.getBean(ActivationMailer.class)));
    }
}
