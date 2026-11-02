
package vn.edu.tdtu.fitcenter.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;

import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.server.ResponseStatusException;

import vn.edu.tdtu.fitcenter.domain.entity.Member;
import vn.edu.tdtu.fitcenter.domain.entity.Membership;
import vn.edu.tdtu.fitcenter.domain.entity.MembershipPlan;
import vn.edu.tdtu.fitcenter.domain.entity.User;

import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.MembershipStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;

import vn.edu.tdtu.fitcenter.repository.MemberRepository;
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
    private UserRepository userRepository;

    @Mock
    private MemberRepository memberRepository;

    @Mock
    private MembershipRepository membershipRepository;

    @InjectMocks
    private MembershipService membershipService;

    private User testUser;
    private Member testMember;

    @BeforeEach
    void setUp() {
        testUser = new User();
        testUser.setId(UUID.randomUUID());
        testUser.setEmail("member@test.com");
        testUser.setRole(Role.MEMBER);
        testUser.setStatus(AccountStatus.ACTIVE);

        testMember = new Member();
        testMember.setId(UUID.randomUUID());
        testMember.setUser(testUser);
        testMember.setFullName("Test Member");
    }

    private void mockActiveMember() {
        when(userRepository.findByEmail("member@test.com"))
                .thenReturn(Optional.of(testUser));

        when(memberRepository.findByUser_Id(testUser.getId()))
                .thenReturn(Optional.of(testMember));
    }

    @Test
    void returnsEmptyList_whenMemberHasNoMembership() {
        mockActiveMember();

        when(membershipRepository.findByMember_Id(testMember.getId()))
                .thenReturn(List.of());

        var result = membershipService.getMyMemberships(
                "member@test.com"
        );

        assertNotNull(result);
        assertTrue(result.isEmpty());

        verify(memberRepository)
                .findByUser_Id(testUser.getId());

        verify(membershipRepository)
                .findByMember_Id(testMember.getId());
    }

    @Test
    void deniesAccess_whenAccountSuspended() {
        testUser.setStatus(AccountStatus.SUSPENDED);

        when(userRepository.findByEmail("member@test.com"))
                .thenReturn(Optional.of(testUser));

        assertThrows(
                AccessDeniedException.class,
                () -> membershipService.getMyMemberships(
                        "member@test.com"
                )
        );

        verifyNoInteractions(
                memberRepository,
                membershipRepository
        );
    }

    @Test
    void deniesAccess_whenUserIsPT() {
        testUser.setRole(Role.PT);

        when(userRepository.findByEmail("member@test.com"))
                .thenReturn(Optional.of(testUser));

        assertThrows(
                AccessDeniedException.class,
                () -> membershipService.getMyMemberships(
                        "member@test.com"
                )
        );

        verifyNoInteractions(
                memberRepository,
                membershipRepository
        );
    }

    @Test
    void returns404_whenMemberProfileNotFound() {
        when(userRepository.findByEmail("member@test.com"))
                .thenReturn(Optional.of(testUser));

        when(memberRepository.findByUser_Id(testUser.getId()))
                .thenReturn(Optional.empty());

        ResponseStatusException exception = assertThrows(
                ResponseStatusException.class,
                () -> membershipService.getMyMemberships(
                        "member@test.com"
                )
        );

        assertEquals(
                HttpStatus.NOT_FOUND,
                exception.getStatusCode()
        );

        verifyNoInteractions(membershipRepository);
    }

    @Test
    void returnsMembership_whenDataExists() {
        mockActiveMember();

        UUID membershipId = UUID.randomUUID();
        UUID planId = UUID.randomUUID();

        MembershipPlan plan = new MembershipPlan();
        plan.setId(planId);
        plan.setName("Basic 30 Days");

        Membership membership = new Membership();
        membership.setId(membershipId);
        membership.setMember(testMember);
        membership.setPlan(plan);
        membership.setStartDate(
                LocalDate.of(2026, 10, 21)
        );
        membership.setExpiryDate(
                LocalDate.of(2026, 11, 20)
        );
        membership.setStatus(MembershipStatus.ACTIVE);

        when(membershipRepository.findByMember_Id(testMember.getId()))
                .thenReturn(List.of(membership));

        var result = membershipService.getMyMemberships(
                "member@test.com"
        );

        assertEquals(1, result.size());
        assertEquals(membershipId, result.get(0).id());
        assertEquals(planId, result.get(0).planId());
        assertEquals("Basic 30 Days", result.get(0).planName());
        assertEquals(
                LocalDate.of(2026, 11, 20),
                result.get(0).endDate()
        );
        assertEquals(
                MembershipStatus.ACTIVE,
                result.get(0).status()
        );

        verify(memberRepository)
                .findByUser_Id(testUser.getId());

        verify(membershipRepository)
                .findByMember_Id(testMember.getId());
    }
}
