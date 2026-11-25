package vn.edu.tdtu.fitcenter.activation;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.mock.env.MockEnvironment;
import static org.junit.jupiter.api.Assertions.*;
class CoreDemoGuardTest {
 private MockEnvironment env(){var e=new MockEnvironment();e.setActiveProfiles("core-demo");return e.withProperty("fitcenter.account-integration.guard-verified","true").withProperty("fitcenter.renewal.guard-verified","true");}
 @Test void explicitPrivateCoreAllowsFaceOff(){assertDoesNotThrow(()->AccountIntegrationRehearsalConfiguration.verifyCoreDemoOptions(env()));}
 @ParameterizedTest @ValueSource(strings={"fitcenter.face-service.enabled", "fitcenter.checkin.enabled","fitcenter.checkin.test-adapter.enabled","fitcenter.enrollment.enabled","fitcenter.account-integration.guard-verified","fitcenter.renewal.guard-verified"})
 void refusesFaceOrMissingAuthority(String property){var e=env().withProperty(property,property.endsWith("guard-verified")?"false":"true");assertThrows(IllegalStateException.class,()->AccountIntegrationRehearsalConfiguration.verifyCoreDemoOptions(e));}
 @Test void cannotMixProfiles(){var e=env();e.setActiveProfiles("core-demo","face-enrollment-rehearsal");assertThrows(IllegalStateException.class,()->AccountIntegrationRehearsalConfiguration.verifyCoreDemoOptions(e));}
}
