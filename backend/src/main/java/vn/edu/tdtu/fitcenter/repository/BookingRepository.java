package vn.edu.tdtu.fitcenter.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import vn.edu.tdtu.fitcenter.domain.entity.Booking;
import vn.edu.tdtu.fitcenter.domain.enums.BookingStatus;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public interface BookingRepository extends JpaRepository<Booking, UUID> {
    List<Booking> findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
            UUID memberId, OffsetDateTime from, OffsetDateTime to);

    List<Booking> findByMemberIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
            UUID memberId, BookingStatus status, OffsetDateTime from, OffsetDateTime to);

    List<Booking> findByPtIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
            UUID ptId, OffsetDateTime from, OffsetDateTime to);

    List<Booking> findByPtIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
            UUID ptId, BookingStatus status, OffsetDateTime from, OffsetDateTime to);
}
