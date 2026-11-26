package vn.edu.tdtu.fitcenter.accountadmin;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.tdtu.fitcenter.kiosk.KioskAttendance;

import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AdminReportService {
    static final int MAX_DAYS = 92;
    private static final ZoneId ZONE = ZoneId.of("Asia/Ho_Chi_Minh");

    private final JdbcTemplate jdbc;
    private final ObjectProvider<KioskAttendance> kiosk;

    /** status: CONFIRMED, COMPLETED, CANCELLED, or OPEN for a free slot nobody booked. */
    public record Session(Instant startAt, Instant endAt, String trainerName, String memberName, String status) {
    }

    public record Visit(Instant at, UUID profileId, String name, String role) {
    }

    private record Range(OffsetDateTime from, OffsetDateTime until) {
    }

    /** Both dates are Vietnam calendar days and both are included. */
    static Instant[] bounds(LocalDate from, LocalDate to) {
        if (to.isBefore(from) || ChronoUnit.DAYS.between(from, to) >= MAX_DAYS) {
            throw new IllegalArgumentException("Choose between 1 and " + MAX_DAYS + " days");
        }
        return new Instant[] { from.atStartOfDay(ZONE).toInstant(), to.plusDays(1).atStartOfDay(ZONE).toInstant() };
    }

    private static Range range(LocalDate from, LocalDate to) {
        var bounds = bounds(from, to);
        return new Range(bounds[0].atZone(ZONE).toOffsetDateTime(), bounds[1].atZone(ZONE).toOffsetDateTime());
    }

    @Transactional(readOnly = true)
    public List<Session> schedule(LocalDate from, LocalDate to) {
        var range = range(from, to);
        return jdbc.query("""
                SELECT b.start_at, b.end_at, t.full_name trainer, m.full_name member, b.status
                FROM bookings b
                JOIN personal_trainers t ON t.id = b.pt_id
                JOIN members m ON m.id = b.member_id
                WHERE b.start_at >= ? AND b.start_at < ?
                UNION ALL
                SELECT s.start_at, s.end_at, t.full_name, NULL, 'OPEN'
                FROM availability_slots s
                JOIN personal_trainers t ON t.id = s.pt_id
                WHERE s.status = 'AVAILABLE' AND s.start_at >= ? AND s.start_at < ?
                ORDER BY 1, 3
                """, (row, i) -> new Session(row.getObject(1, OffsetDateTime.class).toInstant(),
                row.getObject(2, OffsetDateTime.class).toInstant(), row.getString(3), row.getString(4),
                row.getString(5)), range.from(), range.until(), range.from(), range.until());
    }

    @Transactional(readOnly = true)
    public List<Visit> attendance(LocalDate from, LocalDate to) {
        var range = range(from, to);
        var result = new ArrayList<>(jdbc.query("""
                SELECT a.checked_in_at, m.full_name, m.id
                FROM attendance_records a JOIN members m ON m.id = a.member_id
                WHERE a.checked_in_at >= ? AND a.checked_in_at < ?
                """, (row, i) -> new Visit(row.getObject(1, OffsetDateTime.class).toInstant(),
                row.getObject(3, UUID.class), row.getString(2), "MEMBER"), range.from(), range.until()));
        var source = kiosk.getIfAvailable();
        if (source != null) {
            var names = new HashMap<UUID, String>();
            jdbc.query("SELECT id, full_name FROM personal_trainers",
                    row -> {
                        names.put(row.getObject(1, UUID.class), row.getString(2));
                    });
            for (var visit : source.trainerVisits()) {
                if (!visit.at().isBefore(range.from().toInstant()) && visit.at().isBefore(range.until().toInstant())) {
                    result.add(new Visit(visit.at(), visit.profileId(),
                            names.getOrDefault(visit.profileId(), "PT đã xóa"), "PT"));
                }
            }
        }
        result.sort(Comparator.comparing(Visit::at).reversed());
        return result;
    }
}
