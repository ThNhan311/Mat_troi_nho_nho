package vn.edu.tdtu.fitcenter.membershipinitial;
import jakarta.validation.constraints.*;
import tools.jackson.core.*;
import tools.jackson.databind.*;
import tools.jackson.databind.annotation.JsonDeserialize;
import tools.jackson.databind.deser.std.StdDeserializer;
import java.math.BigDecimal;
import java.text.Normalizer;
import java.util.*;
@JsonDeserialize(using=InitialActivationRequest.Deserializer.class)
public record InitialActivationRequest(@NotNull UUID planId,
 @NotNull @DecimalMin("0") @Digits(integer=10,fraction=2) BigDecimal amountCollected,
 @NotBlank String receiptRef, String note) {
 public InitialActivationRequest {receiptRef=normalize(receiptRef);note=normalize(note);if(note!=null&&note.isBlank())note=null;}
 public static String normalize(String s){return s==null?null:Normalizer.normalize(s,Normalizer.Form.NFC).strip();}
 public String receiptKey(){return receiptRef.toUpperCase(Locale.ROOT);}
 @AssertTrue(message="Receipt must contain at most 100 characters; note at most 500")
 public boolean isTextWithinLimits(){return (receiptRef==null || (receiptRef.codePointCount(0,receiptRef.length())<=100 && receiptKey().codePointCount(0,receiptKey().length())<=100)) && (note==null||note.codePointCount(0,note.length())<=500);}
 public static UUID uuid(String s){if(s==null||!s.matches("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"))throw new IllegalArgumentException("UUID required");return UUID.fromString(s);}
 public static class Deserializer extends StdDeserializer<InitialActivationRequest>{
  public Deserializer(){super(InitialActivationRequest.class);}
  public InitialActivationRequest deserialize(JsonParser p,DeserializationContext c){
   if(!p.isExpectedStartObjectToken())return c.reportInputMismatch(this,"Object required");
   UUID plan=null;BigDecimal amount=null;String receipt=null,note=null;var seen=new HashSet<String>();
   while(p.nextToken()!=JsonToken.END_OBJECT){String f=p.currentName();if(!Set.of("planId","amountCollected","receiptRef","note").contains(f)||!seen.add(f))return c.reportInputMismatch(this,"Unexpected or repeated field");var t=p.nextToken();if(t==JsonToken.VALUE_NULL)continue;
    if(f.equals("amountCollected")){if(t!=JsonToken.VALUE_NUMBER_INT&&t!=JsonToken.VALUE_NUMBER_FLOAT)return c.reportInputMismatch(this,"JSON number required");amount=p.getDecimalValue();}
    else{if(t!=JsonToken.VALUE_STRING)return c.reportInputMismatch(this,"String required");String v=p.getString();if(v.indexOf(0)>=0)return c.reportInputMismatch(this,"Zero character not allowed");if(f.equals("planId")){try{plan=uuid(v);}catch(IllegalArgumentException e){return c.reportInputMismatch(this,"UUID required");}}else if(f.equals("receiptRef"))receipt=v;else note=v;}
   }return new InitialActivationRequest(plan,amount,receipt,note);
  }
 }
}
