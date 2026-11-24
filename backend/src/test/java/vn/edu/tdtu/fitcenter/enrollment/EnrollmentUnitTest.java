package vn.edu.tdtu.fitcenter.enrollment;
import org.junit.jupiter.api.*;import org.junit.jupiter.params.ParameterizedTest;import org.junit.jupiter.params.provider.ValueSource;import org.springframework.mock.env.MockEnvironment;import tools.jackson.databind.ObjectMapper;import static org.junit.jupiter.api.Assertions.*;import static org.mockito.Mockito.*;
class EnrollmentUnitTest {
 @ParameterizedTest @ValueSource(strings={"[]","{\"templateRef\":\"fake\"}","{\"memberId\":null}","{\"consentAccepted\":1}","{\"consentVersion\":false}","{\"atGym\":true,\"atGym\":true}"}) void strictConsentRejectsClientClaims(String s){assertThrows(Exception.class,()->new ObjectMapper().readValue(s,EnrollmentRequest.class));}
 @Test void defaultAdapterDoesNotTouchDbOrFilesystem(){var ds=mock(javax.sql.DataSource.class);var a=new EnrollmentTestAdapter(false,"",new MockEnvironment(),ds,new ObjectMapper());a.afterPropertiesSet();assertFalse(a.enabled());assertNull(a.identify(java.util.UUID.randomUUID()));verifyNoInteractions(ds);}
 @Test void cannotEnableWithDefaultProfile(){var ds=mock(javax.sql.DataSource.class);assertThrows(IllegalStateException.class,()->new EnrollmentTestAdapter(true,"",new MockEnvironment(),ds,new ObjectMapper()).afterPropertiesSet());verifyNoInteractions(ds);}
}
