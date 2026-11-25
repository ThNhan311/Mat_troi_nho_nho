package vn.edu.tdtu.fitcenter.checkin;

import jakarta.validation.constraints.NotNull;
import java.util.UUID;
import tools.jackson.core.*;
import tools.jackson.databind.*;
import tools.jackson.databind.annotation.JsonDeserialize;
import tools.jackson.databind.deser.std.StdDeserializer;
import static vn.edu.tdtu.fitcenter.membershipinitial.InitialActivationRequest.uuid;

@JsonDeserialize(using=CheckinRequest.Reader.class)
public record CheckinRequest(@NotNull UUID requestId, @NotNull UUID captureRef) {
    public static final class Reader extends StdDeserializer<CheckinRequest> {
        public Reader() { super(CheckinRequest.class); }
        public CheckinRequest deserialize(JsonParser parser, DeserializationContext context) {
            if (!parser.isExpectedStartObjectToken()) return context.reportInputMismatch(CheckinRequest.class,"Object required");
            UUID request=null, capture=null;
            var seen=new java.util.HashSet<String>();
            while(parser.nextToken()!=JsonToken.END_OBJECT) {
                String field=parser.currentName();
                if(!java.util.Set.of("requestId","captureRef").contains(field)||!seen.add(field))
                    return context.reportInputMismatch(CheckinRequest.class,"Unknown or repeated field");
                var token=parser.nextToken(); UUID value=null;
                if(token!=JsonToken.VALUE_NULL) {
                    if(token!=JsonToken.VALUE_STRING) return context.reportInputMismatch(CheckinRequest.class,"UUID string required");
                    try { value=uuid(parser.getString()); } catch(Exception ex) { return context.reportInputMismatch(CheckinRequest.class,"UUID required"); }
                }
                if(field.equals("requestId"))request=value;else capture=value;
            }
            return new CheckinRequest(request,capture);
        }
    }
}
