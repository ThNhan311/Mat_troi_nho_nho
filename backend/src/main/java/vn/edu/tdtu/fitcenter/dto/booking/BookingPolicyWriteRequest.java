package vn.edu.tdtu.fitcenter.dto.booking;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import tools.jackson.core.JsonParser;
import tools.jackson.databind.DeserializationContext;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.annotation.JsonDeserialize;
import tools.jackson.databind.deser.std.StdDeserializer;

import java.util.Set;

@JsonDeserialize(using = BookingPolicyWriteRequest.Deserializer.class)
public record BookingPolicyWriteRequest(
        @NotNull @Min(1) Integer maxAdvanceDays,
        @NotNull @Min(0) Integer minNoticeHours,
        @NotNull @Min(0) Integer cancelDeadlineHours,
        @NotNull @Min(1) Integer maxFutureBookings
) {
    /** Local strict contract: no global Jackson coercion changes for other APIs. */
    public static final class Deserializer extends StdDeserializer<BookingPolicyWriteRequest> {
        private static final Set<String> FIELDS = Set.of("maxAdvanceDays", "minNoticeHours", "cancelDeadlineHours", "maxFutureBookings");

        public Deserializer() { super(BookingPolicyWriteRequest.class); }

        @Override public BookingPolicyWriteRequest deserialize(JsonParser parser, DeserializationContext context) {
            JsonNode node = context.readTree(parser);
            if (!node.isObject() || !FIELDS.containsAll(node.propertyNames())) {
                return context.reportInputMismatch(this, "Expected only the four booking policy configuration fields");
            }
            return new BookingPolicyWriteRequest(integer(node, "maxAdvanceDays", context), integer(node, "minNoticeHours", context),
                    integer(node, "cancelDeadlineHours", context), integer(node, "maxFutureBookings", context));
        }

        private Integer integer(JsonNode node, String field, DeserializationContext context) {
            JsonNode value = node.get(field);
            if (value == null || value.isNull()) return null; // Bean Validation reports required fields.
            if (!value.isIntegralNumber() || !value.canConvertToInt()) {
                return context.reportInputMismatch(this, "Policy configuration requires JSON integers in the database INTEGER range");
            }
            return value.intValue();
        }
    }
}
