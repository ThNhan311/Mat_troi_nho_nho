package vn.edu.tdtu.fitcenter.enrollment;
import java.util.UUID;
/** External durable staging. This is not part of the business DB transaction. */
public interface EnrollmentAdapter {
 record Prepared(UUID operation,UUID member,UUID profile,String reference,boolean ready) {}
 boolean enabled();
 Prepared prepare(UUID operation,UUID member,UUID profile,String reference);
 void remove(String reference);
 String identify(UUID opaqueCapture);
}
