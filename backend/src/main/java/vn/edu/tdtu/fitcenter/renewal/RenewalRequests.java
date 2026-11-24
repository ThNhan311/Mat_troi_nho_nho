package vn.edu.tdtu.fitcenter.renewal;
import jakarta.validation.constraints.*;import java.math.BigDecimal;import java.util.*;
import tools.jackson.core.*;import tools.jackson.databind.*;import tools.jackson.databind.annotation.JsonDeserialize;import tools.jackson.databind.deser.std.StdDeserializer;
import static vn.edu.tdtu.fitcenter.membershipinitial.InitialActivationRequest.uuid;
public final class RenewalRequests {
 @JsonDeserialize(using=CreateReader.class) public record Create(@NotNull UUID planId){}
 @JsonDeserialize(using=EventReader.class) public record Event(@NotNull UUID eventId,@NotBlank @Size(max=100) String providerRef,
 @NotNull @DecimalMin("0") @Digits(integer=10,fraction=2) BigDecimal amount,
 @NotNull @Pattern(regexp="[A-Z]{3}") String currency,@NotNull @Pattern(regexp="SUCCESS|FAILED|CANCELLED") String status){}
 static Map<String,Object> fields(JsonParser p,DeserializationContext c,Set<String> allowed){
  if(!p.isExpectedStartObjectToken())return c.reportInputMismatch(RenewalRequests.class,"Object required");var result=new HashMap<String,Object>();
  while(p.nextToken()!=JsonToken.END_OBJECT){String f=p.currentName();if(!allowed.contains(f)||result.containsKey(f))return c.reportInputMismatch(RenewalRequests.class,"Unknown or repeated field");var t=p.nextToken();Object v=null;
   if(t!=JsonToken.VALUE_NULL){if(f.equals("amount")){if(t!=JsonToken.VALUE_NUMBER_INT&&t!=JsonToken.VALUE_NUMBER_FLOAT)return c.reportInputMismatch(RenewalRequests.class,"JSON number required");v=p.getDecimalValue();}
    else{if(t!=JsonToken.VALUE_STRING)return c.reportInputMismatch(RenewalRequests.class,"String required");String text=p.getString();if(text.indexOf(0)>=0)return c.reportInputMismatch(RenewalRequests.class,"Invalid character");try{v=f.equals("planId")||f.equals("eventId")?uuid(text):text;}catch(IllegalArgumentException ex){return c.reportInputMismatch(RenewalRequests.class,"UUID required");}}}
   result.put(f,v);
  }return result;
 }
 public static class CreateReader extends StdDeserializer<Create>{public CreateReader(){super(Create.class);}public Create deserialize(JsonParser p,DeserializationContext c){var m=fields(p,c,Set.of("planId"));return new Create((UUID)m.get("planId"));}}
 public static class EventReader extends StdDeserializer<Event>{public EventReader(){super(Event.class);}public Event deserialize(JsonParser p,DeserializationContext c){var m=fields(p,c,Set.of("eventId","providerRef","amount","currency","status"));return new Event((UUID)m.get("eventId"),(String)m.get("providerRef"),(BigDecimal)m.get("amount"),(String)m.get("currency"),(String)m.get("status"));}}
 private RenewalRequests(){}
}
