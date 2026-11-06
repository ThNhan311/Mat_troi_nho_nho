package vn.edu.tdtu.fitcenter.service;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import vn.edu.tdtu.fitcenter.domain.entity.AvailabilitySlot;
import vn.edu.tdtu.fitcenter.domain.entity.PersonalTrainer;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.domain.enums.SlotStatus;
import vn.edu.tdtu.fitcenter.dto.response.AvailabilitySlotResponse;
import vn.edu.tdtu.fitcenter.repository.AvailabilitySlotRepository;
import vn.edu.tdtu.fitcenter.repository.PersonalTrainerRepository;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

import java.time.OffsetDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AvailabilityService {
    private final UserRepository userRepository;
    private final PersonalTrainerRepository personalTrainerRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;

    public List<AvailabilitySlotResponse> getMySlots(
            String email, OffsetDateTime from, OffsetDateTime to, SlotStatus status) {
        if (from == null || to == null || !from.isBefore(to)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "'from' must be earlier than 'to'");
        }

        User user = userRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new BadCredentialsException("User not found"));
        if (user.getRole() != Role.PT || user.getStatus() != AccountStatus.ACTIVE) {
            throw new AccessDeniedException("Only active personal trainers can access this resource");
        }

        PersonalTrainer trainer = personalTrainerRepository.findByUser_Id(user.getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Personal trainer profile not found"));

        List<AvailabilitySlot> slots = status == null
                ? availabilitySlotRepository
                    .findByPersonalTrainerIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                            trainer.getId(), from, to)
                : availabilitySlotRepository
                    .findByPersonalTrainerIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                            trainer.getId(), status, from, to);

        return slots.stream()
                .map(slot -> new AvailabilitySlotResponse(slot.getId(), trainer.getId(),
                        slot.getStartAt(), slot.getEndAt(), slot.getStatus().name()))
                .toList();
    }
}
