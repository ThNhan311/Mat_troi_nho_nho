package vn.edu.tdtu.fitcenter.checkin;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.*;
import java.util.*;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.*;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.ObjectMapper;
import vn.edu.tdtu.fitcenter.renewal.MembershipPeriodService;

@Service
public final class CheckinService {
    private static final ZoneId BUSINESS_ZONE=ZoneId.of("Asia/Ho_Chi_Minh");
    private final JdbcTemplate jdbc;
    private final ObjectMapper json;
    private final Clock clock;
    private final FaceVerificationAdapter adapter;
    private final MembershipPeriodService periods;
    private final TransactionTemplate write,read;
    private record Eligibility(Instant checkedAt,String denial) {}

    public CheckinService(JdbcTemplate jdbc,ObjectMapper json,Clock clock,FaceVerificationAdapter adapter,
            MembershipPeriodService periods,PlatformTransactionManager manager) {
        this.jdbc=jdbc;this.json=json;this.clock=clock;this.adapter=adapter;this.periods=periods;
        write=new TransactionTemplate(manager);write.setIsolationLevel(TransactionDefinition.ISOLATION_READ_COMMITTED);write.setTimeout(10);
        read=new TransactionTemplate(manager);read.setReadOnly(true);read.setIsolationLevel(TransactionDefinition.ISOLATION_REPEATABLE_READ);read.setTimeout(10);
    }
    private Instant now() { return clock.instant().truncatedTo(java.time.temporal.ChronoUnit.MICROS); }
    private static String hash(String payload) {
        try{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(payload.getBytes(StandardCharsets.UTF_8)));}
        catch(Exception ex){throw new IllegalStateException("Digest unavailable");}
    }
    private static LocalDate date(Object value) { return value==null?null:((java.sql.Date)value).toLocalDate(); }
    private static Instant instant(Object value) { return value==null?null:((java.sql.Timestamp)value).toInstant(); }
    private Map<String,Object> response(CheckinRequest request,boolean recognized,boolean allowed,boolean created,
            UUID member,UUID attendance,Instant checkedInAt,Instant checkedAt,String reason,boolean replayed) {
        var dto=new LinkedHashMap<String,Object>();
        dto.put("requestId",request.requestId());dto.put("recognized",recognized);dto.put("accessAllowed",allowed);
        dto.put("attendanceCreated",created);dto.put("memberId",member);dto.put("attendanceId",attendance);
        dto.put("checkedAt",checkedAt.toString());dto.put("checkedInAt",checkedInAt==null?null:checkedInAt.toString());
        dto.put("reason",reason);dto.put("replayed",replayed);dto.put("simulatedIdentity",true);dto.put("verificationMode","SIMULATED_TEST");
        return dto;
    }
    private void save(String kiosk,CheckinRequest request,String fingerprint,UUID member,UUID profile,Map<String,Object> dto) {
        jdbc.update("INSERT INTO checkin_requests(request_id,kiosk_id,request_fingerprint,member_id,facial_profile_id,attendance_id,attendance_created,identity_mode,decision,checked_at,response_snapshot) VALUES(?,?,?,?,?,?,?,'SIMULATED_TEST',?,?,?::jsonb)",
                request.requestId(),kiosk,fingerprint,member,profile,dto.get("attendanceId"),dto.get("attendanceCreated"),dto.get("reason"),OffsetDateTime.parse((String)dto.get("checkedAt")),json.writeValueAsString(dto));
    }
    /** All business row locks are Member -> Membership -> FacialProfile; no User row lock. */
    private Eligibility eligibility(UUID member,UUID profile) {
        var members=jdbc.queryForList("SELECT user_id FROM members WHERE id=? FOR NO KEY UPDATE",member);
        if(members.isEmpty())return new Eligibility(now(),"UNKNOWN_IDENTITY");
        var memberships=jdbc.queryForList("SELECT id,start_date,expiry_date,status FROM memberships WHERE member_id=? AND status<>'CANCELLED' ORDER BY id FOR UPDATE",member);
        var profiles=jdbc.queryForList("SELECT status FROM facial_profiles WHERE id=? AND member_id=? FOR SHARE",profile,member);
        var users=jdbc.queryForList("SELECT status,role FROM users WHERE id=?",members.getFirst().get("user_id"));
        // Read the decision time only after every wait above has completed.
        Instant now=now();LocalDate today=LocalDate.ofInstant(now,BUSINESS_ZONE);
        if(profiles.isEmpty()||!"ACTIVE".equals(profiles.getFirst().get("status")))return new Eligibility(now,"FACE_PROFILE_INACTIVE");
        if(users.size()!=1||!"MEMBER".equals(users.getFirst().get("role"))||!"ACTIVE".equals(users.getFirst().get("status")))return new Eligibility(now,"ACCOUNT_INACTIVE");
        for(var m:memberships) {
            LocalDate start=date(m.get("start_date")),end=date(m.get("expiry_date"));
            if(!"ACTIVE".equals(m.get("status"))||start==null||end==null||today.isBefore(start)||today.isAfter(end))continue;
            if(periods.enabled()&&periods.covered((UUID)m.get("id"),today,today))return new Eligibility(now,null);
            return new Eligibility(now,"PAID_COVERAGE_MISSING");
        }
        return new Eligibility(now,"MEMBERSHIP_INACTIVE");
    }
    public Map<String,Object> checkin(String kiosk,CheckinRequest request) {
        adapter.requireEnabled();String fingerprint=hash("F01-v1|"+kiosk+"|"+request.captureRef());
        try{return write.execute(status->{
            // Technical request guard precedes business locks; no other writer acquires it.
            jdbc.queryForList("SELECT pg_advisory_xact_lock(hashtextextended(?,0))","F01:"+request.requestId());
            var previous=jdbc.queryForList("SELECT member_id,facial_profile_id,attendance_id,decision,request_fingerprint FROM checkin_requests WHERE request_id=?",request.requestId());
            boolean replay=!previous.isEmpty();UUID member=null,profile=null;
            if(replay) {
                var old=previous.getFirst();
                if(!fingerprint.equals(old.get("request_fingerprint")))throw new CheckinFailure(409,"ERR_CHECKIN_REQUEST_REUSED","Request ID belongs to another payload or kiosk");
                member=(UUID)old.get("member_id");profile=(UUID)old.get("facial_profile_id");
                if(member==null)return response(request,false,false,false,null,null,null,now(),(String)old.get("decision"),true);
            } else {
                var identity=adapter.verify(request.captureRef());
                if(!identity.outcome().equals("MATCHED")) {
                    var dto=response(request,false,false,false,null,null,null,now(),identity.outcome().equals("NO_MATCH")?"NO_MATCH":"UNKNOWN_IDENTITY",false);
                    save(kiosk,request,fingerprint,null,null,dto);return dto;
                }
                var link=jdbc.queryForList("SELECT member_id FROM facial_profiles WHERE id=?",identity.profileId());
                if(link.isEmpty()) {
                    var dto=response(request,false,false,false,null,null,null,now(),"UNKNOWN_IDENTITY",false);
                    save(kiosk,request,fingerprint,null,null,dto);return dto;
                }
                member=(UUID)link.getFirst().get("member_id");profile=identity.profileId();
            }
            var access=eligibility(member,profile);
            if(access.denial()!=null) {
                var dto=response(request,!Set.of("UNKNOWN_IDENTITY","FACE_PROFILE_INACTIVE").contains(access.denial()),false,false,member,null,null,access.checkedAt(),access.denial(),replay);
                if(!replay)save(kiosk,request,fingerprint,member,profile,dto);return dto;
            }
            if(replay) {
                if(!Set.of("CHECKED_IN","DUPLICATE_WINDOW").contains(previous.getFirst().get("decision")))
                    return response(request,true,false,false,member,null,null,access.checkedAt(),"REQUEST_PREVIOUSLY_DENIED",true);
                UUID attendance=(UUID)previous.getFirst().get("attendance_id");
                Instant recorded=attendance==null?null:jdbc.queryForObject("SELECT checked_in_at FROM attendance_records WHERE id=? AND member_id=?",java.sql.Timestamp.class,attendance,member).toInstant();
                return response(request,true,true,false,member,attendance,recorded,access.checkedAt(),"REQUEST_REPLAY",true);
            }
            var last=jdbc.queryForList("SELECT id,checked_in_at FROM attendance_records WHERE member_id=? ORDER BY checked_in_at DESC,id DESC LIMIT 1",member);
            Map<String,Object> dto;
            if(!last.isEmpty()&&access.checkedAt().isBefore(instant(last.getFirst().get("checked_in_at")).plus(Duration.ofMinutes(30)))) {
                dto=response(request,true,true,false,member,(UUID)last.getFirst().get("id"),instant(last.getFirst().get("checked_in_at")),access.checkedAt(),"DUPLICATE_WINDOW",false);
            } else {
                UUID attendance=UUID.randomUUID();
                jdbc.update("INSERT INTO attendance_records(id,member_id,checked_in_at,source,kiosk_id,dedupe_key) VALUES(?,?,?,'FACE',?,?)",attendance,member,OffsetDateTime.ofInstant(access.checkedAt(),ZoneOffset.UTC),kiosk,"f01:"+member+":"+request.requestId());
                dto=response(request,true,true,true,member,attendance,access.checkedAt(),access.checkedAt(),"CHECKED_IN",false);
            }
            save(kiosk,request,fingerprint,member,profile,dto);return dto;
        });}catch(DataIntegrityViolationException ex){throw new CheckinFailure(409,"ERR_CHECKIN_CONFLICT","Check-in conflict; reconcile using the same request ID");}
    }
    public List<Map<String,Object>> history(String email,OffsetDateTime from,OffsetDateTime to) {
        if(!from.toInstant().isBefore(to.toInstant()))throw new CheckinFailure(400,"ERR_VALIDATION","from must precede to");
        return read.execute(status->{
            var owners=jdbc.queryForList("SELECT m.id FROM members m JOIN users u ON u.id=m.user_id WHERE lower(u.email)=lower(?) AND u.role='MEMBER' AND u.status='ACTIVE'",email);
            if(owners.size()!=1)throw new AccessDeniedException("ACTIVE Member profile required");
            String mode=adapter.enabled()?"coalesce(q.identity_mode,'UNVERIFIED_LEGACY')":"'UNVERIFIED_LEGACY'";
            String join=adapter.enabled()?" LEFT JOIN checkin_requests q ON q.attendance_id=a.id AND q.attendance_created ":" ";
            return jdbc.queryForList("SELECT a.id,a.checked_in_at,a.source,a.kiosk_id,"+mode+" verification_mode FROM attendance_records a"+join+"WHERE a.member_id=? AND a.checked_in_at>=? AND a.checked_in_at<? ORDER BY a.checked_in_at DESC,a.id DESC",owners.getFirst().get("id"),from,to).stream().map(r->{
                var dto=new LinkedHashMap<String,Object>();dto.put("id",r.get("id"));dto.put("checkedInAt",instant(r.get("checked_in_at")).toString());dto.put("source",r.get("source"));dto.put("kioskId",r.get("kiosk_id"));dto.put("verificationMode",r.get("verification_mode"));return (Map<String,Object>)dto;
            }).toList();
        });
    }
}
