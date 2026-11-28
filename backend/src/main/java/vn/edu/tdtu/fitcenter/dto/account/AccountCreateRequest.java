package vn.edu.tdtu.fitcenter.dto.account;

import jakarta.validation.constraints.*;
import tools.jackson.core.JsonParser;
import tools.jackson.databind.*;
import tools.jackson.databind.annotation.JsonDeserialize;
import tools.jackson.databind.deser.std.StdDeserializer;
import java.util.Set;

@JsonDeserialize(using = AccountCreateRequest.Deserializer.class)
public record AccountCreateRequest(@NotBlank @Email @Size(max=255) String email, @NotBlank String fullName,
        @Pattern(regexp=PhoneNumbers.PATTERN, message="phone must be a Vietnamese number") String phone,
        @Pattern(regexp=Genders.PATTERN, message="gender must be MALE or FEMALE") String gender) {
    public AccountCreateRequest(String email, String fullName) { this(email, fullName, null, null); }
    @AssertTrue(message="fullName exceeds VARCHAR(150)")
    public boolean isNameWithinStorageLimit() { return fullName==null || fullName.codePointCount(0,fullName.length())<=150; }
    public static final class Deserializer extends StdDeserializer<AccountCreateRequest> {
        public Deserializer(){super(AccountCreateRequest.class);}
        @Override public AccountCreateRequest deserialize(JsonParser p, DeserializationContext c){
            JsonNode n=c.readTree(p);
            if(!n.isObject() || !Set.of("email","fullName","phone","gender").containsAll(n.propertyNames())) return c.reportInputMismatch(this,"Only email/fullName/phone/gender accepted");
            return new AccountCreateRequest(text(n,"email",c),text(n,"fullName",c),text(n,"phone",c),text(n,"gender",c));
        }
        private String text(JsonNode n,String key,DeserializationContext c){
            var v=n.get(key);if(v==null||v.isNull())return null;
            if(!v.isString()||v.stringValue().indexOf('\0')>=0)return c.reportInputMismatch(this,"Expected text");
            return v.stringValue();
        }
    }
}