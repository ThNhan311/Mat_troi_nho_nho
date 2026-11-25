package vn.edu.tdtu.fitcenter.renewal;
import org.junit.jupiter.api.*;import org.junit.jupiter.params.ParameterizedTest;import org.junit.jupiter.params.provider.*;import java.time.*;import static org.junit.jupiter.api.Assertions.*;
class RenewalDatesTest {
 @ParameterizedTest @CsvSource({"2028-02-28T17:00:00Z,2028-02-28,1,2028-02-29,2028-02-29","2028-02-28T17:00:00Z,2028-02-29,2,2028-03-01,2028-03-02","2028-12-31T17:00:00Z,2028-12-31,30,2029-01-01,2029-01-30","2028-02-28T16:59:59Z,2028-02-28,1,2028-02-29,2028-02-29","2028-02-29T17:00:00Z,2028-03-31,3,2028-04-01,2028-04-03"})
 void inclusiveBusinessDates(String now,String last,int days,String start,String end){var p=RenewalDates.next(Instant.parse(now),LocalDate.parse(last),days);assertEquals(LocalDate.parse(start),p.start());assertEquals(LocalDate.parse(end),p.end());}
 @Test void noLastPeriodUsesBusinessToday(){assertEquals(LocalDate.of(2028,2,29),RenewalDates.next(Instant.parse("2028-02-28T17:00:00Z"),null,1).start());}
 @ParameterizedTest @ValueSource(ints={0,-1,Integer.MIN_VALUE})void invalidDuration(int days){assertThrows(IllegalArgumentException.class,()->RenewalDates.next(Instant.EPOCH,null,days));}
 @Test void overflowDoesNotSilentlyWrap(){assertThrows(RenewalFailure.class,()->RenewalDates.next(Instant.EPOCH,LocalDate.of(5874897,12,31),1));}
}
