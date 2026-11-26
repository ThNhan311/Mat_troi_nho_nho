package vn.edu.tdtu.fitcenter.kiosk;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;
import java.util.UUID;

/**
 * Remembers which profiles have a face on the kiosk and which faces still have to
 * be removed there. Only profile ids and one word each: no face data.
 */
@Component
@ConditionalOnProperty(name = "fitcenter.kiosk.enabled", havingValue = "true")
public class KioskFaces {
    public enum State { NONE, ENROLLED, REMOVING }

    private final Path file;
    private final Properties states = new Properties();

    public KioskFaces(@Value("${fitcenter.kiosk.registry:${user.home}/.fitcenter/kiosk-faces.properties}") Path file) {
        this.file = file.toAbsolutePath();
        if (Files.exists(this.file)) {
            try (var in = Files.newInputStream(this.file)) {
                states.load(in);
            } catch (IOException e) {
                throw new UncheckedIOException(e);
            }
        }
    }

    public synchronized State state(UUID profileId) {
        var value = states.getProperty(profileId.toString());
        return value == null ? State.NONE : State.valueOf(value);
    }

    public synchronized void enrolled(UUID profileId) {
        set(profileId, State.ENROLLED);
    }

    /** A recognised face is proof it exists, unless its removal is already queued. */
    public synchronized void seen(UUID profileId) {
        if (state(profileId) == State.NONE) {
            set(profileId, State.ENROLLED);
        }
    }

    /**
     * Queued even when nothing is recorded here: the kiosk treats "not found" as
     * done, and a face must never outlive a request to delete it.
     */
    public synchronized void requestRemoval(UUID profileId) {
        set(profileId, State.REMOVING);
    }

    public synchronized List<UUID> pendingRemovals() {
        var result = new ArrayList<UUID>();
        for (var key : states.stringPropertyNames()) {
            if (State.REMOVING.name().equals(states.getProperty(key))) {
                result.add(UUID.fromString(key));
            }
        }
        return result;
    }

    public synchronized void removed(UUID profileId) {
        if (state(profileId) == State.REMOVING) {
            set(profileId, State.NONE);
        }
    }

    private void set(UUID profileId, State state) {
        if (state == State.NONE) {
            states.remove(profileId.toString());
        } else {
            states.setProperty(profileId.toString(), state.name());
        }
        try {
            Files.createDirectories(file.getParent());
            var temporary = Files.createTempFile(file.getParent(), "faces", ".tmp");
            try (var out = Files.newOutputStream(temporary)) {
                states.store(out, null);
            }
            Files.move(temporary, file, StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}
