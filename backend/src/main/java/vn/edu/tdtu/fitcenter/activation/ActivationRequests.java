package vn.edu.tdtu.fitcenter.activation;
import jakarta.validation.constraints.*;
public final class ActivationRequests {
 private ActivationRequests(){}
    public record EmailRequest(@NotBlank @Email @Size(max=255) @tools.jackson.databind.annotation.JsonDeserialize(using=vn.edu.tdtu.fitcenter.activation.StrictActivationText.class) String email){@Override public String toString(){return "EmailRequest[redacted]";}}
    public record VerifyRequest(@NotBlank @Email @Size(max=255) @tools.jackson.databind.annotation.JsonDeserialize(using=vn.edu.tdtu.fitcenter.activation.StrictActivationText.class) String email,@NotNull @Pattern(regexp="[0-9]{6}") @tools.jackson.databind.annotation.JsonDeserialize(using=vn.edu.tdtu.fitcenter.activation.StrictActivationText.class) String otp){@Override public String toString(){return "VerifyRequest[redacted]";}}
    public record PasswordRequest(@NotBlank @Size(min=43,max=43) @tools.jackson.databind.annotation.JsonDeserialize(using=vn.edu.tdtu.fitcenter.activation.StrictActivationText.class) String verificationToken,@NotBlank @tools.jackson.databind.annotation.JsonDeserialize(using=vn.edu.tdtu.fitcenter.activation.StrictActivationText.class) String password){@Override public String toString(){return "PasswordRequest[redacted]";}}
}
