
package vn.edu.tdtu.fitcenter.service;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import vn.edu.tdtu.fitcenter.domain.entity.PersonalTrainer;
import vn.edu.tdtu.fitcenter.domain.enums.SlotStatus;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.dto.response.AvailabilitySlotResponse;
import vn.edu.tdtu.fitcenter.dto.response.PersonalTrainerResponse;
import vn.edu.tdtu.fitcenter.repository.AvailabilitySlotRepository;
import vn.edu.tdtu.fitcenter.repository.PersonalTrainerRepository;

import java.time.OffsetDateTime;
import java.time.Clock;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PersonalTrainerService {

    private final PersonalTrainerRepository personalTrainerRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final Clock clock;

    public List<PersonalTrainerResponse> getAllTrainers() {
        return personalTrainerRepository
                .findByUser_StatusOrderByFullNameAsc(AccountStatus.ACTIVE).stream()
                .map(this::toTrainerResponse)
                .toList();
    }

    public PersonalTrainerResponse getTrainer(UUID ptId) {
        return toTrainerResponse(findActiveTrainer(ptId));
    }

    private PersonalTrainer findActiveTrainer(UUID ptId) {
        return personalTrainerRepository.findByIdAndUser_Status(ptId, AccountStatus.ACTIVE)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "Personal trainer not found"));
    }

    public List<AvailabilitySlotResponse> getAvailableSlots(
            UUID ptId,
            OffsetDateTime from,
            OffsetDateTime to
    ) {
        if (from == null || to == null || !from.isBefore(to)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "'from' must be earlier than 'to'"
            );
        }

        findActiveTrainer(ptId);
        OffsetDateTime now = OffsetDateTime.now(clock);

        return availabilitySlotRepository
                .findByPersonalTrainerIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                        ptId,
                        SlotStatus.AVAILABLE,
                        from,
                        to
                )
                .stream()
                .filter(slot -> slot.getStartAt().isAfter(now))
                .map(slot -> new AvailabilitySlotResponse(
                        slot.getId(),
                        ptId,
                        slot.getStartAt(),
                        slot.getEndAt(),
                        slot.getStatus().name()
                ))
                .toList();
    }

    private PersonalTrainerResponse toTrainerResponse(
            PersonalTrainer trainer
    ) {
        return new PersonalTrainerResponse(
                trainer.getId(),
                trainer.getFullName(),
                trainer.getBio(),
                trainer.getSpecialization(),
                trainer.getExperienceSummary()
        );
    }
}
