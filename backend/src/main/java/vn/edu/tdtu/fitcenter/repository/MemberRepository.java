
package vn.edu.tdtu.fitcenter.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import vn.edu.tdtu.fitcenter.domain.entity.Member;

import java.util.Optional;
import java.util.UUID;

public interface MemberRepository
        extends JpaRepository<Member, UUID> {

    Optional<Member> findByUser_Id(UUID userId);
}
