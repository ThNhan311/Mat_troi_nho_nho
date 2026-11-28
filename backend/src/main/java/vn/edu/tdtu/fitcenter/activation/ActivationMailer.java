package vn.edu.tdtu.fitcenter.activation;
public interface ActivationMailer {
    void send(String email,String otp);
    /** Senders that word their own mail override this; others deliver the code as usual. */
    default void sendPasswordReset(String email,String otp){send(email,otp);}
}