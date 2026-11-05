
package vn.edu.tdtu.fitcenter.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import vn.edu.tdtu.fitcenter.domain.entity.PersonalTrainer;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import org.springframework.data.jpa.repository.EntityGraph;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PersonalTrainerRepository
        extends JpaRepository<PersonalTrainer, UUID> {
    @EntityGraph(attributePaths = "user")
    List<PersonalTrainer> findByUser_StatusOrderByFullNameAsc(AccountStatus status);

    @EntityGraph(attributePaths = "user")
    Optional<PersonalTrainer> findByIdAndUser_Status(UUID id, AccountStatus status);
}
