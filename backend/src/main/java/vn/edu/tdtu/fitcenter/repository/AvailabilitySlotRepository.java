
package vn.edu.tdtu.fitcenter.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import vn.edu.tdtu.fitcenter.domain.entity.AvailabilitySlot;
import vn.edu.tdtu.fitcenter.domain.enums.SlotStatus;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public interface AvailabilitySlotRepository
        extends JpaRepository<AvailabilitySlot, UUID> {

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
