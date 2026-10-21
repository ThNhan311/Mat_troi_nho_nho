
package vn.edu.tdtu.fitcenter.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;

import vn.edu.tdtu.fitcenter.domain.entity.Membership;
import vn.edu.tdtu.fitcenter.domain.entity.MembershipPlan;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.MembershipStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.repository.MembershipRepository;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class MembershipServiceTest {

    @Mock
    private MembershipRepository membershipRepository;

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private MembershipService membershipService;

    private User testUser;

    @BeforeEach
    void setUp() {
        testUser = new User();
        testUser.setId(UUID.randomUUID());
        testUser.setEmail("member@test.com");
        testUser.setRole(Role.MEMBER);
        testUser.setStatus(AccountStatus.ACTIVE);
    }

    @Test
    void getMyMemberships_returnsEmptyList_whenMemberHasNoMembership() {
        when(userRepository.findByEmail("member@test.com"))
                .thenReturn(Optional.of(testUser));

        when(membershipRepository.findByMemberId(testUser.getId()))
                .thenReturn(List.of());

        var result = membershipService.getMyMemberships("member@test.com");

        assertNotNull(result);
        assertTrue(result.isEmpty());

        verify(membershipRepository).findByMemberId(testUser.getId());
    }

    @Test
    void getMyMemberships_deniesAccess_whenAccountSuspended() {
        testUser.setStatus(AccountStatus.SUSPENDED);

        when(userRepository.findByEmail("member@test.com"))
                .thenReturn(Optional.of(testUser));

        assertThrows(
                AccessDeniedException.class,
                () -> membershipService.getMyMemberships("member@test.com")
        );

        verifyNoInteractions(membershipRepository);
    }

    @Test
    void getMyMemberships_deniesAccess_whenUserIsPT() {
        testUser.setRole(Role.PT);

        when(userRepository.findByEmail("member@test.com"))
                .thenReturn(Optional.of(testUser));

        assertThrows(
                AccessDeniedException.class,
                () -> membershipService.getMyMemberships("member@test.com")
        );

        verifyNoInteractions(membershipRepository);
    }

    @Test
    void getMyMemberships_returnsMembership_whenDataExists() {
        UUID membershipId = UUID.randomUUID();
        UUID planId = UUID.randomUUID();

        MembershipPlan plan = new MembershipPlan();
        plan.setId(planId);
        plan.setName("Basic 30 Days");

        Membership membership = new Membership();
        membership.setId(membershipId);
        membership.setMember(testUser);
        membership.setPlan(plan);
        membership.setStartDate(LocalDate.of(2026, 10, 21));
        membership.setEndDate(LocalDate.of(2026, 11, 20));
        membership.setStatus(MembershipStatus.ACTIVE);

        when(userRepository.findByEmail("member@test.com"))
                .thenReturn(Optional.of(testUser));

        when(membershipRepository.findByMemberId(testUser.getId()))
                .thenReturn(List.of(membership));

        var result = membershipService.getMyMemberships("member@test.com");

        assertEquals(1, result.size());
        assertEquals(membershipId, result.get(0).id());
        assertEquals(planId, result.get(0).planId());
        assertEquals("Basic 30 Days", result.get(0).planName());
        assertEquals(MembershipStatus.ACTIVE, result.get(0).status());

        verify(membershipRepository).findByMemberId(testUser.getId());
    }
}
