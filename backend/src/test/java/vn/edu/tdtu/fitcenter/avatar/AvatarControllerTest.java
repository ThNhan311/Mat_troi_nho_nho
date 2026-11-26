package vn.edu.tdtu.fitcenter.avatar;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import vn.edu.tdtu.fitcenter.config.SecurityConfig;
import vn.edu.tdtu.fitcenter.config.WebConfig;
import vn.edu.tdtu.fitcenter.domain.entity.PersonalTrainer;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.exception.ApiExceptionHandler;
import vn.edu.tdtu.fitcenter.repository.PersonalTrainerRepository;
import vn.edu.tdtu.fitcenter.repository.UserRepository;
import vn.edu.tdtu.fitcenter.security.JwtAuthenticationFilter;
import vn.edu.tdtu.fitcenter.security.JwtService;
import vn.edu.tdtu.fitcenter.security.RestAccessDeniedHandler;
import vn.edu.tdtu.fitcenter.security.RestAuthenticationEntryPoint;
import vn.edu.tdtu.fitcenter.web.CorrelationIdFilter;

import java.nio.file.Path;
import java.util.Optional;
import java.util.UUID;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(value = AvatarController.class, properties = {
        "jwt.secret=fitcenter-test-secret-key-at-least-32-bytes-long-2026",
        "jwt.access-expiration-ms=900000", "jwt.refresh-expiration-ms=604800000",
        "fitcenter.avatar.enabled=true",
        "fitcenter.avatar.directory=${java.io.tmpdir}/fitcenter-avatar-test-${random.uuid}"
})
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, JwtService.class,
        RestAuthenticationEntryPoint.class, RestAccessDeniedHandler.class, AvatarStore.class,
        ApiExceptionHandler.class, CorrelationIdFilter.class, WebConfig.class})
class AvatarControllerTest {
    private static final String ME = "/api/v1/avatar/me";

    @Autowired MockMvc mvc;
    @Autowired JwtService jwt;
    @MockitoBean UserRepository users;
    @MockitoBean PersonalTrainerRepository trainers;

    private User user(Role role) {
        User user = User.builder().id(UUID.randomUUID()).email(UUID.randomUUID() + "@example.test")
                .passwordHash("not-a-real-password").role(role).status(AccountStatus.ACTIVE).build();
        when(users.findById(user.getId())).thenReturn(Optional.of(user));
        when(users.findByEmailIgnoreCase(user.getEmail())).thenReturn(Optional.of(user));
        return user;
    }

    private String bearer(User user) {
        return "Bearer " + jwt.generateAccessToken(user);
    }

    private static byte[] png() throws Exception {
        return AvatarStoreTest.image(40, 40, "png");
    }

    @Test void anonymousCannotReadOrChangeAnything() throws Exception {
        mvc.perform(get(ME)).andExpect(status().isUnauthorized());
        mvc.perform(put(ME).contentType(MediaType.IMAGE_PNG).content(png())).andExpect(status().isUnauthorized());
        mvc.perform(delete(ME)).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/trainers/" + UUID.randomUUID() + "/avatar")).andExpect(status().isUnauthorized());
    }

    @ParameterizedTest @EnumSource(value = Role.class, names = {"MEMBER", "PT"})
    void memberAndTrainerManageOnlyTheirOwnPicture(Role role) throws Exception {
        User owner = user(role), other = user(role);
        mvc.perform(get(ME).header("Authorization", bearer(owner))).andExpect(status().isNoContent());
        mvc.perform(put(ME).header("Authorization", bearer(owner)).contentType(MediaType.IMAGE_PNG).content(png()))
                .andExpect(status().isNoContent());
        mvc.perform(get(ME).header("Authorization", bearer(owner))).andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.IMAGE_JPEG))
                .andExpect(header().string("Cache-Control", "no-store"));
        mvc.perform(get(ME).header("Authorization", bearer(other))).andExpect(status().isNoContent());
        mvc.perform(delete(ME).header("Authorization", bearer(other))).andExpect(status().isNoContent());
        mvc.perform(get(ME).header("Authorization", bearer(owner))).andExpect(status().isOk());
        mvc.perform(delete(ME).header("Authorization", bearer(owner))).andExpect(status().isNoContent());
        mvc.perform(get(ME).header("Authorization", bearer(owner))).andExpect(status().isNoContent());
    }

    @Test void adminHasNoAvatarRoutes() throws Exception {
        User admin = user(Role.ADMIN);
        mvc.perform(get(ME).header("Authorization", bearer(admin))).andExpect(status().isForbidden());
        mvc.perform(put(ME).header("Authorization", bearer(admin)).contentType(MediaType.IMAGE_PNG).content(png()))
                .andExpect(status().isForbidden());
    }

    @Test void rejectsNonImagesAndOtherContentTypes() throws Exception {
        User member = user(Role.MEMBER);
        mvc.perform(put(ME).header("Authorization", bearer(member)).contentType(MediaType.IMAGE_PNG).content("hello"))
                .andExpect(status().isBadRequest());
        mvc.perform(put(ME).header("Authorization", bearer(member)).contentType(MediaType.TEXT_HTML).content(png()))
                .andExpect(status().isUnsupportedMediaType());
        mvc.perform(put(ME).header("Authorization", bearer(member)).contentType(MediaType.IMAGE_PNG)
                .content(new byte[AvatarStore.MAX_BYTES + 10])).andExpect(status().is(413));
    }

    @Test void memberSeesAnActiveTrainersPictureButTrainersCannotBrowseThem() throws Exception {
        User member = user(Role.MEMBER), pt = user(Role.PT);
        UUID ptId = UUID.randomUUID();
        when(trainers.findByIdAndUser_Status(ptId, AccountStatus.ACTIVE))
                .thenReturn(Optional.of(PersonalTrainer.builder().id(ptId).user(pt).fullName("PT").build()));
        mvc.perform(put(ME).header("Authorization", bearer(pt)).contentType(MediaType.IMAGE_PNG).content(png()))
                .andExpect(status().isNoContent());
        String path = "/api/v1/trainers/" + ptId + "/avatar";
        mvc.perform(get(path).header("Authorization", bearer(member))).andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.IMAGE_JPEG));
        mvc.perform(get(path).header("Authorization", bearer(pt))).andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/trainers/" + UUID.randomUUID() + "/avatar").header("Authorization", bearer(member)))
                .andExpect(status().isNotFound());
    }
}
