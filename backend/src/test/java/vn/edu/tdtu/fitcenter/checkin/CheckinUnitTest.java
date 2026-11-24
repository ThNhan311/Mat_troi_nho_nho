package vn.edu.tdtu.fitcenter.checkin;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.mock.env.MockEnvironment;
import tools.jackson.databind.ObjectMapper;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class CheckinUnitTest {
    final ObjectMapper json=new ObjectMapper();
    @ParameterizedTest @ValueSource(strings={"[]","{\"requestId\":12}","{\"requestId\":\"bad\"}","{\"captureRef\":false}","{\"memberId\":null}","{\"status\":\"SUCCESS\"}","{\"facialProfileId\":null}","{\"requestId\":null,\"requestId\":null}"})
    void strictRequestRejectsIdentityInjection(String input){assertThrows(Exception.class,()->json.readValue(input,CheckinRequest.class));}
    @Test void validOpaqueRequestHasNoOwnerFields(){var id=java.util.UUID.randomUUID();var capture=java.util.UUID.randomUUID();var r=json.readValue("{\"requestId\":\""+id+"\",\"captureRef\":\""+capture+"\"}",CheckinRequest.class);assertEquals(id,r.requestId());assertEquals(capture,r.captureRef());}
    @Test void gateOffNeverQueriesDatabase(){var source=mock(javax.sql.DataSource.class);var a=new FaceTestAdapter(false,false,"",new MockEnvironment(),source,json);a.afterPropertiesSet();assertFalse(a.authenticate("test-kiosk-a","not-a-key"));assertEquals(503,assertThrows(CheckinFailure.class,a::requireEnabled).status);verifyNoInteractions(source);}
    @Test void cannotEnableSimulatedAdapterOnDefaultProfile(){var source=mock(javax.sql.DataSource.class);assertThrows(IllegalStateException.class,()->new FaceTestAdapter(true,true,"",new MockEnvironment(),source,json).afterPropertiesSet());verifyNoInteractions(source);}
    @Test void simulationWithoutCoreGateFailsClosed(){var source=mock(javax.sql.DataSource.class);assertThrows(IllegalStateException.class,()->new FaceTestAdapter(false,true,"",new MockEnvironment(),source,json).afterPropertiesSet());verifyNoInteractions(source);}
}
