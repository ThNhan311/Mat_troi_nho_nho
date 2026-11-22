package vn.edu.tdtu.fitcenter.service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.entity.MembershipPlan;
import vn.edu.tdtu.fitcenter.domain.enums.*;
import vn.edu.tdtu.fitcenter.dto.membership.MembershipPlanCreateRequest;
import vn.edu.tdtu.fitcenter.repository.*;
import java.util.*;
import java.math.BigDecimal;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class MembershipPlanCreateServiceTest {
    private final UserRepository users = mock(UserRepository.class);
    private final MembershipPlanRepository plans = mock(MembershipPlanRepository.class);
    private final MembershipPlanCreateService service = new MembershipPlanCreateService(users, plans);
    private final User admin = User.builder().id(UUID.randomUUID()).email("m01-unit@example.invalid").role(Role.ADMIN).status(AccountStatus.ACTIVE).build();
    private final MembershipPlanCreateRequest request = new MembershipPlanCreateRequest("Plan", null, 37, BigDecimal.ZERO);
    private void actor() { when(users.findByEmailIgnoreCase(admin.getEmail())).thenReturn(Optional.of(admin)); }
    @Test void createsActiveServerIdentityWithoutNameLookup() {
        actor(); when(users.existsByIdAndRoleAndStatus(admin.getId(), Role.ADMIN, AccountStatus.ACTIVE)).thenReturn(true);
        UUID id = UUID.randomUUID();
        when(plans.saveAndFlush(any())).thenAnswer(invocation -> {
            MembershipPlan plan = invocation.getArgument(0);
            assertNull(plan.getId()); assertEquals(MembershipPlanStatus.ACTIVE, plan.getStatus());
            assertEquals(37, plan.getDurationDays()); assertEquals(BigDecimal.ZERO, plan.getPrice());
            plan.setId(id); return plan;
        });
        assertEquals(id, service.create(admin.getEmail(), request).id());
        var order = inOrder(users, plans);
        order.verify(users).findByEmailIgnoreCase(admin.getEmail());
        order.verify(users).existsByIdAndRoleAndStatus(admin.getId(), Role.ADMIN, AccountStatus.ACTIVE);
        order.verify(plans).saveAndFlush(any()); verifyNoMoreInteractions(plans);
    }
    @ParameterizedTest @EnumSource(value = Role.class, names = "ADMIN", mode = EnumSource.Mode.EXCLUDE)
    void wrongRole(Role role) { admin.setRole(role); actor(); assertThrows(AccessDeniedException.class, () -> service.create(admin.getEmail(), request)); verifyNoInteractions(plans); }
    @ParameterizedTest @EnumSource(value = AccountStatus.class, names = "ACTIVE", mode = EnumSource.Mode.EXCLUDE)
    void inactive(AccountStatus status) { admin.setStatus(status); actor(); assertThrows(AccessDeniedException.class, () -> service.create(admin.getEmail(), request)); verifyNoInteractions(plans); }
    @Test void recheckRefusesRevocation() { actor(); assertThrows(AccessDeniedException.class, () -> service.create(admin.getEmail(), request)); verifyNoInteractions(plans); }
    @Test void missingActor() { assertThrows(BadCredentialsException.class, () -> service.create("missing", request)); verifyNoInteractions(plans); }
}