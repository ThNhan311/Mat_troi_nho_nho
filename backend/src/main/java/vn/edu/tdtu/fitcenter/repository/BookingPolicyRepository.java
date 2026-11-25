package vn.edu.tdtu.fitcenter.repository;

import org.springframework.data.repository.Repository;
import vn.edu.tdtu.fitcenter.domain.entity.BookingPolicy;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

/** Intentionally exposes no save/delete operations for this read-only feature. */
public interface BookingPolicyRepository extends Repository<BookingPolicy, UUID> {
    Optional<BookingPolicy> findByActiveTrueAndEffectiveFromLessThanEqual(Instant now);
}
