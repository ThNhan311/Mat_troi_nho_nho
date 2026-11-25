package vn.edu.tdtu.fitcenter.activation;

import org.springframework.boot.flyway.autoconfigure.FlywayMigrationStrategy;
import org.springframework.context.annotation.*;
import org.springframework.core.env.Environment;
import java.sql.Connection;
import java.util.*;
import javax.sql.DataSource;

/** Fails before Flyway can apply any DDL to a non-rehearsal target. */
@Configuration
@Profile("activation-rehearsal")
public class ActivationRehearsalConfiguration {
    public static void verify(DataSource source, boolean verified) {
        if (!verified) throw new IllegalStateException("Run the guarded activation rehearsal runner");
        try (Connection c = source.getConnection(); var s = c.createStatement()) {
            String url = c.getMetaData().getURL();
            var target = java.net.URI.create(url.substring("jdbc:".length()));
            if (!"postgresql".equals(target.getScheme()) || !"127.0.0.1".equals(target.getHost()) || target.getPort()!=15439 || target.getUserInfo()!=null || target.getFragment()!=null || !target.getPath().matches("/fitcenter_activation_[a-f0-9]{12}_(empty|history)_test"))
                throw new IllegalStateException("Activation rehearsal requires its dedicated loopback database");
            try (var r = s.executeQuery("SELECT current_database(),current_user,rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls FROM pg_roles WHERE rolname=current_user")) {
                if (!r.next() || !target.getPath().equals("/" + r.getString(1)) || !r.getString(2).equals("fitcenter_activation_app") || r.getBoolean(3))
                    throw new IllegalStateException("Unexpected rehearsal database/role privileges");
            }
        } catch (java.sql.SQLException ex) {
            throw new IllegalStateException("Rehearsal datasource verification failed; SQLSTATE=" + ex.getSQLState());
        }
    }
    @Bean
    FlywayMigrationStrategy rehearsalMigration(Environment env) {
        return flyway -> {
            verify(flyway.getConfiguration().getDataSource(), env.getProperty("fitcenter.activation.guard-verified", Boolean.class, false));
            Set<String> locations = new HashSet<>();
            for (var l : flyway.getConfiguration().getLocations()) locations.add(l.getDescriptor());
            if (flyway.getConfiguration().isOutOfOrder() || !locations.equals(Set.of("classpath:db/migration", "classpath:db/activation-rehearsal")))
                throw new IllegalStateException("Unexpected Flyway rehearsal locations/order");
            flyway.migrate();
        };
    }
}
