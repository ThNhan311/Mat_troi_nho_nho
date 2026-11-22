package vn.edu.tdtu.fitcenter.dto.membership;

import jakarta.validation.constraints.*;
import tools.jackson.core.JsonParser;
import tools.jackson.core.JsonToken;
import tools.jackson.databind.DeserializationContext;
import tools.jackson.databind.annotation.JsonDeserialize;
import tools.jackson.databind.deser.std.StdDeserializer;

import java.math.BigDecimal;
import java.util.HashSet;
import java.util.Set;

@JsonDeserialize(using = MembershipPlanCreateRequest.Deserializer.class)
public record MembershipPlanCreateRequest(
        @NotBlank String name,
        String description,
        @NotNull @Min(1) Integer durationDays,
        @NotNull @DecimalMin("0") @Digits(integer = 10, fraction = 2) BigDecimal price
) {
    @AssertTrue(message = "name must contain at most 100 characters")
    public boolean isNameWithinStorageLimit() {
        return name == null || name.codePointCount(0, name.length()) <= 100;
    }

    /** Strict only for this command. Read decimals directly from tokens, never through double. */
    public static final class Deserializer extends StdDeserializer<MembershipPlanCreateRequest> {
        private static final Set<String> FIELDS = Set.of("name", "description", "durationDays", "price");
        public Deserializer() { super(MembershipPlanCreateRequest.class); }
        @Override public MembershipPlanCreateRequest deserialize(JsonParser parser, DeserializationContext context) {
            if (!parser.isExpectedStartObjectToken()) return context.reportInputMismatch(this, "Expected a plan object");
            String name = null, description = null;
            Integer days = null;
            BigDecimal price = null;
            var seen = new HashSet<String>();
            while (parser.nextToken() != JsonToken.END_OBJECT) {
                String field = parser.currentName();
                if (!FIELDS.contains(field) || !seen.add(field)) {
                    return context.reportInputMismatch(this, "Unexpected or repeated plan field");
                }
                JsonToken token = parser.nextToken();
                if (token == JsonToken.VALUE_NULL) continue;
                switch (field) {
                    case "name", "description" -> {
                        if (token != JsonToken.VALUE_STRING) return context.reportInputMismatch(this, "Expected a JSON string");
                        String value = parser.getString();
                        if (value.indexOf('\0') >= 0) return context.reportInputMismatch(this, "Text cannot contain a zero character");
                        if (field.equals("name")) name = value; else description = value;
                    }
                    case "durationDays" -> {
                        if (token != JsonToken.VALUE_NUMBER_INT) return context.reportInputMismatch(this, "durationDays must be a JSON int32 integer");
                        var value = parser.getBigIntegerValue();
                        if (value.bitLength() > 31) return context.reportInputMismatch(this, "durationDays exceeds int32");
                        days = value.intValue();
                    }
                    case "price" -> {
                        if (token != JsonToken.VALUE_NUMBER_INT && token != JsonToken.VALUE_NUMBER_FLOAT) {
                            return context.reportInputMismatch(this, "price must be a JSON number");
                        }
                        price = parser.getDecimalValue();
                    }
                    default -> throw new IllegalStateException();
                }
            }
            return new MembershipPlanCreateRequest(name, description, days, price);
        }
    }
}