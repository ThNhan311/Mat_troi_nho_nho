package vn.edu.tdtu.fitcenter.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.tdtu.fitcenter.dto.booking.BookingPolicyResponse;
import vn.edu.tdtu.fitcenter.dto.booking.BookingPolicyWriteRequest;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;

@Repository
@RequiredArgsConstructor
@Transactional(propagation = Propagation.MANDATORY)
public class BookingPolicyWriteRepository {
    private static final String RETURNING = " RETURNING id,max_advance_days,min_notice_hours,cancel_deadline_hours,max_future_bookings,effective_from";
    private final JdbcTemplate jdbc;

    /** Caller holds the policy exclusive transaction lock. Inactive rows are never changed. */
    public BookingPolicyResponse store(BookingPolicyWriteRequest request, Instant now, UUID adminId) {
        UUID activeId = jdbc.query("SELECT id FROM booking_policy WHERE active=true", rs -> rs.next() ? rs.getObject(1, UUID.class) : null);
        UUID id = activeId == null ? UUID.randomUUID() : activeId;
        String sql = activeId == null
                ? "INSERT INTO booking_policy(id,max_advance_days,min_notice_hours,cancel_deadline_hours,max_future_bookings,effective_from,active,updated_by) VALUES(?,?,?,?,?,?,true,?)"
                : "UPDATE booking_policy SET max_advance_days=?,min_notice_hours=?,cancel_deadline_hours=?,max_future_bookings=?,effective_from=?,updated_by=? WHERE id=? AND active=true";
        Object[] args = activeId == null
                ? new Object[]{id, request.maxAdvanceDays(), request.minNoticeHours(), request.cancelDeadlineHours(), request.maxFutureBookings(), now.atOffset(ZoneOffset.UTC), adminId}
                : new Object[]{request.maxAdvanceDays(), request.minNoticeHours(), request.cancelDeadlineHours(), request.maxFutureBookings(), now.atOffset(ZoneOffset.UTC), adminId, id};
        return jdbc.queryForObject(sql + RETURNING, (rs, row) -> new BookingPolicyResponse(rs.getObject("id", UUID.class),
                rs.getInt("max_advance_days"), rs.getInt("min_notice_hours"), rs.getInt("cancel_deadline_hours"), rs.getInt("max_future_bookings"),
                rs.getObject("effective_from", OffsetDateTime.class).toInstant()), args);
    }
}
