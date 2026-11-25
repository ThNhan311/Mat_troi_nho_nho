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
import vn.edu.tdtu.fitcenter.domain.entity.AvailabilitySlot;
import vn.edu.tdtu.fitcenter.domain.entity.PersonalTrainer;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.domain.enums.SlotStatus;
import vn.edu.tdtu.fitcenter.exception.ApiExceptionHandler;
import vn.edu.tdtu.fitcenter.repository.AvailabilitySlotRepository;
import vn.edu.tdtu.fitcenter.repository.PersonalTrainerRepository;
import vn.edu.tdtu.fitcenter.repository.UserRepository;
import vn.edu.tdtu.fitcenter.security.JwtAuthenticationFilter;
import vn.edu.tdtu.fitcenter.security.JwtService;
import vn.edu.tdtu.fitcenter.security.RestAccessDeniedHandler;
import vn.edu.tdtu.fitcenter.security.RestAuthenticationEntryPoint;
import vn.edu.tdtu.fitcenter.service.AvailabilityService;
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

@WebMvcTest(value = PtAvailabilityController.class, properties = {
        "jwt.secret=fitcenter-test-secret-key-at-least-32-bytes-long-2026",
        "jwt.access-expiration-ms=900000", "jwt.refresh-expiration-ms=604800000"
})
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, JwtService.class,
        RestAuthenticationEntryPoint.class, RestAccessDeniedHandler.class,
        AvailabilityService.class, ApiExceptionHandler.class, CorrelationIdFilter.class, WebConfig.class})
class PtAvailabilityControllerTest {
    private static final String PATH = "/api/v1/pt/slots";
    private static final String FROM_TEXT = "2020-01-01T00:00:00+07:00";
    private static final String TO_TEXT = "2020-01-02T00:00:00+07:00";
    private static final OffsetDateTime FROM = OffsetDateTime.parse(FROM_TEXT);
    private static final OffsetDateTime TO = OffsetDateTime.parse(TO_TEXT);

    @Autowired MockMvc mvc;
    @Autowired JwtService jwt;
    @MockitoBean UserRepository users;
    @MockitoBean PersonalTrainerRepository trainers;
    @MockitoBean AvailabilitySlotRepository slots;

    private User pt;
    private PersonalTrainer trainer;

    @BeforeEach
    void setUp() {
        pt = User.builder().id(UUID.randomUUID()).email("pt@example.test")
                .role(Role.PT).status(AccountStatus.ACTIVE).build();
        trainer = PersonalTrainer.builder().id(UUID.randomUUID()).user(pt).build();
    }

    private MockHttpServletRequestBuilder authenticatedRequest(User user) {
        when(users.findById(user.getId())).thenReturn(Optional.of(user));
        when(users.findByEmailIgnoreCase(user.getEmail())).thenReturn(Optional.of(user));
        return get(PATH).header("Authorization", "Bearer " + jwt.generateAccessToken(user));
    }

    private MockHttpServletRequestBuilder request() {
        return authenticatedRequest(pt).param("from", FROM_TEXT).param("to", TO_TEXT);
    }

    private void mockProfile() {
        when(trainers.findByUser_Id(pt.getId())).thenReturn(Optional.of(trainer));
    }

    private AvailabilitySlot slot(PersonalTrainer owner, SlotStatus status, int hour) {
        return AvailabilitySlot.builder().id(UUID.randomUUID()).personalTrainer(owner)
                .startAt(FROM.plusHours(hour)).endAt(FROM.plusHours(hour + 1))
                .status(status).version(0L).build();
    }

    @Test
    void realJwtReturnsAllStatusesIncludingPastSlotsAsDtos() throws Exception {
        mockProfile();
        var records = List.of(slot(trainer, SlotStatus.AVAILABLE, 0),
                slot(trainer, SlotStatus.BOOKED, 1), slot(trainer, SlotStatus.DISABLED, 2));
        when(slots.findByPersonalTrainerIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO)).thenReturn(records);

