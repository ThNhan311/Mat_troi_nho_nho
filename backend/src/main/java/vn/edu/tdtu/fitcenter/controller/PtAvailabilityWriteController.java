package vn.edu.tdtu.fitcenter.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vn.edu.tdtu.fitcenter.dto.request.AvailabilityWriteRequest;
import vn.edu.tdtu.fitcenter.dto.response.AvailabilitySlotResponse;
import vn.edu.tdtu.fitcenter.service.AvailabilityWriteService;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/pt/availability")
@RequiredArgsConstructor
public class PtAvailabilityWriteController {
    private final AvailabilityWriteService service;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AvailabilitySlotResponse create(Authentication auth, @RequestBody AvailabilityWriteRequest request) {
        return service.create(auth.getName(), request);
    }

    @PatchMapping("/{slotId}")
    public AvailabilitySlotResponse update(Authentication auth, @PathVariable UUID slotId,
                                           @RequestBody AvailabilityWriteRequest request) {
        return service.update(auth.getName(), slotId, request);
    }

    @DeleteMapping("/{slotId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void disable(Authentication auth, @PathVariable UUID slotId) {
        service.disable(auth.getName(), slotId);
    }
}
