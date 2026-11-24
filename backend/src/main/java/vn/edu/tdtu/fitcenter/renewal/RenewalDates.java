package vn.edu.tdtu.fitcenter.renewal;
import java.time.*;
public final class RenewalDates {
 public record Period(LocalDate start,LocalDate end){}
 public static Period next(Instant now,LocalDate lastPaidEnd,int days){
  if(days<1)throw new IllegalArgumentException("Positive duration required");
  LocalDate today=LocalDate.ofInstant(now,ZoneId.of("Asia/Ho_Chi_Minh"));
  try{LocalDate start=lastPaidEnd!=null&&!lastPaidEnd.isBefore(today)?lastPaidEnd.plusDays(1):today,end=start.plusDays((long)days-1);
   if(end.getYear()>5874897)throw new DateTimeException("PostgreSQL DATE range");return new Period(start,end);
  }catch(DateTimeException|ArithmeticException ex){throw new RenewalFailure(400,"ERR_RENEWAL_DATE_RANGE","Duration cannot be represented as a stored date");}
 }
 private RenewalDates(){}
}
