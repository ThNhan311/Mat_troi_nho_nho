package vn.edu.tdtu.fitcenter.service;

import jakarta.validation.Validation;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.security.access.AccessDeniedException;
import vn.edu.tdtu.fitcenter.accountadmin.TrainerPhones;
import vn.edu.tdtu.fitcenter.domain.entity.PersonalTrainer;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.dto.request.PtProfileWriteRequest;
import vn.edu.tdtu.fitcenter.repository.PersonalTrainerRepository;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class PtProfileServiceTest {
    private static final String EMAIL = "pt@example.test";

    private final UserRepository users = mock(UserRepository.class);
    private final PersonalTrainerRepository trainers = mock(PersonalTrainerRepository.class);
    private final TrainerPhones phones = mock(TrainerPhones.class);
    private final PtProfileService service = new PtProfileService(users, trainers, phones,
            mock(vn.edu.tdtu.fitcenter.accountadmin.TrainerGenders.class));
    private final User user = User.builder().id(UUID.randomUUID()).email(EMAIL)
            .role(Role.PT).status(AccountStatus.ACTIVE).build();
    private final PersonalTrainer trainer = PersonalTrainer.builder().id(UUID.randomUUID())
            .user(user).fullName("Trainer A").bio("old").build();

    private void signedIn() {
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.of(user));
    }

    @Test
    void updateTrimsClearsBlanksAndKeepsTheName() {
        signedIn();
        when(trainers.findByUserIdForUpdate(user.getId())).thenReturn(Optional.of(trainer));

        var result = service.update(EMAIL, new PtProfileWriteRequest("   ", "  Yoga, Cardio ", "3 years\n"));

        assertNull(trainer.getBio());
        assertEquals("Yoga, Cardio", trainer.getSpecialization());
        assertEquals("3 years", trainer.getExperienceSummary());
        assertEquals("Trainer A", result.fullName());
        assertEquals(trainer.getId(), result.id());
    }

    @Test
    void readReturnsTheSignedInTrainersOwnProfile() {
        signedIn();
        when(trainers.findByUser_Id(user.getId())).thenReturn(Optional.of(trainer));

        assertEquals("old", service.mine(EMAIL).bio());
    }

    @ParameterizedTest
    @EnumSource(value = Role.class, names = "PT", mode = EnumSource.Mode.EXCLUDE)
    void otherRolesCannotReadOrWrite(Role role) {
        user.setRole(role);
        signedIn();

        assertThrows(AccessDeniedException.class, () -> service.mine(EMAIL));
        assertThrows(AccessDeniedException.class,
                () -> service.update(EMAIL, new PtProfileWriteRequest("a", "b", "c")));
        verifyNoInteractions(trainers);
    }

    @Test
    void inactiveTrainerCannotWrite() {
        user.setStatus(AccountStatus.SUSPENDED);
        signedIn();

        assertThrows(AccessDeniedException.class,
                () -> service.update(EMAIL, new PtProfileWriteRequest("a", "b", "c")));
        verifyNoInteractions(trainers);
    }

    @Test
    void lengthLimitsMatchTheColumns() {
        try (var factory = Validation.buildDefaultValidatorFactory()) {
            var validator = factory.getValidator();
            assertEquals(0, validator.validate(new PtProfileWriteRequest(
                    "a".repeat(1000), "b".repeat(200), "c".repeat(500))).size());
            assertEquals(3, validator.validate(new PtProfileWriteRequest(
                    "a".repeat(1001), "b".repeat(201), "c".repeat(501))).size());
        }
    }
}
