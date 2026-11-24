package vn.edu.tdtu.fitcenter.enrollment;
import java.util.UUID;
/** External durable staging. This is not part of the business DB transaction. */
public interface EnrollmentAdapter {
 record Prepared(UUID operation,UUID member,UUID profile,String reference,boolean ready,long generation) { public Prepared(UUID operation,UUID member,UUID profile,String reference,boolean ready){this(operation,member,profile,reference,ready,0);} }
 boolean enabled();
 Prepared prepare(UUID operation,UUID member,UUID profile,String reference);
 default Prepared prepare(UUID operation,UUID member,UUID profile,String reference,String predecessor){return prepare(operation,member,profile,reference);}
 default void finalizeEnrollment(UUID operation,UUID member,UUID profile,String reference) {}
 default String identify(UUID request,UUID capture){return identify(capture);}
 void remove(String reference);
 String identify(UUID opaqueCapture);
}
