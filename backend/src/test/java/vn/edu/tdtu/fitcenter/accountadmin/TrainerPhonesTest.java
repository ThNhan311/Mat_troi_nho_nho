package vn.edu.tdtu.fitcenter.accountadmin;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

class TrainerPhonesTest {
    @TempDir Path directory;

    @Test
    void numbersSurviveARestartAndCanBeReplacedOrRemoved() {
        var file = directory.resolve("nested/trainer-phones.properties");
        var first = UUID.randomUUID();
        var second = UUID.randomUUID();
        var phones = new TrainerPhones(file);
        assertEquals(Optional.empty(), phones.find(first));

        phones.save(first, "0901234567");
        phones.save(second, "0912345678");
        phones.save(first, "+84901234567");

        var reopened = new TrainerPhones(file);
        assertEquals(Optional.of("+84901234567"), reopened.find(first));
        reopened.remove(first);
        assertEquals(Optional.empty(), new TrainerPhones(file).find(first));
        assertEquals(Optional.of("0912345678"), new TrainerPhones(file).find(second));
    }

    @Test
    void removingAnUnknownProfileWritesNothing() {
        var file = directory.resolve("trainer-phones.properties");
        new TrainerPhones(file).remove(UUID.randomUUID());
        assertFalse(Files.exists(file));
    }
}
