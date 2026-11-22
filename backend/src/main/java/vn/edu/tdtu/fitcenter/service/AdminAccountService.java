package vn.edu.tdtu.fitcenter.service;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.tdtu.fitcenter.domain.entity.*;
import vn.edu.tdtu.fitcenter.domain.enums.*;
import vn.edu.tdtu.fitcenter.dto.account.*;
import vn.edu.tdtu.fitcenter.repository.*;
import java.security.SecureRandom;
import java.util.*;

@Service @RequiredArgsConstructor
public class AdminAccountService {
    private final UserRepository users;
    private final MemberRepository members;
    private final PersonalTrainerRepository pts;
    private final PasswordEncoder encoder;
    private final JdbcTemplate jdbc;
    private UUID actor(String email) {
        var actor=users.findByEmailIgnoreCase(email).orElseThrow(()->new BadCredentialsException("Unknown actor"));
        if(actor.getRole()!=Role.ADMIN || actor.getStatus()!=AccountStatus.ACTIVE || !users.existsByIdAndRoleAndStatus(actor.getId(),Role.ADMIN,AccountStatus.ACTIVE))throw new AccessDeniedException("ACTIVE ADMIN required");
        return actor.getId();
    }
    @Transactional(timeout=10)
    public AccountResponse create(String actorEmail, Role role, AccountCreateRequest request) {
        UUID admin=actor(actorEmail);
        if(role!=Role.MEMBER && role!=Role.PT)throw new IllegalArgumentException("Only Member/PT creation");
        byte[] random=new byte[32];new SecureRandom().nextBytes(random);
        var user=users.saveAndFlush(User.builder().email(request.email().trim()).role(role).status(AccountStatus.DISABLED)
                .passwordHash(encoder.encode(Base64.getUrlEncoder().withoutPadding().encodeToString(random))).build());
        UUID profile=role==Role.MEMBER
                ? members.saveAndFlush(Member.builder().user(user).fullName(request.fullName()).build()).getId()
                : pts.saveAndFlush(PersonalTrainer.builder().user(user).fullName(request.fullName()).build()).getId();
        jdbc.update("INSERT INTO audit_logs(actor_user_id,actor_type,action,entity_type,entity_id,details) VALUES(?,'USER','ACCOUNT_CREATED_PENDING_ACTIVATION','USER',?,jsonb_build_object('role',?::text))",admin,user.getId(),role.name());
        return new AccountResponse(user.getId(),profile,user.getEmail(),request.fullName(),role.name(),"DISABLED",true);
    }
    @Transactional(readOnly=true)
    public List<AccountResponse> list(String actorEmail,Role role) {
        actor(actorEmail);
        String table=switch(role){case MEMBER->"members";case PT->"personal_trainers";default->throw new IllegalArgumentException();};
        return jdbc.query("SELECT u.id user_id,p.id profile_id,u.email,p.full_name,u.role,u.status,(u.status='DISABLED' AND EXISTS(SELECT 1 FROM audit_logs a WHERE a.entity_type='USER' AND a.entity_id=u.id AND a.action='ACCOUNT_CREATED_PENDING_ACTIVATION') AND NOT EXISTS(SELECT 1 FROM audit_logs a WHERE a.entity_type='USER' AND a.entity_id=u.id AND a.action='PT_ACCOUNT_ACTIVATED')) pending FROM users u JOIN "+table+" p ON p.user_id=u.id WHERE u.role=? ORDER BY p.full_name,u.id",
                (r,i)->new AccountResponse(r.getObject("user_id",UUID.class),r.getObject("profile_id",UUID.class),r.getString("email"),r.getString("full_name"),r.getString("role"),r.getString("status"),r.getBoolean("pending")),role.name());
    }
}