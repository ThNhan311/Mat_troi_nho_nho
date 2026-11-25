package vn.edu.tdtu.fitcenter.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import vn.edu.tdtu.fitcenter.domain.enums.SlotStatus;
import vn.edu.tdtu.fitcenter.dto.response.AvailabilitySlotResponse;
import vn.edu.tdtu.fitcenter.service.AvailabilityService;

import java.time.OffsetDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/v1/pt/slots")
@RequiredArgsConstructor
public class PtAvailabilityController {
    private final AvailabilityService availabilityService;

    @GetMapping
    public List<AvailabilitySlotResponse> getMySlots(
            Authentication authentication,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to,
            @RequestParam(required = false) String status) {
        SlotStatus slotStatus = status == null ? null : SlotStatus.valueOf(status);
        return availabilityService.getMySlots(authentication.getName(), from, to, slotStatus);
    }
}
