package vn.edu.tdtu.fitcenter.accountadmin;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.nio.file.Path;

/** Trainer genders, as MALE or FEMALE. */
@Component
public class TrainerGenders extends TrainerFile {
    public TrainerGenders(
            @Value("${fitcenter.trainer-genders.file:${user.home}/.fitcenter/trainer-genders.properties}") Path file) {
        super(file);
    }
}
