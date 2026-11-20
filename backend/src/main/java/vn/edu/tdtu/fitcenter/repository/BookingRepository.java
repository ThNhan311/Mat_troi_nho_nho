package vn.edu.tdtu.fitcenter.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import vn.edu.tdtu.fitcenter.domain.entity.Booking;
import vn.edu.tdtu.fitcenter.domain.enums.BookingStatus;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public interface BookingRepository extends JpaRepository<Booking, UUID> {
    boolean existsBySlotId(UUID slotId);
    boolean existsBySlotIdAndStatus(UUID slotId, BookingStatus status);

    @Query(value = """
            select exists(select 1 from bookings where pt_id=:ptId and status='CONFIRMED'
              and start_at<:endAt and end_at>:startAt)
            """, nativeQuery = true)
    boolean overlapsConfirmed(UUID ptId, OffsetDateTime startAt, OffsetDateTime endAt);

    @Query(value = """
            select exists(select 1 from bookings where member_id=:memberId and status='CONFIRMED'
              and start_at<:endAt and end_at>:startAt)
            """, nativeQuery = true)
    boolean overlapsMember(UUID memberId, OffsetDateTime startAt, OffsetDateTime endAt);

    @Query(value = "select count(*) from bookings where member_id=:memberId and status='CONFIRMED' and start_at>:now",
            nativeQuery = true)
    long countFutureConfirmed(UUID memberId, OffsetDateTime now);

    List<Booking> findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
            UUID memberId, OffsetDateTime from, OffsetDateTime to);

    List<Booking> findByMemberIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
            UUID memberId, BookingStatus status, OffsetDateTime from, OffsetDateTime to);

    List<Booking> findByPtIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
            UUID ptId, OffsetDateTime from, OffsetDateTime to);

    List<Booking> findByPtIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
            UUID ptId, BookingStatus status, OffsetDateTime from, OffsetDateTime to);
}
