package vn.edu.tdtu.fitcenter.http;

import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.regex.Pattern;

/** Actual SMTP protocol, loopback only; code/body remain in memory, never stdout/disk. */
final class ActivationLoopbackMailSink implements AutoCloseable {
    private final ServerSocket server;
    private final ExecutorService loop=Executors.newSingleThreadExecutor();
    private final Map<String,BlockingQueue<String>> codes=new ConcurrentHashMap<>();
    final AtomicBoolean failNext=new AtomicBoolean();
    private volatile boolean closed;
    ActivationLoopbackMailSink(){try{server=new ServerSocket(0,20,InetAddress.getByName("127.0.0.1"));loop.submit(()->{while(!closed){try{serve(server.accept());}catch(IOException e){if(!closed)throw new UncheckedIOException(e);}}});}catch(IOException e){throw new IllegalStateException("Cannot start mail sink");}}
    int port(){return server.getLocalPort();}
    private void serve(Socket socket) throws IOException {
        try(socket;var in=new BufferedReader(new InputStreamReader(socket.getInputStream(),StandardCharsets.US_ASCII));var out=new PrintWriter(new OutputStreamWriter(socket.getOutputStream(),StandardCharsets.US_ASCII),true)){
            socket.setSoTimeout(15000);reply(out,"220 loopback SMTP test sink");String recipient=null;StringBuilder body=new StringBuilder();boolean data=false;
            for(String line;(line=in.readLine())!=null;){
                if(data){if(line.equals(".")){data=false;if(failNext.getAndSet(false)){reply(out,"550 controlled test delivery failure");}else{var m=Pattern.compile("activation code: ([0-9]{6})").matcher(body);if(recipient==null||!recipient.endsWith("@example.invalid")||!m.find()){reply(out,"550 synthetic message required");}else{codes.computeIfAbsent(recipient,k->new LinkedBlockingQueue<>()).add(m.group(1));reply(out,"250 queued in memory");}}}else body.append(line).append('\n');}
                else if(line.startsWith("RCPT TO:")){recipient=line.substring(line.indexOf('<')+1,line.indexOf('>')).toLowerCase(Locale.ROOT);reply(out,"250 OK");}
                else if(line.equals("DATA")){data=true;reply(out,"354 send body");}
                else if(line.equals("QUIT")){reply(out,"221 bye");break;}
                else reply(out,"250 localhost");
            }
        }
    }
    private void reply(PrintWriter out,String text){out.print(text+"\r\n");out.flush();}
    String take(String email){try{String code=codes.computeIfAbsent(email.toLowerCase(Locale.ROOT),k->new LinkedBlockingQueue<>()).poll(10,TimeUnit.SECONDS);if(code==null)throw new IllegalStateException("No synthetic SMTP delivery");return code;}catch(InterruptedException e){Thread.currentThread().interrupt();throw new IllegalStateException("Mail wait interrupted");}}
    boolean empty(String email){return codes.computeIfAbsent(email.toLowerCase(Locale.ROOT),k->new LinkedBlockingQueue<>()).isEmpty();}
    @Override public void close(){closed=true;try{server.close();}catch(IOException ignored){}loop.shutdownNow();codes.clear();}
}
