package vn.edu.tdtu.fitcenter.domain.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.Immutable;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "booking_policy")
@Immutable
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BookingPolicy {
    @Id
    private UUID id;

    @Column(name = "max_advance_days", nullable = false)
    private int maxAdvanceDays;

    @Column(name = "min_notice_hours", nullable = false)
    private int minNoticeHours;

    @Column(name = "cancel_deadline_hours", nullable = false)
    private int cancelDeadlineHours;

    @Column(name = "max_future_bookings", nullable = false)
    private int maxFutureBookings;

    @Column(name = "effective_from", nullable = false)
    private Instant effectiveFrom;

    @Column(name = "active", nullable = false)
    private boolean active;
}
