package vn.edu.tdtu.fitcenter.controller;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import vn.edu.tdtu.fitcenter.config.SecurityConfig;
import vn.edu.tdtu.fitcenter.config.WebConfig;
import vn.edu.tdtu.fitcenter.domain.entity.Booking;
import vn.edu.tdtu.fitcenter.domain.entity.Member;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.BookingStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.exception.ApiExceptionHandler;
import vn.edu.tdtu.fitcenter.repository.BookingRepository;
import vn.edu.tdtu.fitcenter.repository.MemberRepository;
import vn.edu.tdtu.fitcenter.repository.PersonalTrainerRepository;
import vn.edu.tdtu.fitcenter.repository.UserRepository;
import vn.edu.tdtu.fitcenter.security.JwtAuthenticationFilter;
import vn.edu.tdtu.fitcenter.security.JwtService;
import vn.edu.tdtu.fitcenter.security.RestAccessDeniedHandler;
import vn.edu.tdtu.fitcenter.security.RestAuthenticationEntryPoint;
import vn.edu.tdtu.fitcenter.service.BookingQueryService;
import vn.edu.tdtu.fitcenter.web.CorrelationIdFilter;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(value = BookingController.class, properties = {
        "jwt.secret=fitcenter-test-secret-key-at-least-32-bytes-long-2026",
        "jwt.access-expiration-ms=900000", "jwt.refresh-expiration-ms=604800000"
})
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, JwtService.class,
        RestAuthenticationEntryPoint.class, RestAccessDeniedHandler.class, BookingQueryService.class,
        ApiExceptionHandler.class, CorrelationIdFilter.class, WebConfig.class})
class BookingControllerTest {
    private static final String PATH = "/api/v1/bookings/me";
    private static final String FROM_TEXT = "2020-01-01T00:00:00+07:00";
    private static final String TO_TEXT = "2020-01-02T00:00:00+07:00";
    private static final OffsetDateTime FROM = OffsetDateTime.parse(FROM_TEXT);
    private static final OffsetDateTime TO = OffsetDateTime.parse(TO_TEXT);

    @Autowired MockMvc mvc;
    @Autowired JwtService jwt;
    @MockitoBean UserRepository users;
    @MockitoBean MemberRepository members;
    @MockitoBean BookingRepository bookings;
    @MockitoBean PersonalTrainerRepository trainers;

    private User memberUser;
    private Member member;

    @BeforeEach
    void setUp() {
        memberUser = User.builder().id(UUID.randomUUID()).email("member@example.test")
                .passwordHash("not-a-real-password").role(Role.MEMBER).status(AccountStatus.ACTIVE).build();
        member = Member.builder().id(UUID.randomUUID()).user(memberUser).build();
    }

    private MockHttpServletRequestBuilder authenticatedRequest(User user) {
        when(users.findById(user.getId())).thenReturn(Optional.of(user));
        when(users.findByEmailIgnoreCase(user.getEmail())).thenReturn(Optional.of(user));
        return get(PATH).header("Authorization", "Bearer " + jwt.generateAccessToken(user));
    }

    private MockHttpServletRequestBuilder request() {
        return authenticatedRequest(memberUser).param("from", FROM_TEXT).param("to", TO_TEXT);
    }

    private void mockProfile() {
        when(members.findByUser_Id(memberUser.getId())).thenReturn(Optional.of(member));
    }

    private Booking booking(Member owner, BookingStatus status, int hour) {
        Booking record = Booking.builder().id(UUID.randomUUID()).memberId(owner.getId())
                .ptId(UUID.randomUUID()).slotId(UUID.randomUUID()).status(status)
                .startAt(FROM.plusHours(hour)).endAt(FROM.plusHours(hour + 1))
                .createdAt(FROM.minusDays(1)).updatedAt(FROM).build();
        if (status == BookingStatus.CANCELLED) {
            record.setCancelledBy("PT");
            record.setCancelReason("Schedule conflict");
            record.setCancelledAt(FROM.minusDays(1));
        } else if (status == BookingStatus.COMPLETED) {
            record.setCompletedAt(record.getEndAt());
        }
        return record;
    }