        mvc.perform(request().header("X-Correlation-Id", "pt-slots-123"))
                .andExpect(status().isOk())
                .andExpect(header().string("X-Correlation-Id", "pt-slots-123"))
                .andExpect(jsonPath("$.length()").value(3))
                .andExpect(jsonPath("$[0].id").value(records.getFirst().getId().toString()))
                .andExpect(jsonPath("$[0].ptId").value(trainer.getId().toString()))
                .andExpect(jsonPath("$[0].startAt").value(FROM_TEXT))
                .andExpect(jsonPath("$[0].status").value("AVAILABLE"))
                .andExpect(jsonPath("$[1].status").value("BOOKED"))
                .andExpect(jsonPath("$[2].status").value("DISABLED"))
                .andExpect(jsonPath("$[0].personalTrainer").doesNotExist())
                .andExpect(jsonPath("$[0].version").doesNotExist());
        verify(slots).findByPersonalTrainerIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO);
        verifyNoMoreInteractions(slots);
    }

    @ParameterizedTest
    @EnumSource(SlotStatus.class)
    void supportsEachStatusFilter(SlotStatus status) throws Exception {
        mockProfile();
        when(slots.findByPersonalTrainerIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), status, FROM, TO)).thenReturn(List.of(slot(trainer, status, 0)));
        mvc.perform(request().param("status", status.name()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].status").value(status.name()));
        verify(slots).findByPersonalTrainerIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), status, FROM, TO);
        verifyNoMoreInteractions(slots);
    }

    @Test
    void noSlotsReturnsAnEmptyJsonArray() throws Exception {
        mockProfile();
        when(slots.findByPersonalTrainerIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO)).thenReturn(List.of());
        mvc.perform(request()).andExpect(status().isOk()).andExpect(content().json("[]"));
    }

    @Test
    void ownerQueryParametersCannotSelectAnotherTrainer() throws Exception {
        mockProfile();
        UUID otherId = UUID.randomUUID();
        when(slots.findByPersonalTrainerIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO)).thenReturn(List.of(slot(trainer, SlotStatus.BOOKED, 1)));
        mvc.perform(request().param("ptId", otherId.toString()).param("userId", otherId.toString())
                        .param("email", "another-pt@example.test"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].ptId").value(trainer.getId().toString()));
        verify(trainers).findByUser_Id(pt.getId());
        verify(slots).findByPersonalTrainerIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO);
        verifyNoMoreInteractions(trainers, slots);
    }

    @Test
    void differentJwtOwnersResolveDifferentTrainerProfiles() throws Exception {
        mockProfile();
        User other = User.builder().id(UUID.randomUUID()).email("other@example.test")
                .role(Role.PT).status(AccountStatus.ACTIVE).build();
        PersonalTrainer otherTrainer = PersonalTrainer.builder().id(UUID.randomUUID()).user(other).build();
        when(trainers.findByUser_Id(other.getId())).thenReturn(Optional.of(otherTrainer));
        when(slots.findByPersonalTrainerIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO)).thenReturn(List.of(slot(trainer, SlotStatus.AVAILABLE, 0)));
        when(slots.findByPersonalTrainerIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                otherTrainer.getId(), FROM, TO)).thenReturn(List.of(slot(otherTrainer, SlotStatus.DISABLED, 2)));
        mvc.perform(request()).andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].ptId").value(trainer.getId().toString()));
        mvc.perform(authenticatedRequest(other).param("from", FROM_TEXT).param("to", TO_TEXT))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].ptId").value(otherTrainer.getId().toString()));
    }

    @ParameterizedTest
    @ValueSource(strings = {"from", "to"})
    void missingTimeParameterReturnsStructured400(String missing) throws Exception {
        String remaining = missing.equals("from") ? "to" : "from";
        mvc.perform(authenticatedRequest(pt).param(remaining, missing.equals("from") ? TO_TEXT : FROM_TEXT))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("ERR_VALIDATION"));
        verifyNoInteractions(trainers, slots);
    }

    @ParameterizedTest
    @CsvSource({"from,garbage", "to,garbage", "from,2020-01-01T00:00:00",
            "to,2020-01-02T00:00:00", "from,''", "to,''"})
    void malformedOrMissingOffsetReturns400(String parameter, String value) throws Exception {
        var query = authenticatedRequest(pt).param("from", parameter.equals("from") ? value : FROM_TEXT)
                .param("to", parameter.equals("to") ? value : TO_TEXT);
        mvc.perform(query).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("ERR_VALIDATION"));
        verifyNoInteractions(trainers, slots);
    }

    @ParameterizedTest
    @ValueSource(strings = {"2020-01-01T00:00:00+07:00", "2019-12-31T17:00:00Z",
            "2019-12-31T23:59:59+07:00"})
    void equalOrReversedInstantsReturn400(String to) throws Exception {
        mvc.perform(authenticatedRequest(pt).param("from", FROM_TEXT).param("to", to))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("ERR_VALIDATION"));
        verifyNoInteractions(trainers, slots);
    }

    @ParameterizedTest
    @ValueSource(strings = {"PENDING", "available", "", " AVAILABLE "})
    void invalidStatusReturns400(String value) throws Exception {
        mvc.perform(request().param("status", value)).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("ERR_VALIDATION"));
        verifyNoInteractions(trainers, slots);
    }

    @Test
    void missingProfileReturnsStructured404() throws Exception {
        when(trainers.findByUser_Id(pt.getId())).thenReturn(Optional.empty());
        mvc.perform(request().header("X-Correlation-Id", "missing-profile"))
                .andExpect(status().isNotFound())
                .andExpect(header().string("X-Correlation-Id", "missing-profile"))
                .andExpect(jsonPath("$.error.code").value("ERR_NOT_FOUND"))
                .andExpect(jsonPath("$.error.correlationId").value("missing-profile"));
        verifyNoInteractions(slots);
    }

    @ParameterizedTest
    @EnumSource(value = Role.class, names = {"MEMBER", "ADMIN"})
    void nonPtJwtReturns403(Role role) throws Exception {
        pt.setRole(role);
        mvc.perform(request()).andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("ERR_FORBIDDEN"));
        verifyNoInteractions(trainers, slots);
    }

    @Test
    void missingJwtReturns401WithCorrelation() throws Exception {
        mvc.perform(get(PATH).param("from", FROM_TEXT).param("to", TO_TEXT)
                        .header("X-Correlation-Id", "no-token"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("ERR_UNAUTHORIZED"))
                .andExpect(jsonPath("$.error.correlationId").value("no-token"));
        verifyNoInteractions(users, trainers, slots);
    }

    @Test
    void invalidJwtReturns401() throws Exception {
        mvc.perform(get(PATH).param("from", FROM_TEXT).param("to", TO_TEXT)
                        .header("Authorization", "Bearer invalid-token"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("ERR_UNAUTHORIZED"));
        verifyNoInteractions(users, trainers, slots);
    }

    @Test
    void refreshTokenCannotBeUsedAsAccessToken() throws Exception {
        mvc.perform(get(PATH).param("from", FROM_TEXT).param("to", TO_TEXT)
                        .header("Authorization", "Bearer " + jwt.generateRefreshToken(pt)))
                .andExpect(status().isUnauthorized());
        verifyNoInteractions(users, trainers, slots);
    }

    @Test
    void unexpectedFailureDoesNotExposeInternalDetails() throws Exception {
        mockProfile();
        when(slots.findByPersonalTrainerIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO)).thenThrow(new IllegalStateException("private database details"));
        mvc.perform(request()).andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.error.code").value("ERR_INTERNAL"))
                .andExpect(jsonPath("$.stackTrace").doesNotExist())
                .andExpect(content().string(not(containsString("private database details"))));
    }
}
