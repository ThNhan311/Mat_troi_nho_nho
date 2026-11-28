package vn.edu.tdtu.fitcenter.accountadmin;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Optional;
import java.util.Properties;
import java.util.UUID;

/**
 * One value per trainer profile id, kept in a file outside Git because
 * personal_trainers has no column for it and the schema is not changed.
 */
abstract class TrainerFile {
    private final Path file;
    private Properties values = new Properties();

    TrainerFile(Path file) {
        this.file = file.toAbsolutePath();
        if (Files.exists(this.file)) {
            try (var in = Files.newInputStream(this.file)) {
                values.load(in);
            } catch (IOException e) {
                throw new UncheckedIOException(e);
            }
        }
    }

    public synchronized Optional<String> find(UUID profileId) {
        return Optional.ofNullable(values.getProperty(profileId.toString()));
    }

    public synchronized void save(UUID profileId, String value) {
        var next = copy();
        next.setProperty(profileId.toString(), value);
        store(next);
    }

    public synchronized void remove(UUID profileId) {
        if (values.containsKey(profileId.toString())) {
            var next = copy();
            next.remove(profileId.toString());
            store(next);
        }
    }

    private Properties copy() {
        var next = new Properties();
        next.putAll(values);
        return next;
    }

    /** What is read back only changes once the file has been replaced. */
    private void store(Properties next) {
        try {
            Files.createDirectories(file.getParent());
            var temporary = Files.createTempFile(file.getParent(), "trainer", ".tmp");
            try {
                try (var out = Files.newOutputStream(temporary)) {
                    next.store(out, null);
                }
                Files.move(temporary, file, StandardCopyOption.REPLACE_EXISTING);
            } finally {
                Files.deleteIfExists(temporary);
            }
            values = next;
        } catch (IOException e) {
            throw new UncheckedIOException("Trainer detail could not be stored", e);
        }
    }
}