    @Test
    void realMemberJwtReturnsPastBookingsAndAllStatusesWithoutMembershipChecks() throws Exception {
        mockProfile();
        var records = List.of(booking(member, BookingStatus.CONFIRMED, 0),
                booking(member, BookingStatus.CANCELLED, 1), booking(member, BookingStatus.COMPLETED, 2));
        when(bookings.findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), FROM, TO)).thenReturn(records);

        mvc.perform(request().header("X-Correlation-Id", "booking-read-123"))
                .andExpect(status().isOk())
                .andExpect(header().string("X-Correlation-Id", "booking-read-123"))
                .andExpect(jsonPath("$.length()").value(3))
                .andExpect(jsonPath("$[0].length()").value(11))
                .andExpect(jsonPath("$[0].id").value(records.getFirst().getId().toString()))
                .andExpect(jsonPath("$[0].memberId").value(member.getId().toString()))
                .andExpect(jsonPath("$[0].ptId").value(records.getFirst().getPtId().toString()))
                .andExpect(jsonPath("$[0].slotId").value(records.getFirst().getSlotId().toString()))
                .andExpect(jsonPath("$[0].startAt").value(FROM_TEXT))
                .andExpect(jsonPath("$[0].endAt").value("2020-01-01T01:00:00+07:00"))
                .andExpect(jsonPath("$[0].status").value("CONFIRMED"))
                .andExpect(jsonPath("$[1].status").value("CANCELLED"))
                .andExpect(jsonPath("$[1].cancelledBy").value("PT"))
                .andExpect(jsonPath("$[1].cancelReason").value("Schedule conflict"))
                .andExpect(jsonPath("$[1].cancelledAt").value("2019-12-31T00:00:00+07:00"))
                .andExpect(jsonPath("$[2].status").value("COMPLETED"))
                .andExpect(jsonPath("$[2].completedAt").value("2020-01-01T03:00:00+07:00"))
                .andExpect(jsonPath("$[0].createdAt").doesNotExist())
                .andExpect(jsonPath("$[0].updatedAt").doesNotExist())
                .andExpect(jsonPath("$[0].member").doesNotExist())
                .andExpect(jsonPath("$[0].user").doesNotExist())
                .andExpect(jsonPath("$[0].passwordHash").doesNotExist())
                .andExpect(jsonPath("$[0].token").doesNotExist())
                .andExpect(content().string(not(containsString(memberUser.getEmail()))))
                .andExpect(content().string(not(containsString(memberUser.getPasswordHash()))));
        verify(bookings).findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), FROM, TO);
        verifyNoMoreInteractions(bookings);
    }

    @ParameterizedTest
    @EnumSource(BookingStatus.class)
    void eachV4StatusIsSupported(BookingStatus status) throws Exception {
        mockProfile();
        when(bookings.findByMemberIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), status, FROM, TO)).thenReturn(List.of(booking(member, status, 0)));
        mvc.perform(request().param("status", status.name()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].status").value(status.name()));
        verify(bookings).findByMemberIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), status, FROM, TO);
        verifyNoMoreInteractions(bookings);
    }

    @Test
    void noBookingsReturnsAnEmptyArray() throws Exception {
        mockProfile();
        when(bookings.findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), FROM, TO)).thenReturn(List.of());
        mvc.perform(request()).andExpect(status().isOk()).andExpect(content().json("[]"));
    }

    @Test
    void queryParametersCannotReplaceTheMemberResolvedFromJwt() throws Exception {
        mockProfile();
        UUID otherId = UUID.randomUUID();
        when(bookings.findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), FROM, TO)).thenReturn(List.of(booking(member, BookingStatus.CONFIRMED, 0)));
        mvc.perform(request().param("memberId", otherId.toString()).param("userId", otherId.toString())
                        .param("email", "other@example.test"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].memberId").value(member.getId().toString()));
        verify(members).findByUser_Id(memberUser.getId());
        verify(bookings).findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), FROM, TO);
        verifyNoMoreInteractions(members, bookings);
    }

    @Test
    void memberAAndMemberBReceiveTheirOwnBookingsUsingDistinctProfileIds() throws Exception {
        mockProfile();
        User otherUser = User.builder().id(UUID.randomUUID()).email("other@example.test")
                .role(Role.MEMBER).status(AccountStatus.ACTIVE).build();
        Member otherMember = Member.builder().id(UUID.randomUUID()).user(otherUser).build();
        when(members.findByUser_Id(otherUser.getId())).thenReturn(Optional.of(otherMember));
        when(bookings.findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), FROM, TO)).thenReturn(List.of(booking(member, BookingStatus.CONFIRMED, 0)));
        when(bookings.findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                otherMember.getId(), FROM, TO)).thenReturn(List.of(booking(otherMember, BookingStatus.COMPLETED, 2)));
        mvc.perform(request()).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].memberId").value(member.getId().toString()));
        mvc.perform(authenticatedRequest(otherUser).param("from", FROM_TEXT).param("to", TO_TEXT))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].memberId").value(otherMember.getId().toString()));
        verify(bookings).findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), FROM, TO);
        verify(bookings).findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                otherMember.getId(), FROM, TO);
        verifyNoMoreInteractions(bookings);
    }

    @Test
    void doesNotImposeAnUnapprovedMaximumQueryRange() throws Exception {
        mockProfile();
        OffsetDateTime from = OffsetDateTime.parse("1900-01-01T00:00:00Z");
        OffsetDateTime to = OffsetDateTime.parse("2100-01-01T00:00:00Z");
        when(bookings.findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), from, to)).thenReturn(List.of());
        mvc.perform(authenticatedRequest(memberUser).param("from", from.toString()).param("to", to.toString()))
                .andExpect(status().isOk()).andExpect(content().json("[]"));
        verify(bookings).findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), from, to);
    }

    @ParameterizedTest
    @ValueSource(strings = {"from", "to"})
    void missingTimeParameterReturns400(String missing) throws Exception {
        mvc.perform(authenticatedRequest(memberUser)
                        .param(missing.equals("from") ? "to" : "from", missing.equals("from") ? TO_TEXT : FROM_TEXT))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("ERR_VALIDATION"));
        verifyNoInteractions(members, bookings);
    }

    @ParameterizedTest
    @CsvSource({"from,garbage", "to,garbage", "from,2020-01-01T00:00:00",
            "to,2020-01-02T00:00:00", "from,''", "to,''"})
    void invalidTimestampOrMissingTimezoneOffsetReturns400(String parameter, String value) throws Exception {
        mvc.perform(authenticatedRequest(memberUser)
                        .param("from", parameter.equals("from") ? value : FROM_TEXT)
                        .param("to", parameter.equals("to") ? value : TO_TEXT))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("ERR_VALIDATION"));
        verifyNoInteractions(members, bookings);
    }

    @ParameterizedTest
    @ValueSource(strings = {"2020-01-01T00:00:00+07:00", "2019-12-31T17:00:00Z",
            "2019-12-31T23:59:59+07:00"})
    void equalOrReversedInstantsReturn400(String to) throws Exception {
        mvc.perform(authenticatedRequest(memberUser).param("from", FROM_TEXT).param("to", to))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("ERR_VALIDATION"));
        verifyNoInteractions(members, bookings);
    }

    @ParameterizedTest
    @ValueSource(strings = {"PENDING", "REJECTED", "confirmed", "", " CONFIRMED "})
    void unsupportedOrEmptyStatusReturns400(String value) throws Exception {
        mvc.perform(request().param("status", value)).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("ERR_VALIDATION"));
        verifyNoInteractions(members, bookings);
    }

    @Test
    void missingMemberProfileReturns404WithCorrelation() throws Exception {
        when(members.findByUser_Id(memberUser.getId())).thenReturn(Optional.empty());
        mvc.perform(request().header("X-Correlation-Id", "missing-member"))
                .andExpect(status().isNotFound())
                .andExpect(header().string("X-Correlation-Id", "missing-member"))
                .andExpect(jsonPath("$.error.code").value("ERR_NOT_FOUND"))
                .andExpect(jsonPath("$.error.correlationId").value("missing-member"));
        verifyNoInteractions(bookings);
    }

    @ParameterizedTest
    @EnumSource(value = Role.class, names = {"PT", "ADMIN"})
    void otherRolesReturn403(Role role) throws Exception {
        memberUser.setRole(role);
        mvc.perform(request()).andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("ERR_FORBIDDEN"));
        verifyNoInteractions(members, bookings);
    }

    @ParameterizedTest
    @EnumSource(value = AccountStatus.class, names = {"SUSPENDED", "DISABLED"})
    void inactiveAccountIsRejectedByTheExistingJwtFilter(AccountStatus status) throws Exception {
        memberUser.setStatus(status);
        mvc.perform(request()).andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("ERR_UNAUTHORIZED"));
        verifyNoInteractions(members, bookings);
    }

    @Test
    void noJwtReturns401WithCorrelation() throws Exception {
        mvc.perform(get(PATH).param("from", FROM_TEXT).param("to", TO_TEXT)
                        .header("X-Correlation-Id", "no-jwt"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("ERR_UNAUTHORIZED"))
                .andExpect(jsonPath("$.error.correlationId").value("no-jwt"));
        verifyNoInteractions(users, members, bookings);
    }

    @Test
    void invalidJwtReturns401() throws Exception {
        mvc.perform(get(PATH).param("from", FROM_TEXT).param("to", TO_TEXT)
                        .header("Authorization", "Bearer invalid-token"))
                .andExpect(status().isUnauthorized());
        verifyNoInteractions(users, members, bookings);
    }

    @Test
    void refreshTokenCannotBeUsedForThisEndpoint() throws Exception {
        mvc.perform(get(PATH).param("from", FROM_TEXT).param("to", TO_TEXT)
                        .header("Authorization", "Bearer " + jwt.generateRefreshToken(memberUser)))
                .andExpect(status().isUnauthorized());
        verifyNoInteractions(users, members, bookings);
    }

    @Test
    void unexpectedFailureDoesNotLeakInternalInformation() throws Exception {
        mockProfile();
        when(bookings.findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), FROM, TO)).thenThrow(new IllegalStateException("private database details"));
        mvc.perform(request()).andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.error.code").value("ERR_INTERNAL"))
                .andExpect(jsonPath("$.stackTrace").doesNotExist())
                .andExpect(content().string(not(containsString("private database details"))));
    }
}
