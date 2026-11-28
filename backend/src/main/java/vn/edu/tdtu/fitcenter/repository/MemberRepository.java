
package vn.edu.tdtu.fitcenter.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import vn.edu.tdtu.fitcenter.domain.entity.Member;
import vn.edu.tdtu.fitcenter.dto.booking.BookedMember;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface MemberRepository
        extends JpaRepository<Member, UUID> {

    Optional<Member> findByUser_Id(UUID userId);

    @Query(value = "select * from members where user_id=:userId for no key update", nativeQuery = true)
    Optional<Member> findByUserIdForUpdate(UUID userId);

    @Query(value = "select * from members where id=:id for no key update", nativeQuery = true)
    Optional<Member> findByIdForUpdate(UUID id);

    /** Members with at least one booking, of any status, with this trainer. */
    @Query("""
            select new vn.edu.tdtu.fitcenter.dto.booking.BookedMember(m.id, m.fullName, m.phone, m.gender)
            from Member m
            where m.id in (select b.memberId from Booking b where b.ptId = :ptId)
            """)
    List<BookedMember> findBookedWith(UUID ptId);
}
