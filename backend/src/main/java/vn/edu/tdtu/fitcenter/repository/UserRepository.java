package vn.edu.tdtu.fitcenter.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;

import java.util.Optional;
import java.util.UUID;

public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByEmailIgnoreCase(String email);

    boolean existsByEmailIgnoreCase(String email);

    boolean existsByIdAndRoleAndStatus(UUID id, Role role, AccountStatus status);

    default Optional<User> findByEmail(String email) {
        return findByEmailIgnoreCase(email);
    }

    default boolean existsByEmail(String email) {
        return existsByEmailIgnoreCase(email);
    }
}
