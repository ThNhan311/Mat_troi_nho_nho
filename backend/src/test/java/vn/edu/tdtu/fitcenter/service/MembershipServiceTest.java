
package vn.edu.tdtu.fitcenter.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;

import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Spy;
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
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class MembershipServiceTest {
    @Spy
    private Clock clock = Clock.fixed(Instant.parse("2026-11-05T12:00:00Z"), ZoneOffset.UTC);

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
        when(userRepository.findByEmailIgnoreCase("member@test.com"))
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

        when(userRepository.findByEmailIgnoreCase("member@test.com"))
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

        when(userRepository.findByEmailIgnoreCase("member@test.com"))
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
        when(userRepository.findByEmailIgnoreCase("member@test.com"))
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

    private vn.edu.tdtu.fitcenter.dto.membership.MembershipResponse responseFor(
            MembershipStatus status, LocalDate start, LocalDate end) {
        mockActiveMember();
        MembershipPlan plan = MembershipPlan.builder().id(UUID.randomUUID()).name("Plan").build();
        Membership membership = Membership.builder().id(UUID.randomUUID()).member(testMember)
                .plan(plan).status(status).startDate(start).expiryDate(end).build();
        when(membershipRepository.findByMember_Id(testMember.getId())).thenReturn(List.of(membership));
        return membershipService.getMyMemberships("member@test.com").get(0);
    }

    @Test void expiredDateDoesNotRemainActive() {
        assertEquals(MembershipStatus.EXPIRED, responseFor(MembershipStatus.ACTIVE,
                LocalDate.of(2026, 10, 1), LocalDate.of(2026, 11, 4)).status());
    }

    @Test void expiryTodayIsStillActive() {
        assertEquals(MembershipStatus.ACTIVE, responseFor(MembershipStatus.ACTIVE,
                LocalDate.of(2026, 10, 1), LocalDate.of(2026, 11, 5)).status());
    }

    @Test void futureStartIsNotActive() {
        assertEquals(MembershipStatus.PENDING_ACTIVATION, responseFor(MembershipStatus.ACTIVE,
                LocalDate.of(2026, 11, 6), LocalDate.of(2026, 12, 5)).status());
    }

    @Test void missingDatesCannotGrantActiveMembership() {
        assertEquals(MembershipStatus.PENDING_ACTIVATION,
                responseFor(MembershipStatus.ACTIVE, null, null).status());
    }

    @Test void suspendedStatusIsPreservedEvenWhenDatesExpired() {
        assertEquals(MembershipStatus.SUSPENDED, responseFor(MembershipStatus.SUSPENDED,
                LocalDate.of(2026, 10, 1), LocalDate.of(2026, 11, 4)).status());
    }

    @Test void cancelledStatusIsPreserved() {
        assertEquals(MembershipStatus.CANCELLED, responseFor(MembershipStatus.CANCELLED,
                LocalDate.of(2026, 10, 1), LocalDate.of(2026, 12, 5)).status());
    }

    @Test void expirationUsesVietnamBusinessDateAcrossUtcMidnight() {
        clock = Clock.fixed(Instant.parse("2026-11-05T18:00:00Z"), ZoneOffset.UTC);
        membershipService = new MembershipService(membershipRepository, memberRepository, userRepository, clock);
        assertEquals(MembershipStatus.EXPIRED, responseFor(MembershipStatus.ACTIVE,
                LocalDate.of(2026, 10, 1), LocalDate.of(2026, 11, 5)).status());
    }
}
