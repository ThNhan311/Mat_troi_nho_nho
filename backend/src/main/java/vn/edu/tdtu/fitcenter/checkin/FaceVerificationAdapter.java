package vn.edu.tdtu.fitcenter.checkin;

import java.util.UUID;

/** Trusted server-side boundary. Captures are opaque; client member/profile claims are never inputs. */
public interface FaceVerificationAdapter {
    record Identity(String outcome,UUID profileId) {}
    boolean enabled();
    void requireEnabled();
    Identity verify(UUID captureRef);
    default Identity verify(UUID requestId,UUID captureRef){return verify(captureRef);}
}
