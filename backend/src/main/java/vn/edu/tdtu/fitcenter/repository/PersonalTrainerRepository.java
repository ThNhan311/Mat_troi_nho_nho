
package vn.edu.tdtu.fitcenter.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import vn.edu.tdtu.fitcenter.domain.entity.PersonalTrainer;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PersonalTrainerRepository
        extends JpaRepository<PersonalTrainer, UUID> {
    @EntityGraph(attributePaths = "user")
    List<PersonalTrainer> findByUser_StatusOrderByFullNameAsc(AccountStatus status);

    @EntityGraph(attributePaths = "user")
    Optional<PersonalTrainer> findByIdAndUser_Status(UUID id, AccountStatus status);

    Optional<PersonalTrainer> findByUser_Id(UUID userId);

    // Serialize availability writes for one PT, including the case where no slot exists yet.
    // NO KEY UPDATE also permits FK key-share checks by a concurrent booking transaction.
    @Query(value = "select * from personal_trainers where user_id=:userId for no key update", nativeQuery = true)
    Optional<PersonalTrainer> findByUserIdForUpdate(UUID userId);
}
