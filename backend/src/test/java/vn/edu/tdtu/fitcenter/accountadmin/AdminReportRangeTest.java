package vn.edu.tdtu.fitcenter.accountadmin;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.*;

class AdminReportRangeTest {
    @Test
    void daysAreVietnamDaysAndBothEndsAreIncluded() {
        var day = LocalDate.of(2030, 1, 2);
        var bounds = AdminReportService.bounds(day, day);
        assertEquals(Instant.parse("2030-01-01T17:00:00Z"), bounds[0]);
        assertEquals(Instant.parse("2030-01-02T17:00:00Z"), bounds[1]);
    }

    @Test
    void reversedOrTooLongRangesAreRefused() {
        var day = LocalDate.of(2030, 1, 2);
        assertThrows(IllegalArgumentException.class, () -> AdminReportService.bounds(day, day.minusDays(1)));
        assertThrows(IllegalArgumentException.class,
                () -> AdminReportService.bounds(day, day.plusDays(AdminReportService.MAX_DAYS)));
        assertDoesNotThrow(() -> AdminReportService.bounds(day, day.plusDays(AdminReportService.MAX_DAYS - 1)));
    }
}
