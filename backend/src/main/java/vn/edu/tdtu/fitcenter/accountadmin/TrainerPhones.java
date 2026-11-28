package vn.edu.tdtu.fitcenter.accountadmin;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.nio.file.Path;

/** Trainer phone numbers. */
@Component
public class TrainerPhones extends TrainerFile {
    public TrainerPhones(
            @Value("${fitcenter.trainer-phones.file:${user.home}/.fitcenter/trainer-phones.properties}") Path file) {
        super(file);
    }
}
