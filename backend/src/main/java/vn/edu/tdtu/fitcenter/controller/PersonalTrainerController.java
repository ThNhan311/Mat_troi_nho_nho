
package vn.edu.tdtu.fitcenter.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import vn.edu.tdtu.fitcenter.dto.response.AvailabilitySlotResponse;
import vn.edu.tdtu.fitcenter.dto.response.PersonalTrainerResponse;
import vn.edu.tdtu.fitcenter.service.PersonalTrainerService;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/trainers")
@RequiredArgsConstructor
public class PersonalTrainerController {

    private final PersonalTrainerService personalTrainerService;

    @GetMapping
    public ResponseEntity<List<PersonalTrainerResponse>> getAllTrainers() {
        return ResponseEntity.ok(
                personalTrainerService.getAllTrainers()
        );
    }

    @GetMapping("/{ptId}")
    public ResponseEntity<PersonalTrainerResponse> getTrainer(@PathVariable UUID ptId) {
        return ResponseEntity.ok(personalTrainerService.getTrainer(ptId));
    }

    @GetMapping({"/{ptId}/slots", "/{ptId}/availability"})
    public ResponseEntity<List<AvailabilitySlotResponse>> getAvailability(
            @PathVariable UUID ptId,
            @RequestParam
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME)
            OffsetDateTime from,
            @RequestParam
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME)
            OffsetDateTime to
    ) {
        return ResponseEntity.ok(
                personalTrainerService.getAvailableSlots(ptId, from, to)
        );
    }
}
