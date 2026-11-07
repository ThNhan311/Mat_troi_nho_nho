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
import vn.edu.tdtu.fitcenter.domain.entity.PersonalTrainer;
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

@WebMvcTest(value = PtBookingController.class, properties = {
        "jwt.secret=fitcenter-test-secret-key-at-least-32-bytes-long-2026",
        "jwt.access-expiration-ms=900000", "jwt.refresh-expiration-ms=604800000"
})
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, JwtService.class,
        RestAuthenticationEntryPoint.class, RestAccessDeniedHandler.class, BookingQueryService.class,
        ApiExceptionHandler.class, CorrelationIdFilter.class, WebConfig.class})
class PtBookingControllerTest {
    private static final String PATH = "/api/v1/pt/bookings";
    private static final String FROM_TEXT = "2020-01-01T00:00:00+07:00";
    private static final String TO_TEXT = "2020-01-02T00:00:00+07:00";
    private static final OffsetDateTime FROM = OffsetDateTime.parse(FROM_TEXT);
    private static final OffsetDateTime TO = OffsetDateTime.parse(TO_TEXT);

    @Autowired MockMvc mvc;
    @Autowired JwtService jwt;
    @MockitoBean UserRepository users;
    @MockitoBean PersonalTrainerRepository trainers;
    @MockitoBean MemberRepository members;
    @MockitoBean BookingRepository bookings;

    private User ptUser;
    private PersonalTrainer trainer;

    @BeforeEach
    void setUp() {
        ptUser = User.builder().id(UUID.randomUUID()).email("trainer@example.test")
                .passwordHash("not-a-real-password").role(Role.PT).status(AccountStatus.ACTIVE).build();
        trainer = PersonalTrainer.builder().id(UUID.randomUUID()).user(ptUser).build();
    }

    private MockHttpServletRequestBuilder authenticatedRequest(User user) {
        when(users.findById(user.getId())).thenReturn(Optional.of(user));
        when(users.findByEmailIgnoreCase(user.getEmail())).thenReturn(Optional.of(user));
        return get(PATH).header("Authorization", "Bearer " + jwt.generateAccessToken(user));
    }

    private MockHttpServletRequestBuilder request() {
        return authenticatedRequest(ptUser).param("from", FROM_TEXT).param("to", TO_TEXT);
    }

    private void mockProfile() {
        when(trainers.findByUser_Id(ptUser.getId())).thenReturn(Optional.of(trainer));
    }

