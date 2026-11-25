
package vn.edu.tdtu.fitcenter.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import vn.edu.tdtu.fitcenter.domain.entity.Member;

import java.util.Optional;
import java.util.UUID;

public interface MemberRepository
        extends JpaRepository<Member, UUID> {

    Optional<Member> findByUser_Id(UUID userId);

    @Query(value = "select * from members where user_id=:userId for no key update", nativeQuery = true)
    Optional<Member> findByUserIdForUpdate(UUID userId);

    @Query(value = "select * from members where id=:id for no key update", nativeQuery = true)
    Optional<Member> findByIdForUpdate(UUID id);
}
