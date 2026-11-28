package vn.edu.tdtu.fitcenter.password;

import vn.edu.tdtu.fitcenter.activation.ActivationFailure;

import java.nio.charset.StandardCharsets;

/** The same limits as account activation: BCrypt reads at most 72 bytes. */
final class PasswordRules {
    private PasswordRules() {
    }

    static void check(String password) {
        if (password == null || password.isBlank() || password.codePointCount(0, password.length()) < 8
                || password.getBytes(StandardCharsets.UTF_8).length > 72) {
            throw new ActivationFailure(400, "ERR_VALIDATION",
                    "Mật khẩu cần ít nhất 8 ký tự và tối đa 72 byte.");
        }
    }
}
