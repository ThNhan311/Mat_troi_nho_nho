package vn.edu.tdtu.fitcenter.kiosk;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.tdtu.fitcenter.domain.enums.Role;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Records visits seen by the kiosk: members in attendance_records; trainers in a
 * small local file, because the schema has no trainer attendance table. The
 * kiosk has no liveness check, so its rows are marked with their own kiosk id.
 */
@Component
@ConditionalOnProperty(name = "fitcenter.kiosk.enabled", havingValue = "true")
public class KioskAttendance {
    static final Duration REPEAT_WINDOW = Duration.ofMinutes(30);
    public static final String KIOSK_ID = "local-kiosk-no-liveness";

    public record Visit(UUID profileId, Instant at) {
    }

    private final JdbcTemplate jdbc;
    private final Clock clock;
    private final Path trainerLog;

    public KioskAttendance(JdbcTemplate jdbc, Clock clock,
            @Value("${fitcenter.kiosk.trainer-log:${user.home}/.fitcenter/kiosk-trainer-visits.csv}") Path trainerLog) {
        this.jdbc = jdbc;
        this.clock = clock;
        this.trainerLog = trainerLog.toAbsolutePath();
    }

    /** One visit per person per 30 minutes; callers pass only accepted check-ins. */
    @Transactional(timeout = 10)
    public void record(UUID profileId, Role role) {
        if (role == Role.PT) {
            recordTrainer(profileId);
            return;
        }
        // Serialises concurrent scans of the same member.
        jdbc.queryForList("SELECT id FROM members WHERE id = ? FOR NO KEY UPDATE", profileId);
        var now = clock.instant().truncatedTo(ChronoUnit.MICROS);
        Integer recent = jdbc.queryForObject(
                "SELECT count(*) FROM attendance_records WHERE member_id = ? AND checked_in_at > ?", Integer.class,
                profileId, at(now.minus(REPEAT_WINDOW)));
        if (recent != null && recent == 0) {
            jdbc.update("INSERT INTO attendance_records(member_id,checked_in_at,source,kiosk_id,dedupe_key) "
                    + "VALUES(?,?,'FACE',?,?)", profileId, at(now), KIOSK_ID, "kiosk:" + UUID.randomUUID());
        }
    }

    private synchronized void recordTrainer(UUID profileId) {
        var now = clock.instant().truncatedTo(ChronoUnit.SECONDS);
        var recent = trainerVisits().stream()
                .anyMatch(v -> v.profileId().equals(profileId) && v.at().isAfter(now.minus(REPEAT_WINDOW)));
        if (recent) {
            return;
        }
        try {
            Files.createDirectories(trainerLog.getParent());
            Files.writeString(trainerLog, profileId + "," + now + "\n", StandardCharsets.UTF_8,
                    StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    public synchronized List<Visit> trainerVisits() {
        var result = new ArrayList<Visit>();
        if (!Files.exists(trainerLog)) {
            return result;
        }
        try {
            for (var line : Files.readAllLines(trainerLog, StandardCharsets.UTF_8)) {
                var parts = line.split(",");
                if (parts.length == 2) {
                    result.add(new Visit(UUID.fromString(parts[0]), Instant.parse(parts[1])));
                }
            }
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        return result;
    }

    private static OffsetDateTime at(Instant instant) {
        return OffsetDateTime.ofInstant(instant, ZoneOffset.UTC);
    }
}
