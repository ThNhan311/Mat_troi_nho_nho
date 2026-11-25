package vn.edu.tdtu.fitcenter.activation;
import tools.jackson.core.*;
import tools.jackson.databind.*;
import tools.jackson.databind.deser.std.StdDeserializer;
/** Avoid coercing numeric OTP/password/email input into strings. */
public class StrictActivationText extends StdDeserializer<String> {
    public StrictActivationText(){super(String.class);}
    @Override public String deserialize(JsonParser p,DeserializationContext c){if(p.currentToken()!=JsonToken.VALUE_STRING)return c.reportInputMismatch(this,"Expected JSON string");return p.getString();}
}