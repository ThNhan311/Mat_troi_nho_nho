package vn.edu.tdtu.fitcenter.exception;

public class BookingPolicyNotFoundException extends RuntimeException {
    public static final String CODE = "BOOKING_POLICY_NOT_FOUND";

    public BookingPolicyNotFoundException() {
        super("Effective booking policy not found");
    }
}
