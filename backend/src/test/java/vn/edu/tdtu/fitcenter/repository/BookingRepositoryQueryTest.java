package vn.edu.tdtu.fitcenter.repository;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.data.domain.Sort;
import org.springframework.data.repository.query.parser.Part;
import org.springframework.data.repository.query.parser.PartTree;
import vn.edu.tdtu.fitcenter.domain.entity.Booking;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

// Checks Spring Data's query definition, not SQL execution or PostgreSQL integration.
class BookingRepositoryQueryTest {
    @ParameterizedTest
    @CsvSource({"memberId,false", "memberId,true", "ptId,false", "ptId,true"})
    void queriesUseOwnerIdInclusiveFromExclusiveToAndAscendingStart(String ownerProperty, boolean filtered) {
        String methodPrefix = "findBy" + Character.toUpperCase(ownerProperty.charAt(0)) + ownerProperty.substring(1);
        var method = Arrays.stream(BookingRepository.class.getDeclaredMethods())
                .filter(candidate -> candidate.getName().startsWith(methodPrefix))
                .filter(candidate -> candidate.getName().contains("AndStatus") == filtered)
                .findFirst().orElseThrow();
        PartTree query = new PartTree(method.getName(), Booking.class);
        List<Part> predicates = new ArrayList<>();
        query.getParts().forEach(predicates::add);

        assertEquals(filtered ? 4 : 3, predicates.size());
        assertTrue(predicates.stream().anyMatch(p -> p.getProperty().toDotPath().equals(ownerProperty)
                && p.getType() == Part.Type.SIMPLE_PROPERTY));
        assertTrue(predicates.stream().anyMatch(p -> p.getProperty().toDotPath().equals("startAt")
                && p.getType() == Part.Type.GREATER_THAN_EQUAL));
        assertTrue(predicates.stream().anyMatch(p -> p.getProperty().toDotPath().equals("startAt")
                && p.getType() == Part.Type.LESS_THAN));
        assertEquals(Sort.by(Sort.Direction.ASC, "startAt"), query.getSort());
        assertEquals(1, query.stream().count());
        if (filtered) {
            assertTrue(predicates.stream().anyMatch(p -> p.getProperty().toDotPath().equals("status")
                    && p.getType() == Part.Type.SIMPLE_PROPERTY));
        }
    }
}
