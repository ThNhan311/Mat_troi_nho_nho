package vn.edu.tdtu.fitcenter.activation;
import org.junit.jupiter.api.Test;
import java.net.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.*;
import static org.junit.jupiter.api.Assertions.*;

class TestSmtpActivationMailerTest {
    @Test void deliversOnlyToInMemoryLoopbackSinkWithoutLoggingBody() throws Exception {
        try(var server=new ServerSocket(0,1,InetAddress.getLoopbackAddress());var executor=Executors.newSingleThreadExecutor()){
            var received=executor.submit(()->{
                try(var socket=server.accept();var reader=new BufferedReader(new InputStreamReader(socket.getInputStream(),StandardCharsets.US_ASCII));var writer=new PrintWriter(new OutputStreamWriter(socket.getOutputStream(),StandardCharsets.US_ASCII),true)){
                    socket.setSoTimeout(15000);writer.print("220 loopback test sink\r\n");writer.flush();StringBuilder data=new StringBuilder();boolean body=false;
                    for(String line;(line=reader.readLine())!=null;){
                        if(body){if(line.equals(".")){body=false;writer.print("250 queued in memory\r\n");writer.flush();}else data.append(line).append('\n');}
                        else if(line.startsWith("EHLO")||line.startsWith("HELO")){writer.print("250 localhost\r\n");writer.flush();}
                        else if(line.equals("DATA")){writer.print("354 send body\r\n");writer.flush();body=true;}
                        else if(line.equals("QUIT")){writer.print("221 bye\r\n");writer.flush();break;}
                        else {writer.print("250 OK\r\n");writer.flush();}
                    }
                    return data.toString();
                }
            });
            String syntheticCode=String.format("%06d",new java.security.SecureRandom().nextInt(1_000_000));
            new TestSmtpActivationMailer(server.getLocalPort()).send("pt-synthetic@example.invalid",syntheticCode);
            String body=received.get(5,TimeUnit.SECONDS);
            assertTrue(body.contains("Your one-time activation code: "+syntheticCode)); // body never written to disk/stdout
            assertTrue(body.contains("5 minutes"));assertFalse(body.contains("password"));
        }
    }
    @Test void rejectsRealRecipientsBeforeOpeningAnyConnection(){
        var sender=new TestSmtpActivationMailer(1);
        var failure=assertThrows(ActivationFailure.class,()->sender.send("do-not-send@real-domain.test","000000"));
        assertEquals("ERR_TEST_MAIL_ONLY",failure.getCode());
    }
    @Test void connectionFailureIsControlledAndDoesNotExposeOtp(){
        var failure=assertThrows(ActivationFailure.class,()->new TestSmtpActivationMailer(1).send("pt@example.invalid","000000"));
        assertEquals(503,failure.getStatus());assertFalse(failure.getMessage().contains("000000"));
    }
}