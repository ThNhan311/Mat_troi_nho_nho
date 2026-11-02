
package vn.edu.tdtu.fitcenter.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import vn.edu.tdtu.fitcenter.domain.entity.MembershipPlan;
import vn.edu.tdtu.fitcenter.domain.enums.MembershipPlanStatus;

import java.util.List;
import java.util.UUID;

public interface MembershipPlanRepository
        extends JpaRepository<MembershipPlan, UUID> {

    List<MembershipPlan> findByStatus(MembershipPlanStatus status);
}
