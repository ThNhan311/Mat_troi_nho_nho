
package vn.edu.tdtu.fitcenter.controller;

import org.junit.jupiter.api.Test;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import vn.edu.tdtu.fitcenter.config.SecurityConfig;
import vn.edu.tdtu.fitcenter.repository.UserRepository;
import vn.edu.tdtu.fitcenter.security.JwtAuthenticationFilter;
import vn.edu.tdtu.fitcenter.security.JwtService;
import vn.edu.tdtu.fitcenter.security.RestAccessDeniedHandler;
import vn.edu.tdtu.fitcenter.security.RestAuthenticationEntryPoint;
import vn.edu.tdtu.fitcenter.service.MembershipService;

import java.util.List;

import static org.mockito.Mockito.when;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(MembershipController.class)
@Import({
        SecurityConfig.class,
        JwtAuthenticationFilter.class,
        RestAuthenticationEntryPoint.class,
        RestAccessDeniedHandler.class
})
class MembershipControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private MembershipService membershipService;

    @MockitoBean
    private JwtService jwtService;

    @MockitoBean
    private UserRepository userRepository;

    @Test
    void getMyMemberships_returns401_whenUnauthenticated()
            throws Exception {

        mockMvc.perform(
                get("/api/v1/memberships/me")
        )
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.status").value(401));
    }

    @Test
    @WithMockUser(username = "pt@test.com", roles = "PT")
    void getMyMemberships_returns403_whenUserIsPT()
            throws Exception {

        mockMvc.perform(
                get("/api/v1/memberships/me")
        )
        .andExpect(status().isForbidden())
        .andExpect(jsonPath("$.status").value(403));
    }

    @Test
    @WithMockUser(username = "member@test.com", roles = "MEMBER")
    void getMyMemberships_returns200_whenUserIsMember()
            throws Exception {

        when(membershipService.getMyMemberships("member@test.com"))
                .thenReturn(List.of());

        mockMvc.perform(
                get("/api/v1/memberships/me")
                        .accept(MediaType.APPLICATION_JSON)
        )
        .andExpect(status().isOk())
        .andExpect(content().json("[]"));

        verify(membershipService)
                .getMyMemberships("member@test.com");
    }
}
