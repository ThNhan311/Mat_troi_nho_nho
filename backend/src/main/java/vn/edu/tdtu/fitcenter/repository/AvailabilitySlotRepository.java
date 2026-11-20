
package vn.edu.tdtu.fitcenter.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import jakarta.persistence.LockModeType;
import vn.edu.tdtu.fitcenter.domain.entity.AvailabilitySlot;
import vn.edu.tdtu.fitcenter.domain.enums.SlotStatus;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface AvailabilitySlotRepository
        extends JpaRepository<AvailabilitySlot, UUID> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from AvailabilitySlot s where s.id = :id and s.personalTrainer.id = :ptId")
    Optional<AvailabilitySlot> findOwnedByIdForUpdate(UUID id, UUID ptId);

    @Query(value = """
            select exists(select 1 from availability_slots
              where pt_id=:ptId and id<>:excludedId and status<>'DISABLED'
                and start_at<:endAt and end_at>:startAt)
            """, nativeQuery = true)
    boolean overlaps(UUID ptId, UUID excludedId, OffsetDateTime startAt, OffsetDateTime endAt);

    List<AvailabilitySlot>
    findByPersonalTrainerIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
            UUID ptId,
            OffsetDateTime from,
            OffsetDateTime to
    );

    List<AvailabilitySlot>
    findByPersonalTrainerIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
            UUID ptId,
            SlotStatus status,
            OffsetDateTime from,
            OffsetDateTime to
    );
}
