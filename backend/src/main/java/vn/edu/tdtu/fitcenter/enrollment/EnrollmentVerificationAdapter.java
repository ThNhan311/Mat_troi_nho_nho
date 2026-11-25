package vn.edu.tdtu.fitcenter.enrollment;
import java.util.UUID;import org.springframework.context.annotation.Primary;import org.springframework.stereotype.Component;import org.springframework.jdbc.core.JdbcTemplate;import vn.edu.tdtu.fitcenter.checkin.*;
/** Resolve only server-side adapter attestations; no template/member input from public clients. */
@Component @Primary public final class EnrollmentVerificationAdapter implements FaceVerificationAdapter {
 private final FaceTestAdapter core;private final EnrollmentAdapter enrollment;private final JdbcTemplate jdbc;
 public EnrollmentVerificationAdapter(FaceTestAdapter core,EnrollmentAdapter enrollment,JdbcTemplate jdbc){this.core=core;this.enrollment=enrollment;this.jdbc=jdbc;}
 public boolean enabled(){return core.enabled();}public void requireEnabled(){core.requireEnabled();}
 public Identity verify(UUID capture){return verify(null,capture);}
 public Identity verify(UUID request,UUID capture){var first=core.verify(capture);if(!first.outcome().equals("UNKNOWN")||!enrollment.enabled())return first;
  String ref=enrollment.identify(request,capture);if(ref==null)return first;
  var rows=jdbc.queryForList("SELECT f.id FROM facial_profiles f JOIN face_enrollments e ON e.activated_profile_id=f.id AND e.member_id=f.member_id AND e.template_ref=f.template_ref WHERE e.template_ref=?",UUID.class,ref);
  return rows.size()==1?new Identity("MATCHED",rows.getFirst()):new Identity("UNKNOWN",null);
 }
}
