package vn.edu.tdtu.fitcenter.activation;
import java.time.Instant;
import java.util.*;
public interface ActivationStore {
    record Account(UUID id,String email,String role,String status,boolean pending) {}
    final class State {
        public UUID userId; public String otpDigest,grantDigest;
        public Instant otpExpiresAt,grantExpiresAt,windowStartedAt,lastSentAt,completedAt;
        public int attempts,sendCount;
        // Deliberately no toString: hashes/grants must not be dumped.
    }
    Optional<UUID> findUser(String email);
    Optional<UUID> findGrant(String digest);
    Account lockUser(UUID id);
    State lockState(UUID id);
    void save(State state);
    void activate(UUID userId,String encodedPassword);
}