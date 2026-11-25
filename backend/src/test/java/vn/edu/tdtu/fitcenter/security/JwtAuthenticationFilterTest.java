
package vn.edu.tdtu.fitcenter.security;

import jakarta.servlet.FilterChain;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;

import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class JwtAuthenticationFilterTest {

    @Mock
    private JwtService jwtService;

    @Mock
    private UserRepository userRepository;

    @Mock
    private FilterChain filterChain;

    @InjectMocks
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    private MockHttpServletRequest request;
    private MockHttpServletResponse response;

    private User activeUser;

    private static final String ACCESS_TOKEN = "valid-access-token";

    @BeforeEach
    void setUp() {
        SecurityContextHolder.clearContext();

        request = new MockHttpServletRequest();
        request.setMethod("GET");
        request.setRequestURI("/api/v1/memberships/me");
        request.setServletPath("/api/v1/memberships/me");

        response = new MockHttpServletResponse();

        activeUser = User.builder()
                .id(UUID.randomUUID())
                .email("member@fitcenter.local")
                .passwordHash("encoded-password")
                .role(Role.MEMBER)
                .status(AccountStatus.ACTIVE)
                .build();
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    private void executeFilter() throws Exception {
        jwtAuthenticationFilter.doFilter(
                request,
                response,
                filterChain
        );
    }

    private void setBearerToken(String token) {
        request.addHeader(
                "Authorization",
                "Bearer " + token
        );
    }

    private void mockValidAccessToken() {
        when(jwtService.isAccessTokenValid(ACCESS_TOKEN))
                .thenReturn(true);

        when(jwtService.extractUserId(ACCESS_TOKEN))
                .thenReturn(activeUser.getId().toString());
    }

    private void assertUnauthenticated() throws Exception {
        executeFilter();

        assertNull(
                SecurityContextHolder.getContext()
                        .getAuthentication()
        );

        verify(filterChain).doFilter(request, response);
    }

    @Test
    void missingAuthorizationHeader_doesNotAuthenticate()
            throws Exception {

        assertUnauthenticated();

        verifyNoInteractions(jwtService, userRepository);
    }

    @Test
    void nonBearerHeader_doesNotAuthenticate()
            throws Exception {

        request.addHeader(
                "Authorization",
                "Basic example-credentials"
        );

        assertUnauthenticated();

        verifyNoInteractions(jwtService, userRepository);
    }

    @Test
    void invalidAccessToken_doesNotAuthenticate()
            throws Exception {

        setBearerToken("invalid-token");

        when(jwtService.isAccessTokenValid("invalid-token"))
                .thenReturn(false);

        assertUnauthenticated();

        verifyNoInteractions(userRepository);
    }

    @Test
    void refreshToken_rejectedByAccessTokenValidation()
            throws Exception {

        setBearerToken("refresh-token");

        when(jwtService.isAccessTokenValid("refresh-token"))
                .thenReturn(false);

        assertUnauthenticated();

        verifyNoInteractions(userRepository);
    }

    @Test
    void invalidUserId_doesNotAuthenticate()
            throws Exception {

        setBearerToken(ACCESS_TOKEN);

        when(jwtService.isAccessTokenValid(ACCESS_TOKEN))
                .thenReturn(true);

        when(jwtService.extractUserId(ACCESS_TOKEN))
                .thenReturn("not-a-valid-uuid");

        assertUnauthenticated();

        verifyNoInteractions(userRepository);
    }

    @Test
    void unknownUser_doesNotAuthenticate()
            throws Exception {

        setBearerToken(ACCESS_TOKEN);
        mockValidAccessToken();

        when(userRepository.findById(activeUser.getId()))
                .thenReturn(Optional.empty());

        assertUnauthenticated();
    }

    @Test
    void suspendedUser_doesNotAuthenticate()
            throws Exception {

        activeUser.setStatus(AccountStatus.SUSPENDED);

        setBearerToken(ACCESS_TOKEN);
        mockValidAccessToken();

        when(userRepository.findById(activeUser.getId()))
                .thenReturn(Optional.of(activeUser));

        assertUnauthenticated();
    }

    @Test
    void disabledUser_doesNotAuthenticate()
            throws Exception {

        activeUser.setStatus(AccountStatus.DISABLED);

        setBearerToken(ACCESS_TOKEN);
        mockValidAccessToken();

        when(userRepository.findById(activeUser.getId()))
                .thenReturn(Optional.of(activeUser));

        assertUnauthenticated();
    }

    @Test
    void activeMember_authenticatesSuccessfully()
            throws Exception {

        setBearerToken(ACCESS_TOKEN);
        mockValidAccessToken();

        when(userRepository.findById(activeUser.getId()))
                .thenReturn(Optional.of(activeUser));

        executeFilter();

        Authentication authentication =
                SecurityContextHolder.getContext()
                        .getAuthentication();

        assertNotNull(authentication);
        assertTrue(authentication.isAuthenticated());

        assertEquals(
                activeUser.getEmail(),
                authentication.getPrincipal()
        );

        assertTrue(
                authentication.getAuthorities().stream()
                        .anyMatch(authority ->
                                "ROLE_MEMBER".equals(
                                        authority.getAuthority()
                                )
                        )
        );

        verify(filterChain).doFilter(request, response);
    }

    @Test
    void databaseRole_isUsedForAuthorization()
            throws Exception {

        activeUser.setRole(Role.PT);

        setBearerToken(ACCESS_TOKEN);
        mockValidAccessToken();

        when(userRepository.findById(activeUser.getId()))
                .thenReturn(Optional.of(activeUser));

        executeFilter();

        Authentication authentication =
                SecurityContextHolder.getContext()
                        .getAuthentication();

        assertNotNull(authentication);

        assertTrue(
                authentication.getAuthorities().stream()
                        .anyMatch(authority ->
                                "ROLE_PT".equals(
                                        authority.getAuthority()
                                )
                        )
        );

        assertFalse(
                authentication.getAuthorities().stream()
                        .anyMatch(authority ->
                                "ROLE_MEMBER".equals(
                                        authority.getAuthority()
                                )
                        )
        );

        verify(filterChain).doFilter(request, response);
    }

    @Test
    void existingAuthentication_isNotOverwritten()
            throws Exception {

        Authentication existingAuthentication =
                new UsernamePasswordAuthenticationToken(
                        "existing-user",
                        null,
                        List.of(
                                new SimpleGrantedAuthority("ROLE_ADMIN")
                        )
                );

        SecurityContextHolder.getContext()
                .setAuthentication(existingAuthentication);

        setBearerToken(ACCESS_TOKEN);

        when(jwtService.isAccessTokenValid(ACCESS_TOKEN))
                .thenReturn(true);

        executeFilter();

        assertSame(
                existingAuthentication,
                SecurityContextHolder.getContext()
                        .getAuthentication()
        );

        verifyNoInteractions(userRepository);
        verify(filterChain).doFilter(request, response);
    }
}
