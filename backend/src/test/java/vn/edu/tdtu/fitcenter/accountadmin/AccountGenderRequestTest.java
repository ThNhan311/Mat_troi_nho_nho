package vn.edu.tdtu.fitcenter.accountadmin;

import jakarta.validation.Validation;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import tools.jackson.databind.json.JsonMapper;
import vn.edu.tdtu.fitcenter.dto.account.AccountCreateRequest;

import java.nio.file.Path;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class AccountGenderRequestTest {
    @TempDir Path directory;

    @Test
    void createReadsAnOptionalGenderAndRejectsOtherWords() {
        var mapper = JsonMapper.builder().build();
        var without = mapper.readValue("{\"email\":\"a@example.test\",\"fullName\":\"A\"}",
                AccountCreateRequest.class);
        var with = mapper.readValue("{\"email\":\"a@example.test\",\"fullName\":\"A\",\"gender\":\"FEMALE\"}",
                AccountCreateRequest.class);
        assertNull(without.gender());
        assertEquals("FEMALE", with.gender());

        try (var factory = Validation.buildDefaultValidatorFactory()) {
            var validator = factory.getValidator();
            assertEquals(0, validator.validate(without).size());
            assertEquals(0, validator.validate(with).size());
            assertEquals(1, validator.validate(
                    new AccountCreateRequest("a@example.test", "A", null, "other")).size());
            assertEquals(1, validator.validate(
                    new AccountAdminController.Update("A", "a@example.test", null, "nam")).size());
        }
    }

    @Test
    void trainerGenderHasItsOwnFile() {
        var profile = UUID.randomUUID();
        var genders = new TrainerGenders(directory.resolve("genders.properties"));
        genders.save(profile, "MALE");

        assertEquals(Optional.of("MALE"), new TrainerGenders(directory.resolve("genders.properties")).find(profile));
        assertEquals(Optional.empty(), new TrainerPhones(directory.resolve("phones.properties")).find(profile));
    }
}
