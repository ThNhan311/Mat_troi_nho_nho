package vn.edu.tdtu.fitcenter.service;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import vn.edu.tdtu.fitcenter.accountadmin.TrainerGenders;
import vn.edu.tdtu.fitcenter.accountadmin.TrainerPhones;
import vn.edu.tdtu.fitcenter.domain.entity.PersonalTrainer;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.dto.request.PtProfileWriteRequest;
import vn.edu.tdtu.fitcenter.dto.response.PersonalTrainerResponse;
import vn.edu.tdtu.fitcenter.repository.PersonalTrainerRepository;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

/** A trainer's own public profile. The name stays under Admin control. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PtProfileService {
    private final UserRepository users;
    private final PersonalTrainerRepository trainers;
    private final TrainerPhones phones;
    private final TrainerGenders genders;

    public PersonalTrainerResponse mine(String email) {
        return response(trainers.findByUser_Id(activeTrainerUser(email).getId())
                .orElseThrow(PtProfileService::noProfile));
    }

    @Transactional
    public PersonalTrainerResponse update(String email, PtProfileWriteRequest request) {
        PersonalTrainer trainer = trainers.findByUserIdForUpdate(activeTrainerUser(email).getId())
                .orElseThrow(PtProfileService::noProfile);
        trainer.setBio(clean(request.bio()));
        trainer.setSpecialization(clean(request.specialization()));
        trainer.setExperienceSummary(clean(request.experienceSummary()));
        return response(trainer);
    }

    private User activeTrainerUser(String email) {
        User user = users.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new BadCredentialsException("User not found"));
        if (user.getRole() != Role.PT || user.getStatus() != AccountStatus.ACTIVE) {
            throw new AccessDeniedException("Only active personal trainers can access this resource");
        }
        return user;
    }

    private static ResponseStatusException noProfile() {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, "Personal trainer profile not found");
    }

    private static String clean(String value) {
        return value == null || value.isBlank() ? null : value.strip();
    }

    private PersonalTrainerResponse response(PersonalTrainer trainer) {
        return new PersonalTrainerResponse(trainer.getId(), trainer.getFullName(), trainer.getBio(),
                trainer.getSpecialization(), trainer.getExperienceSummary(),
                phones.find(trainer.getId()).orElse(null),
                genders.find(trainer.getId()).orElse(null));
    }
}
