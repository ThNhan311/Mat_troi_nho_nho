package vn.edu.tdtu.fitcenter;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.tdtu.fitcenter.domain.entity.*;
import vn.edu.tdtu.fitcenter.domain.enums.*;
import vn.edu.tdtu.fitcenter.repository.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@Transactional
@EnabledIfEnvironmentVariable(named = "RUN_DB_TESTS", matches = "true")
class DatabaseAlignmentTest {
    @Autowired UserRepository users;
    @Autowired MemberRepository members;
    @Autowired MembershipRepository memberships;
    @Autowired MembershipPlanRepository plans;
    @Autowired PersonalTrainerRepository trainers;
    @Autowired EntityManager entityManager;
    @Autowired JdbcTemplate jdbc;

    @Test void canonicalSchemaIsApplied() {
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM flyway_schema_history WHERE version='6' AND success", Integer.class));
        if (getClass().getResource("/db/migration/V7__membership_periods.sql") == null) return;
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM flyway_schema_history WHERE version='7' AND success", Integer.class));
        assertNotNull(jdbc.queryForObject("SELECT to_regclass('membership_periods')::text", String.class));
        assertNotNull(jdbc.queryForObject("SELECT to_regclass('v_membership_overview')::text", String.class));
    }

    @Test void generatedIdsAndDatabaseManagedTimestampsWorkOnInsert() {
        User user = users.saveAndFlush(User.builder().email("case-" + UUID.randomUUID() + "@test.local")
                .passwordHash("test-hash").role(Role.MEMBER).status(AccountStatus.ACTIVE).build());
        assertNotNull(user.getId());
        Member member = members.saveAndFlush(Member.builder().user(user).fullName("Member").build());
        MembershipPlan plan = plans.saveAndFlush(MembershipPlan.builder().name("Test").durationDays(30)
                .price(BigDecimal.TEN).status(MembershipPlanStatus.ACTIVE).build());
        Membership membership = memberships.saveAndFlush(Membership.builder().member(member).plan(plan)
                .startDate(LocalDate.of(2026, 11, 5)).expiryDate(LocalDate.of(2026, 12, 4))
                .status(MembershipStatus.ACTIVE).build());
        UUID memberId = member.getId();
        assertNotNull(plan.getId());
        assertNotNull(membership.getId());
        entityManager.clear();
        Member reloaded = members.findById(memberId).orElseThrow();
        assertNotNull(reloaded.getCreatedAt());
        assertNotNull(reloaded.getUpdatedAt());
    }

    @Test void emailLookupMatchesCaseInsensitiveUniqueIndex() {
        String email = "Mixed-" + UUID.randomUUID() + "@Example.Com";
        User user = users.saveAndFlush(User.builder().email(email).passwordHash("test-hash")
                .role(Role.MEMBER).status(AccountStatus.ACTIVE).build());
        assertEquals(user.getId(), users.findByEmailIgnoreCase(email.toLowerCase(java.util.Locale.ROOT))
                .orElseThrow().getId());
        assertTrue(users.existsByEmailIgnoreCase(email.toUpperCase(java.util.Locale.ROOT)));
    }

    @Test void suspendedTrainerIsExcludedFromCatalogueAndLookup() {
        User user = users.saveAndFlush(User.builder().email("pt-" + UUID.randomUUID() + "@test.local")
                .passwordHash("test-hash").role(Role.PT).status(AccountStatus.SUSPENDED).build());
        PersonalTrainer trainer = trainers.saveAndFlush(PersonalTrainer.builder()
                .user(user).fullName("Suspended PT").build());
        assertTrue(trainers.findByIdAndUser_Status(trainer.getId(), AccountStatus.ACTIVE).isEmpty());
        assertTrue(trainers.findByUser_StatusOrderByFullNameAsc(AccountStatus.ACTIVE)
                .stream().noneMatch(p -> p.getId().equals(trainer.getId())));
    }
}
