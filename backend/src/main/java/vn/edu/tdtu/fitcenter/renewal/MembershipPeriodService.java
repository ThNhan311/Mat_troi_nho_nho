package vn.edu.tdtu.fitcenter.renewal;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import java.math.BigDecimal;import java.time.*;import java.util.*;
@Service
public class MembershipPeriodService {
 private final JdbcTemplate jdbc;private final boolean enabled;
 public MembershipPeriodService(JdbcTemplate jdbc,@Value("${fitcenter.renewal.enabled:false}")boolean enabled){this.jdbc=jdbc;this.enabled=enabled;}
 public boolean enabled(){return enabled;}
 public void initial(UUID member,UUID membership,UUID plan,String name,BigDecimal amount,int days,LocalDate start,LocalDate end,UUID payment){
  if(!enabled)return;
  jdbc.update("INSERT INTO membership_paid_periods(member_id,membership_id,plan_id,plan_name_snapshot,source,start_date,end_date,amount_snapshot,duration_days_snapshot,currency,payment_transaction_id) VALUES(?,?,?,?,'INITIAL_COUNTER',?,?,?,?,'VND',?)",member,membership,plan,name,start,end,amount,days,payment);
 }
 public List<Map<String,Object>> rows(UUID membership){
  return jdbc.queryForList("SELECT id,plan_id,plan_name_snapshot,source,start_date,end_date,amount_snapshot,duration_days_snapshot,currency,payment_transaction_id FROM membership_paid_periods WHERE membership_id=? ORDER BY start_date,id",membership);
 }
 private static LocalDate date(Map<String,Object> r,String name){return ((java.sql.Date)r.get(name)).toLocalDate();}
 public boolean covered(UUID membership,LocalDate start,LocalDate end){
  LocalDate cursor=start;
  for(var row:rows(membership)){LocalDate from=date(row,"start_date"),to=date(row,"end_date");if(to.isBefore(cursor))continue;if(from.isAfter(cursor))return false;if(!to.isBefore(end))return true;cursor=to.plusDays(1);}return false;
 }
 public Map<String,Object> current(UUID membership,LocalDate today){return rows(membership).stream().filter(r->!date(r,"start_date").isAfter(today)&&!date(r,"end_date").isBefore(today)).findFirst().orElse(null);}
 public Map<String,Object> summary(UUID membership,LocalDate today){var all=rows(membership);var current=all.stream().filter(r->!date(r,"start_date").isAfter(today)&&!date(r,"end_date").isBefore(today)).findFirst();if(current.isPresent())return current.get();return all.stream().filter(r->date(r,"end_date").isBefore(today)).max(Comparator.comparing(r->date(r,"end_date"))).orElse(null);}
 public List<Map<String,Object>> dto(UUID membership,LocalDate today){
  return rows(membership).stream().map(r->{var out=new LinkedHashMap<String,Object>();out.put("id",r.get("id"));out.put("planId",r.get("plan_id"));out.put("planName",r.get("plan_name_snapshot"));out.put("source",r.get("source"));out.put("startDate",date(r,"start_date").toString());out.put("endDate",date(r,"end_date").toString());out.put("amount",r.get("amount_snapshot")==null?null:((BigDecimal)r.get("amount_snapshot")).toPlainString());out.put("durationDays",r.get("duration_days_snapshot"));out.put("currency",r.get("currency"));out.put("paymentId",r.get("payment_transaction_id"));out.put("phase",date(r,"end_date").isBefore(today)?"HISTORY":date(r,"start_date").isAfter(today)?"NEXT":"CURRENT");return (Map<String,Object>)out;}).toList();
 }
}
