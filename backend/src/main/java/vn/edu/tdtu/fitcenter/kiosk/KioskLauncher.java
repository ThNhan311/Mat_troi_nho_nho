package vn.edu.tdtu.fitcenter.kiosk;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Opens the camera screen on the front desk computer, which is where this local
 * backend runs. The script comes from configuration only; a request cannot
 * choose or extend the command.
 */
@Component
@ConditionalOnProperty(name = "fitcenter.kiosk.enabled", havingValue = "true")
public class KioskLauncher {
    /** Starting takes a while; further clicks in this time do nothing. */
    static final Duration STARTING = Duration.ofSeconds(20);

    private final Path script;
    private final Clock clock;
    private Instant startedAt;

    public KioskLauncher(@Value("${fitcenter.kiosk.launcher:}") String script, Clock clock) {
        this.script = script.isBlank() ? null : Path.of(script).toAbsolutePath();
        this.clock = clock;
    }

    public synchronized void open() {
        if (script == null || !Files.isRegularFile(script)) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "This computer has no camera screen to open");
        }
        var now = clock.instant();
        if (startedAt != null && now.isBefore(startedAt.plus(STARTING))) {
            return;
        }
        var builder = new ProcessBuilder(List.of("powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
                "-WindowStyle", "Hidden", "-File", script.toString()))
                .redirectOutput(ProcessBuilder.Redirect.DISCARD)
                .redirectError(ProcessBuilder.Redirect.DISCARD);
        withoutSecrets(builder.environment());
        try {
            builder.start();
        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Could not open the camera screen");
        }
        startedAt = now;
    }

    /** The screen must not inherit the database password or signing keys. */
    static void withoutSecrets(Map<String, String> environment) {
        environment.keySet().removeIf(name -> {
            var key = name.toUpperCase(Locale.ROOT);
            return key.startsWith("DB_") || key.startsWith("PG") && key.contains("PASSWORD")
                    || key.startsWith("JWT_") || key.startsWith("FITCENTER_") || key.contains("PASSWORD");
        });
    }
}
