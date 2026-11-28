package vn.edu.tdtu.fitcenter.dto.account;

public final class PhoneNumbers {
    /** Ten digits starting with 0, or +84 followed by nine digits. */
    public static final String PATTERN = "^(0|\\+84)[0-9]{9}$";

    private PhoneNumbers() {
    }
}
