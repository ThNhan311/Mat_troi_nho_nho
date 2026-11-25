
package vn.edu.tdtu.fitcenter.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import jakarta.persistence.LockModeType;
import vn.edu.tdtu.fitcenter.domain.enums.MembershipStatus;
import vn.edu.tdtu.fitcenter.domain.entity.Membership;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface MembershipRepository
        extends JpaRepository<Membership, UUID> {

    List<Membership> findByMember_Id(UUID memberId);

    @Query("select m from Membership m where m.member.id=:memberId and m.status<>vn.edu.tdtu.fitcenter.domain.enums.MembershipStatus.CANCELLED")
    Optional<Membership> findCurrentForServiceEligibility(UUID memberId);

    @Lock(LockModeType.PESSIMISTIC_READ)
    Optional<Membership> findByMember_IdAndStatusNot(UUID memberId, MembershipStatus excludedStatus);
}
