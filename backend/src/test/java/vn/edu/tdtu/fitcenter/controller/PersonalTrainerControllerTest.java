package vn.edu.tdtu.fitcenter.controller;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import vn.edu.tdtu.fitcenter.config.SecurityConfig;
import vn.edu.tdtu.fitcenter.config.TimeConfig;
import vn.edu.tdtu.fitcenter.config.WebConfig;
import vn.edu.tdtu.fitcenter.exception.ApiExceptionHandler;
import vn.edu.tdtu.fitcenter.web.CorrelationIdFilter;
import vn.edu.tdtu.fitcenter.domain.entity.PersonalTrainer;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.repository.*;
import vn.edu.tdtu.fitcenter.security.*;
import vn.edu.tdtu.fitcenter.service.*;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.hamcrest.Matchers.*;

@WebMvcTest({PersonalTrainerController.class, MembershipPlanController.class, AuthController.class})
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, RestAuthenticationEntryPoint.class,
        RestAccessDeniedHandler.class, PersonalTrainerService.class, TimeConfig.class,
        ApiExceptionHandler.class, CorrelationIdFilter.class, WebConfig.class})
class PersonalTrainerControllerTest {
    @Test void allowedBrowserOriginCanPreflightLogin() throws Exception {
        mvc.perform(options("/api/v1/auth/login").header("Origin", "http://localhost:3000")
                .header("Access-Control-Request-Method", "POST")
                .header("Access-Control-Request-Headers", "content-type"))
            .andExpect(status().isOk())
            .andExpect(header().string("Access-Control-Allow-Origin", "http://localhost:3000"));
    }

    @Test void unconfiguredBrowserOriginIsRejected() throws Exception {
        mvc.perform(options("/api/v1/auth/login").header("Origin", "https://untrusted.example")
                .header("Access-Control-Request-Method", "POST"))
            .andExpect(status().isForbidden());
    }
    @Autowired MockMvc mvc;
    @MockitoBean PersonalTrainerRepository trainers;
    @MockitoBean AvailabilitySlotRepository slots;
    @MockitoBean MembershipPlanService plans;
    @MockitoBean AuthService auth;
    @MockitoBean JwtService jwt;
    @MockitoBean UserRepository users;

    @Test void unauthenticatedGetsStructured401AndCorrelation() throws Exception {
        mvc.perform(get("/api/v1/trainers").header("X-Correlation-Id", "review-123"))
            .andExpect(status().isUnauthorized())
            .andExpect(header().string("X-Correlation-Id", "review-123"))
            .andExpect(jsonPath("$.error.correlationId").value("review-123"))
            .andExpect(jsonPath("$.error.code").value("ERR_UNAUTHORIZED"))
            .andExpect(jsonPath("$.success").value(false));
    }

    @Test void invalidCorrelationIsReplaced() throws Exception {
        mvc.perform(get("/api/v1/trainers").header("X-Correlation-Id", "x".repeat(65)))
            .andExpect(status().isUnauthorized())
            .andExpect(header().string("X-Correlation-Id", matchesPattern("[a-f0-9-]{36}")));
    }

    @Test @WithMockUser(roles="PT")
    void ptCannotReadMemberTrainerCatalogue() throws Exception {
        mvc.perform(get("/api/v1/trainers")).andExpect(status().isForbidden())
            .andExpect(jsonPath("$.error.code").value("ERR_FORBIDDEN"));
        verifyNoInteractions(trainers);
    }

    @Test @WithMockUser(roles="PT")
    void ptCannotReadMemberAdminPlans() throws Exception {
        mvc.perform(get("/api/v1/membership-plans")).andExpect(status().isForbidden());
        verifyNoInteractions(plans);
    }

    @Test @WithMockUser(roles="ADMIN")
    void adminCanReadPlans() throws Exception {
        when(plans.getActivePlans()).thenReturn(List.of());
        mvc.perform(get("/api/v1/membership-plans")).andExpect(status().isOk());
    }

    @Test @WithMockUser(roles="MEMBER")
    void invalidDateRangeReturns400() throws Exception {
        mvc.perform(get("/api/v1/trainers/" + UUID.randomUUID() + "/slots")
                .param("from", "2026-12-02T10:00:00Z").param("to", "2026-12-01T10:00:00Z"))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.error.code").value("ERR_VALIDATION"));
        verifyNoInteractions(trainers, slots);
    }

    @Test @WithMockUser(roles="MEMBER")
    void unknownOrInactiveTrainerReturns404() throws Exception {
        UUID id = UUID.randomUUID();
        when(trainers.findByIdAndUser_Status(id, AccountStatus.ACTIVE)).thenReturn(Optional.empty());
        mvc.perform(get("/api/v1/trainers/" + id + "/slots")
                .param("from", "2026-12-01T10:00:00Z").param("to", "2026-12-02T10:00:00Z"))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.error.code").value("ERR_NOT_FOUND"));
        verifyNoInteractions(slots);
    }

    @Test @WithMockUser(roles="MEMBER")
    void invalidUuidReturnsStructured400() throws Exception {
        mvc.perform(get("/api/v1/trainers/not-a-uuid"))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.error.code").value("ERR_VALIDATION"));
    }

    @Test @WithMockUser(roles="MEMBER")
    void bothSlotPathsRemainAvailable() throws Exception {
        UUID id = UUID.randomUUID();
        when(trainers.findByIdAndUser_Status(id, AccountStatus.ACTIVE))
            .thenReturn(Optional.of(PersonalTrainer.builder().id(id).fullName("PT").build()));
        for (String suffix : List.of("slots", "availability")) {
            mvc.perform(get("/api/v1/trainers/" + id + "/" + suffix)
                    .param("from", "2026-12-01T10:00:00Z").param("to", "2026-12-02T10:00:00Z"))
                .andExpect(status().isOk()).andExpect(content().json("[]"));
        }
    }

    @Test void invalidLoginDtoHasFieldDetails() throws Exception {
        mvc.perform(post("/api/v1/auth/login").contentType("application/json")
                .content("{\"email\":\"invalid\",\"password\":\"\"}"))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.error.details.email").exists())
            .andExpect(jsonPath("$.error.details.password").exists());
    }

    @Test void badCredentialsReturn401() throws Exception {
        when(auth.login(any())).thenThrow(new org.springframework.security.authentication.BadCredentialsException("bad"));
        mvc.perform(post("/api/v1/auth/login").contentType("application/json")
                .content("{\"email\":\"member@example.com\",\"password\":\"bad\"}"))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.error.code").value("ERR_UNAUTHORIZED"));
    }

    @Test @WithMockUser(roles="MEMBER")
    void unexpectedFailureHidesInternalMessage() throws Exception {
        when(trainers.findByUser_StatusOrderByFullNameAsc(AccountStatus.ACTIVE))
                .thenThrow(new IllegalStateException("private internal value"));
        mvc.perform(get("/api/v1/trainers"))
            .andExpect(status().isInternalServerError())
            .andExpect(jsonPath("$.error.code").value("ERR_INTERNAL"))
            .andExpect(jsonPath("$.message", not(containsString("private internal value"))));
    }
}
