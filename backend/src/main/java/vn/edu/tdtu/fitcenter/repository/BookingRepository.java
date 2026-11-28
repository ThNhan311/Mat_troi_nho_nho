package vn.edu.tdtu.fitcenter.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.Lock;
import jakarta.persistence.LockModeType;
import vn.edu.tdtu.fitcenter.dto.booking.BookingLink;
import vn.edu.tdtu.fitcenter.domain.entity.Booking;
import vn.edu.tdtu.fitcenter.domain.enums.BookingStatus;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface BookingRepository extends JpaRepository<Booking, UUID> {
    @Query("select new vn.edu.tdtu.fitcenter.dto.booking.BookingLink(b.memberId,b.ptId,b.slotId) from Booking b where b.id=:id")
    Optional<BookingLink> findLink(UUID id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select b from Booking b where b.id=:id")
    Optional<Booking> findByIdForUpdate(UUID id);

    boolean existsBySlotIdAndStatusAndIdNot(UUID slotId, BookingStatus status, UUID excludedId);

    boolean existsBySlotId(UUID slotId);
    boolean existsByPtIdAndMemberId(UUID ptId, UUID memberId);
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