    private Booking booking(PersonalTrainer owner, BookingStatus status, int hour) {
        Booking record = Booking.builder().id(UUID.randomUUID()).ptId(owner.getId())
                .memberId(UUID.randomUUID()).slotId(UUID.randomUUID()).status(status)
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
    void realPtJwtReturnsPastBookingsAndAllStatusesWithoutMembershipChecks() throws Exception {
        mockProfile();
        var records = List.of(booking(trainer, BookingStatus.CONFIRMED, 0),
                booking(trainer, BookingStatus.CANCELLED, 1), booking(trainer, BookingStatus.COMPLETED, 2));
        when(bookings.findByPtIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO)).thenReturn(records);

        mvc.perform(request().header("X-Correlation-Id", "booking-read-123"))
                .andExpect(status().isOk())
                .andExpect(header().string("X-Correlation-Id", "booking-read-123"))
                .andExpect(jsonPath("$.length()").value(3))
                .andExpect(jsonPath("$[0].length()").value(11))
                .andExpect(jsonPath("$[0].id").value(records.getFirst().getId().toString()))
                .andExpect(jsonPath("$[0].ptId").value(trainer.getId().toString()))
                .andExpect(jsonPath("$[0].memberId").value(records.getFirst().getMemberId().toString()))
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
                .andExpect(jsonPath("$[0].trainer").doesNotExist())
                .andExpect(jsonPath("$[0].user").doesNotExist())
                .andExpect(jsonPath("$[0].passwordHash").doesNotExist())
                .andExpect(jsonPath("$[0].token").doesNotExist())
                .andExpect(content().string(not(containsString(ptUser.getEmail()))))
                .andExpect(content().string(not(containsString(ptUser.getPasswordHash()))));
        verify(bookings).findByPtIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO);
        verifyNoMoreInteractions(bookings);
        verifyNoInteractions(members);
    }

    @ParameterizedTest
    @EnumSource(BookingStatus.class)
    void eachV4StatusIsSupported(BookingStatus status) throws Exception {
        mockProfile();
        when(bookings.findByPtIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), status, FROM, TO)).thenReturn(List.of(booking(trainer, status, 0)));
        mvc.perform(request().param("status", status.name()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].status").value(status.name()));
        verify(bookings).findByPtIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), status, FROM, TO);
        verifyNoMoreInteractions(bookings);
    }

    @Test
    void noBookingsReturnsAnEmptyArray() throws Exception {
        mockProfile();
        when(bookings.findByPtIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO)).thenReturn(List.of());
        mvc.perform(request()).andExpect(status().isOk()).andExpect(content().json("[]"));
    }

    @Test
    void queryParametersCannotReplaceTheTrainerResolvedFromJwt() throws Exception {
        mockProfile();
        UUID otherId = UUID.randomUUID();
        when(bookings.findByPtIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO)).thenReturn(List.of(booking(trainer, BookingStatus.CONFIRMED, 0)));
        mvc.perform(request().param("ptId", otherId.toString()).param("userId", otherId.toString())
                        .param("email", "other@example.test"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].ptId").value(trainer.getId().toString()));
        verify(trainers).findByUser_Id(ptUser.getId());
        verify(bookings).findByPtIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO);
        verifyNoMoreInteractions(trainers, bookings);
    }

    @Test
    void ptAAndPtBReceiveTheirOwnBookingsUsingDistinctProfileIds() throws Exception {
        mockProfile();
        User otherUser = User.builder().id(UUID.randomUUID()).email("other@example.test")
                .role(Role.PT).status(AccountStatus.ACTIVE).build();
        PersonalTrainer otherTrainer = PersonalTrainer.builder().id(UUID.randomUUID()).user(otherUser).build();
        when(trainers.findByUser_Id(otherUser.getId())).thenReturn(Optional.of(otherTrainer));
        when(bookings.findByPtIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO)).thenReturn(List.of(booking(trainer, BookingStatus.CONFIRMED, 0)));
        when(bookings.findByPtIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                otherTrainer.getId(), FROM, TO)).thenReturn(List.of(booking(otherTrainer, BookingStatus.COMPLETED, 2)));
        mvc.perform(request()).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].ptId").value(trainer.getId().toString()));
        mvc.perform(authenticatedRequest(otherUser).param("from", FROM_TEXT).param("to", TO_TEXT))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].ptId").value(otherTrainer.getId().toString()));
        verify(bookings).findByPtIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO);
        verify(bookings).findByPtIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                otherTrainer.getId(), FROM, TO);
        verifyNoMoreInteractions(bookings);
    }

    @Test
    void doesNotImposeAnUnapprovedMaximumQueryRange() throws Exception {
        mockProfile();
        OffsetDateTime from = OffsetDateTime.parse("1900-01-01T00:00:00Z");
        OffsetDateTime to = OffsetDateTime.parse("2100-01-01T00:00:00Z");
        when(bookings.findByPtIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), from, to)).thenReturn(List.of());
        mvc.perform(authenticatedRequest(ptUser).param("from", from.toString()).param("to", to.toString()))
                .andExpect(status().isOk()).andExpect(content().json("[]"));
        verify(bookings).findByPtIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), from, to);
    }

    @ParameterizedTest
    @ValueSource(strings = {"from", "to"})
    void missingTimeParameterReturns400(String missing) throws Exception {
        mvc.perform(authenticatedRequest(ptUser)
                        .param(missing.equals("from") ? "to" : "from", missing.equals("from") ? TO_TEXT : FROM_TEXT))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("ERR_VALIDATION"));
        verifyNoInteractions(trainers, bookings);
    }

    @ParameterizedTest
    @CsvSource({"from,garbage", "to,garbage", "from,2020-01-01T00:00:00",
            "to,2020-01-02T00:00:00", "from,''", "to,''"})
    void invalidTimestampOrMissingTimezoneOffsetReturns400(String parameter, String value) throws Exception {
        mvc.perform(authenticatedRequest(ptUser)
                        .param("from", parameter.equals("from") ? value : FROM_TEXT)
                        .param("to", parameter.equals("to") ? value : TO_TEXT))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("ERR_VALIDATION"));
        verifyNoInteractions(trainers, bookings);
    }

    @ParameterizedTest
    @ValueSource(strings = {"2020-01-01T00:00:00+07:00", "2019-12-31T17:00:00Z",
            "2019-12-31T23:59:59+07:00"})
    void equalOrReversedInstantsReturn400(String to) throws Exception {
        mvc.perform(authenticatedRequest(ptUser).param("from", FROM_TEXT).param("to", to))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("ERR_VALIDATION"));
        verifyNoInteractions(trainers, bookings);
    }

    @ParameterizedTest
    @ValueSource(strings = {"PENDING", "REJECTED", "confirmed", "", " CONFIRMED "})
    void unsupportedOrEmptyStatusReturns400(String value) throws Exception {
        mvc.perform(request().param("status", value)).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("ERR_VALIDATION"));
        verifyNoInteractions(trainers, bookings);
    }

    @Test
    void missingTrainerProfileReturns404WithCorrelation() throws Exception {
        when(trainers.findByUser_Id(ptUser.getId())).thenReturn(Optional.empty());
        mvc.perform(request().header("X-Correlation-Id", "missing-trainer"))
                .andExpect(status().isNotFound())
                .andExpect(header().string("X-Correlation-Id", "missing-trainer"))
                .andExpect(jsonPath("$.error.code").value("ERR_NOT_FOUND"))
                .andExpect(jsonPath("$.error.correlationId").value("missing-trainer"));
        verifyNoInteractions(bookings);
    }

    @ParameterizedTest
    @EnumSource(value = Role.class, names = {"MEMBER", "ADMIN"})
    void otherRolesReturn403(Role role) throws Exception {
        ptUser.setRole(role);
        mvc.perform(request()).andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("ERR_FORBIDDEN"));
        verifyNoInteractions(trainers, bookings);
    }

    @ParameterizedTest
    @EnumSource(value = AccountStatus.class, names = {"SUSPENDED", "DISABLED"})
    void inactiveAccountIsRejectedByTheExistingJwtFilter(AccountStatus status) throws Exception {
        ptUser.setStatus(status);
        mvc.perform(request()).andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("ERR_UNAUTHORIZED"));
        verifyNoInteractions(trainers, bookings);
    }

    @Test
    void noJwtReturns401WithCorrelation() throws Exception {
        mvc.perform(get(PATH).param("from", FROM_TEXT).param("to", TO_TEXT)
                        .header("X-Correlation-Id", "no-jwt"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("ERR_UNAUTHORIZED"))
                .andExpect(jsonPath("$.error.correlationId").value("no-jwt"));
        verifyNoInteractions(users, trainers, bookings);
    }

    @Test
    void invalidJwtReturns401() throws Exception {
        mvc.perform(get(PATH).param("from", FROM_TEXT).param("to", TO_TEXT)
                        .header("Authorization", "Bearer invalid-token"))
                .andExpect(status().isUnauthorized());
        verifyNoInteractions(users, trainers, bookings);
    }

    @Test
    void refreshTokenCannotBeUsedForThisEndpoint() throws Exception {
        mvc.perform(get(PATH).param("from", FROM_TEXT).param("to", TO_TEXT)
                        .header("Authorization", "Bearer " + jwt.generateRefreshToken(ptUser)))
                .andExpect(status().isUnauthorized());
        verifyNoInteractions(users, trainers, bookings);
    }

    @Test
    void unexpectedFailureDoesNotLeakInternalInformation() throws Exception {
        mockProfile();
        when(bookings.findByPtIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO)).thenThrow(new IllegalStateException("private database details"));
        mvc.perform(request()).andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.error.code").value("ERR_INTERNAL"))
                .andExpect(jsonPath("$.stackTrace").doesNotExist())
                .andExpect(content().string(not(containsString("private database details"))));
    }
}
