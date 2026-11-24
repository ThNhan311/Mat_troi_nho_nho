package vn.edu.tdtu.fitcenter.enrollment;
import jakarta.validation.constraints.*;import tools.jackson.databind.*;import tools.jackson.core.*;import tools.jackson.databind.annotation.JsonDeserialize;import tools.jackson.databind.deser.std.StdDeserializer;
@JsonDeserialize(using=EnrollmentRequest.Reader.class)
public record EnrollmentRequest(@NotNull Boolean consentAccepted,@NotNull Boolean memberVerified,@NotNull Boolean atGym,@NotBlank @Size(max=64) String consentVersion){
 public static final class Reader extends StdDeserializer<EnrollmentRequest>{public Reader(){super(EnrollmentRequest.class);}public EnrollmentRequest deserialize(JsonParser p,DeserializationContext c){
  if(!p.isExpectedStartObjectToken())return c.reportInputMismatch(EnrollmentRequest.class,"Object required");var fields=new java.util.HashMap<String,Object>();
  while(p.nextToken()!=JsonToken.END_OBJECT){String k=p.currentName();if(!java.util.Set.of("consentAccepted","memberVerified","atGym","consentVersion").contains(k)||fields.containsKey(k))return c.reportInputMismatch(EnrollmentRequest.class,"Unknown or repeated field");var t=p.nextToken();Object v=null;
   if(t!=JsonToken.VALUE_NULL){if(k.equals("consentVersion")){if(t!=JsonToken.VALUE_STRING)return c.reportInputMismatch(EnrollmentRequest.class,"String required");v=p.getString();}else{if(t!=JsonToken.VALUE_TRUE&&t!=JsonToken.VALUE_FALSE)return c.reportInputMismatch(EnrollmentRequest.class,"Boolean required");v=t==JsonToken.VALUE_TRUE;}}fields.put(k,v);}
  return new EnrollmentRequest((Boolean)fields.get("consentAccepted"),(Boolean)fields.get("memberVerified"),(Boolean)fields.get("atGym"),(String)fields.get("consentVersion"));}
 }
}
