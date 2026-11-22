package vn.edu.tdtu.fitcenter.dto.account;

import jakarta.validation.constraints.*;
import tools.jackson.core.JsonParser;
import tools.jackson.databind.*;
import tools.jackson.databind.annotation.JsonDeserialize;
import tools.jackson.databind.deser.std.StdDeserializer;
import java.util.Set;

@JsonDeserialize(using = AccountCreateRequest.Deserializer.class)
public record AccountCreateRequest(@NotBlank @Email @Size(max=255) String email, @NotBlank String fullName) {
    @AssertTrue(message="fullName exceeds VARCHAR(150)")
    public boolean isNameWithinStorageLimit() { return fullName==null || fullName.codePointCount(0,fullName.length())<=150; }
    public static final class Deserializer extends StdDeserializer<AccountCreateRequest> {
        public Deserializer(){super(AccountCreateRequest.class);}
        @Override public AccountCreateRequest deserialize(JsonParser p, DeserializationContext c){
            JsonNode n=c.readTree(p);
            if(!n.isObject() || !Set.of("email","fullName").containsAll(n.propertyNames())) return c.reportInputMismatch(this,"Only email/fullName accepted");
            return new AccountCreateRequest(text(n,"email",c),text(n,"fullName",c));
        }
        private String text(JsonNode n,String key,DeserializationContext c){
            var v=n.get(key);if(v==null||v.isNull())return null;
            if(!v.isString()||v.stringValue().indexOf('\0')>=0)return c.reportInputMismatch(this,"Expected text");
            return v.stringValue();
        }
    }
}