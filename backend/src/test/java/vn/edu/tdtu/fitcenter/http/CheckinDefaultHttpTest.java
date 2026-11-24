package vn.edu.tdtu.fitcenter.http;

import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.annotation.DirtiesContext;
import java.net.URI;
import java.net.http.*;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest(webEnvironment=SpringBootTest.WebEnvironment.RANDOM_PORT,properties={"server.address=127.0.0.1","spring.main.banner-mode=off","logging.level.org.springframework.security=ERROR"})
@ActiveProfiles("default") @DirtiesContext(classMode=DirtiesContext.ClassMode.AFTER_CLASS)
@EnabledIfEnvironmentVariable(named="RUN_HTTP_BASELINE_TESTS",matches="true")
class CheckinDefaultHttpTest {
    @org.springframework.test.context.DynamicPropertySource static void guarded(org.springframework.test.context.DynamicPropertyRegistry properties){HttpBaselineTest.guardedDatasource(properties);}
    @LocalServerPort int port;
    @Test void publicSelfClaimedMatchCannotEnableDefaultAdapter()throws Exception {
        try(var http=HttpClient.newHttpClient()) {
            var request=HttpRequest.newBuilder(URI.create("http://127.0.0.1:"+port+"/api/v1/check-ins/face")).header("Content-Type","application/json").POST(HttpRequest.BodyPublishers.ofString("{\"memberId\":\"self-claimed\",\"recognized\":true}"));
            var result=http.send(request.build(),HttpResponse.BodyHandlers.ofString());assertEquals(503,result.statusCode());assertTrue(result.body().contains("ERR_CHECKIN_UNAVAILABLE"));assertTrue(result.headers().firstValue("Cache-Control").orElse("").contains("no-store"));
        }
    }
    @Test void publicHistoryStillRequiresMemberJwt()throws Exception {
        try(var http=HttpClient.newHttpClient()) {
            var result=http.send(HttpRequest.newBuilder(URI.create("http://127.0.0.1:"+port+"/api/v1/attendance/me?from=2026-01-01T00:00:00Z&to=2027-01-01T00:00:00Z")).GET().build(),HttpResponse.BodyHandlers.ofString());assertEquals(401,result.statusCode());assertTrue(result.body().contains("ERR_UNAUTHORIZED"));
        }
    }
}
