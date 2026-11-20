package vn.edu.tdtu.fitcenter.http;

import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.junit.jupiter.api.parallel.Execution;
import org.junit.jupiter.api.parallel.ExecutionMode;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.ObjectMapper;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.time.Duration;
import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.*;
import java.util.regex.Pattern;
import java.util.concurrent.atomic.AtomicReference;
import java.util.concurrent.*;
import java.util.stream.IntStream;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.*;

/** Actual HTTP + PostgreSQL, opt-in only. No MockMvc, test endpoints or production overrides. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
        "server.address=127.0.0.1", "logging.level.org.springframework.boot=ERROR",
        "logging.level.org.springframework.security=ERROR", "spring.main.banner-mode=off"
})
@ActiveProfiles("default")
@Import(HttpBaselineTest.ClockConfiguration.class)
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
@Execution(ExecutionMode.SAME_THREAD)
@EnabledIfEnvironmentVariable(named = "RUN_HTTP_BASELINE_TESTS", matches = "true")
class HttpBaselineTest {
    @LocalServerPort int port;
    @Autowired JdbcTemplate jdbc;
    @Autowired PasswordEncoder encoder;
    @Autowired PlatformTransactionManager transactions;
    @Autowired ObjectMapper json;
    @Autowired ControllableClock testClock;
    private HttpBaselineFixture fixture;
    private HttpClient client;
    private final Map<String, String> accessTokens = new HashMap<>();
    private final Set<UUID> writeSlots = ConcurrentHashMap.newKeySet();
    private final Set<UUID> writeBookings = ConcurrentHashMap.newKeySet();

    @DynamicPropertySource
    static void guardedDatasource(DynamicPropertyRegistry properties) {
        if (Runtime.version().feature() != 21) throw new IllegalStateException("JDK 21 required");
        if (!"true".equals(System.getenv("HTTP_BASELINE_GUARD_VERIFIED"))) {
            throw new IllegalStateException("Run through backend/scripts/test-http-baseline.ps1");
        }
        String url = required("DB_URL"), user = required("DB_USERNAME"), password = required("DB_PASSWORD");
        String expectedDb = required("HTTP_BASELINE_EXPECTED_DATABASE");
        var matcher = Pattern.compile("^jdbc:postgresql://127\\.0\\.0\\.1:[0-9]+/(fitcenter_(?:baseline|http)_[a-z0-9_]+_test)$").matcher(url);
        if (!matcher.matches() || !matcher.group(1).equals(expectedDb)) {
            throw new IllegalStateException("Only an explicitly verified loopback test database is allowed");
        }
        // Runs before Spring creates its datasource/Flyway: do not migrate an unverified target.
        try (var connection = DriverManager.getConnection(url, user, password);
             var statement = connection.createStatement()) {
            try (var result = statement.executeQuery("SELECT current_database(),current_user,rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls FROM pg_roles WHERE rolname=current_user")) {
                if (!result.next() || !expectedDb.equals(result.getString(1)) || !user.equals(result.getString(2)) || result.getBoolean(3)) {
                    throw new IllegalStateException("Database/role verification failed");
                }
            }
            try (var result = statement.executeQuery("SELECT string_agg(version,',' ORDER BY installed_rank),bool_and(success) FROM flyway_schema_history WHERE version IS NOT NULL")) {
                if (!result.next() || !"1,2,3,4,5,6".equals(result.getString(1)) || !result.getBoolean(2)) {
                    throw new IllegalStateException("An existing verified canonical V1-V6 schema is required; V7 is forbidden");
                }
            }
        } catch (SQLException error) {
            throw new IllegalStateException("Database preflight failed; SQLSTATE=" + error.getSQLState());
        }
        properties.add("spring.datasource.url", () -> url);
        properties.add("spring.datasource.username", () -> user);
        properties.add("spring.datasource.password", () -> password);
        properties.add("spring.flyway.locations", () -> "classpath:db/migration");
        String jwtSecret = HttpBaselineFixture.randomSecret();
        properties.add("jwt.secret", () -> jwtSecret);
    }

    private static String required(String name) {
        String value = System.getenv(name);
        if (value == null || value.isBlank()) throw new IllegalStateException("Missing environment variable " + name);
        return value;
    }

    @BeforeAll void createFixture() {
        if (jdbc.queryForObject("SELECT count(*) FROM booking_policy", Integer.class) != 0) {
            throw new IllegalStateException("Policy scenarios require an empty booking_policy on the isolated test DB; do not clear existing data");
        }
        client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5))
                .followRedirects(HttpClient.Redirect.NEVER).build();
        fixture = new HttpBaselineFixture(jdbc, new TransactionTemplate(transactions));
        fixture.seed(encoder);
    }

    @AfterAll void removeOnlyThisFixture() {
        try { if (fixture != null) fixture.close(); }
        finally {
            accessTokens.clear();
            if (client != null) client.close();
        }
    }

    @AfterEach void restoreSystemTime() {
        testClock.fixed.set(null);
        // Exact UUIDs produced by this scenario only; no broad delete by PT, time or status.
        new TransactionTemplate(transactions).executeWithoutResult(status -> {
            for (UUID id : writeBookings) assertEquals(1, jdbc.update("DELETE FROM bookings WHERE id=?", id));
            for (UUID id : writeSlots) assertEquals(1, jdbc.update("DELETE FROM availability_slots WHERE id=?", id));
        });
        writeBookings.clear();
        writeSlots.clear();
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class ClockConfiguration {
        @Bean @Primary ControllableClock httpBaselineClock() {
            return new ControllableClock(new AtomicReference<>(), ZoneOffset.UTC);
        }
    }

    static final class ControllableClock extends Clock {
        private final AtomicReference<Instant> fixed;
        private final ZoneId zone;

        ControllableClock(AtomicReference<Instant> fixed, ZoneId zone) {
            this.fixed = fixed;
            this.zone = zone;
        }
        @Override public ZoneId getZone() { return zone; }
        @Override public Clock withZone(ZoneId zone) { return new ControllableClock(fixed, Objects.requireNonNull(zone)); }
        @Override public Instant instant() {
            Instant value = fixed.get();
            return value == null ? Instant.now() : value;
        }
    }

    private static final String POLICY_PATH = "/api/v1/admin/booking-policy";
    private static final String AVAILABILITY_PATH = "/api/v1/pt/availability";
    private static final Instant POLICY_NOW = Instant.parse("2030-01-02T03:04:05.123456Z");

    @Nested
    @TestInstance(TestInstance.Lifecycle.PER_CLASS)
    class BookingCreateCases {
        private static final String PATH = "/api/v1/bookings";
        private UUID policyId;
        private Instant now;
        private Map<String, Object> originalMembership;

        @BeforeEach void bookingSetup() {
            now = fixture.future.toInstant();
            testClock.fixed.set(now);
            originalMembership = jdbc.queryForMap("SELECT * FROM memberships WHERE id=?", fixture.membershipA);
            policyId = UUID.randomUUID();
            jdbc.update("INSERT INTO booking_policy(id,max_advance_days,min_notice_hours,cancel_deadline_hours,max_future_bookings,effective_from,active,updated_by) VALUES(?,14,2,4,5,?,true,?)",
                    policyId, now.atOffset(ZoneOffset.UTC), fixture.admin.userId);
        }

        @AfterEach void bookingRestore() {
            jdbc.update("DELETE FROM booking_policy WHERE id=?", policyId);
            jdbc.update("UPDATE memberships SET status=?,start_date=?,expiry_date=? WHERE id=?",
                    originalMembership.get("status"), originalMembership.get("start_date"), originalMembership.get("expiry_date"), fixture.membershipA);
            for (var actor : List.of(fixture.memberA, fixture.memberB, fixture.ptA, fixture.ptB)) {
                jdbc.update("UPDATE users SET status='ACTIVE' WHERE id=?", actor.userId);
            }
        }

        private OffsetDateTime start() { return fixture.future.plusDays(2).plusHours(9); }

        private UUID slot(HttpBaselineFixture.Actor pt, OffsetDateTime start, String status) {
            UUID id = UUID.randomUUID();
            jdbc.update("INSERT INTO availability_slots(id,pt_id,start_at,end_at,status) VALUES(?,?,?,?,?)",
                    id, pt.profileId, start, start.plusMinutes(90), status);
            writeSlots.add(id);
            return id;
        }

        private UUID booking(HttpBaselineFixture.Actor member, UUID slot, String status) {
            UUID id = UUID.randomUUID();
            jdbc.update("""
                    INSERT INTO bookings(id,member_id,pt_id,slot_id,start_at,end_at,status,cancelled_by,cancelled_at,completed_at)
                    SELECT ?,?,pt_id,id,start_at,end_at,?,case when ?='CANCELLED' then 'MEMBER' end,
                      case when ?='CANCELLED' then now() end,case when ?='COMPLETED' then end_at end
                    FROM availability_slots WHERE id=?
                    """, id, member.profileId, status, status, status, status, slot);
            writeBookings.add(id);
            return id;
        }

        private Map<String, Object> input(HttpBaselineFixture.Actor pt, UUID slot) {
            return Map.of("ptId", pt.profileId.toString(), "slotId", slot.toString());
        }

        private Map<String, Object> book(HttpBaselineFixture.Actor member, HttpBaselineFixture.Actor pt, UUID slot,
                                         int expected, String code) throws Exception {
            var response = writeExchange("POST", PATH, token(member), input(pt, slot));
            remember(response);
            assertEquals(expected, response.statusCode());
            var body = object(json.readValue(response.body(), Object.class));
            if (expected == 201) assertBookingCreated(body, member, pt, slot);
            else {
                assertEquals(false, body.get("success"));
                assertEquals(expected, body.get("status"));
                assertEquals(code, object(body.get("error")).get("code"));
            }
            return body;
        }

        private void remember(HttpResponse<String> response) {
            if (response.statusCode() == 201) {
                var body = object(json.readValue(response.body(), Object.class));
                UUID id = UUID.fromString((String) body.get("id"));
                if (body.containsKey("memberId")) writeBookings.add(id); else writeSlots.add(id);
            }
        }

        private void assertBookingCreated(Map<String, Object> body, HttpBaselineFixture.Actor member,
                                          HttpBaselineFixture.Actor pt, UUID slot) {
            assertEquals(Set.of("id", "memberId", "ptId", "slotId", "startAt", "endAt", "status",
                    "cancelledBy", "cancelReason", "cancelledAt", "completedAt"), body.keySet());
            assertEquals(member.profileId.toString(), body.get("memberId"));
            assertEquals(pt.profileId.toString(), body.get("ptId"));
            assertEquals(slot.toString(), body.get("slotId"));
            assertEquals("CONFIRMED", body.get("status"));
            for (String field : List.of("cancelledBy", "cancelReason", "cancelledAt", "completedAt")) assertNull(body.get(field));
            var stored = jdbc.queryForMap("SELECT * FROM bookings WHERE id=?", UUID.fromString((String) body.get("id")));
            assertEquals(member.profileId, stored.get("member_id"));
            assertEquals(pt.profileId, stored.get("pt_id"));
            assertEquals(slot, stored.get("slot_id"));
            assertEquals("CONFIRMED", stored.get("status"));
            var times = jdbc.queryForObject("SELECT start_at,end_at FROM availability_slots WHERE id=?",
                    (rs, row) -> List.of(rs.getObject(1, OffsetDateTime.class), rs.getObject(2, OffsetDateTime.class)), slot);
            assertEquals(times.get(0).toInstant().toString(), body.get("startAt"));
            assertEquals(times.get(1).toInstant().toString(), body.get("endAt"));
            assertEquals("BOOKED", jdbc.queryForObject("SELECT status FROM availability_slots WHERE id=?", String.class, slot));
        }

        @Test void happyPathAutoConfirmsCorrectOwnerAndRemovesAvailability() throws Exception {
            UUID slot = slot(fixture.ptA, start(), "AVAILABLE");
            var payload = new HashMap<>(input(fixture.ptA, slot));
            payload.put("memberId", fixture.memberB.profileId.toString());
            payload.put("status", "PENDING");
            var response = writeExchange("POST", PATH, token(fixture.memberA), payload);
            remember(response);
            assertEquals(201, response.statusCode());
            var body = object(json.readValue(response.body(), Object.class));
            assertBookingCreated(body, fixture.memberA, fixture.ptA, slot);
            String range = range(start(), start().plusHours(2));
            assertTrue(array(request("GET", "/api/v1/trainers/" + fixture.ptA.profileId + "/slots" + range,
                    token(fixture.memberB), null, 200)).isEmpty());
            assertEquals(List.of(body), array(request("GET", PATH + "/me" + range, token(fixture.memberA), null, 200)));
            assertTrue(array(request("GET", PATH + "/me" + range, token(fixture.memberB), null, 200)).isEmpty());
            assertEquals(List.of(body), array(request("GET", "/api/v1/pt/bookings" + range, token(fixture.ptA), null, 200)));
            book(fixture.memberB, fixture.ptA, slot, 409, "ERR_SLOT_NO_LONGER_AVAILABLE");
        }

        @ParameterizedTest @ValueSource(strings = {"admin", "ptA", "ptB"})
        void bookingIsMemberOnly(String actor) throws Exception {
            error("POST", PATH, token(actor(actor)), input(fixture.ptA, fixture.available.id()), 403, "ERR_FORBIDDEN");
        }

        @Test void bookingWithoutTokenIs401() throws Exception {
            error("POST", PATH, null, input(fixture.ptA, fixture.available.id()), 401, "ERR_UNAUTHORIZED");
        }

        @ParameterizedTest @ValueSource(strings = {"missingPt", "missingSlot", "badPt", "badSlot", "nullPt"})
        void inputMustContainBothUuids(String state) throws Exception {
            var body = new HashMap<String, Object>(input(fixture.ptA, fixture.available.id()));
            switch (state) {
                case "missingPt" -> body.remove("ptId");
                case "missingSlot" -> body.remove("slotId");
                case "badPt" -> body.put("ptId", "PT-001");
                case "badSlot" -> body.put("slotId", "SLOT-001");
                default -> body.put("ptId", null);
            }
            error("POST", PATH, token(fixture.memberA), body, 400, "ERR_VALIDATION");
        }

        @ParameterizedTest @ValueSource(strings = {"SUSPENDED", "DISABLED"})
        void previouslyIssuedTokenCannotBookForInactiveMember(String state) throws Exception {
            String access = token(fixture.memberA);
            jdbc.update("UPDATE users SET status=? WHERE id=?", state, fixture.memberA.userId);
            error("POST", PATH, access, input(fixture.ptA, fixture.available.id()), 401, "ERR_UNAUTHORIZED");
        }

        @Test void activeMemberWithoutProfileIs404() throws Exception {
            var member = new HttpBaselineFixture.Actor("MEMBER", "r03-no-m");
            jdbc.update("INSERT INTO users(id,email,password_hash,role,status) VALUES(?,?,?,'MEMBER','ACTIVE')",
                    member.userId, member.email, encoder.encode(member.password));
            try { book(member, fixture.ptA, fixture.available.id(), 404, "ERR_NOT_FOUND"); }
            finally { accessTokens.remove(member.email); assertEquals(1, jdbc.update("DELETE FROM users WHERE id=?", member.userId)); }
        }

        @ParameterizedTest @ValueSource(strings = {"SUSPENDED", "DISABLED"})
        void inactivePtCannotReceiveBooking(String state) throws Exception {
            UUID slot = slot(fixture.ptA, start(), "AVAILABLE");
            jdbc.update("UPDATE users SET status=? WHERE id=?", state, fixture.ptA.userId);
            book(fixture.memberA, fixture.ptA, slot, 404, "ERR_NOT_FOUND");
        }

        @Test void missingPtSlotOrMismatchedPairIs404() throws Exception {
            book(fixture.memberA, fixture.ptA, UUID.randomUUID(), 404, "ERR_NOT_FOUND");
            book(fixture.memberA, fixture.ptB, fixture.available.id(), 404, "ERR_NOT_FOUND");
            error("POST", PATH, token(fixture.memberA), Map.of("ptId", UUID.randomUUID().toString(), "slotId", fixture.available.id().toString()), 404, "ERR_NOT_FOUND");
        }

        @ParameterizedTest @ValueSource(strings = {"BOOKED", "DISABLED"})
        void unavailableSlotHasStableCode(String status) throws Exception {
            UUID slot = slot(fixture.ptA, start(), status);
            book(fixture.memberA, fixture.ptA, slot, 409, "ERR_SLOT_NO_LONGER_AVAILABLE");
            assertEquals(status, jdbc.queryForObject("SELECT status FROM availability_slots WHERE id=?", String.class, slot));
        }

        @Test void legacy60MinuteSlotCannotBeBooked() throws Exception {
            book(fixture.memberA, fixture.ptA, fixture.available.id(), 409, "ERR_SLOT_INVALID_DURATION");
        }

        @ParameterizedTest @ValueSource(strings = {"PENDING_ACTIVATION", "SUSPENDED", "EXPIRED", "CANCELLED", "missing", "future", "past", "notCovered"})
        void membershipMustBeActiveNowAndCoverSession(String state) throws Exception {
            UUID slot = slot(fixture.ptA, start(), "AVAILABLE");
            String code = "ERR_MEMBERSHIP_INACTIVE";
            switch (state) {
                case "missing" -> jdbc.update("UPDATE memberships SET status='CANCELLED' WHERE id=?", fixture.membershipA);
                case "future" -> jdbc.update("UPDATE memberships SET start_date=? WHERE id=?", fixture.future.toLocalDate().plusDays(1), fixture.membershipA);
                case "past" -> jdbc.update("UPDATE memberships SET expiry_date=? WHERE id=?", fixture.future.toLocalDate().minusDays(1), fixture.membershipA);
                case "notCovered" -> {
                    jdbc.update("UPDATE memberships SET expiry_date=? WHERE id=?", start().toLocalDate().minusDays(1), fixture.membershipA);
                    code = "ERR_MEMBERSHIP_NOT_COVERED";
                }
                default -> jdbc.update("UPDATE memberships SET status=? WHERE id=?", state, fixture.membershipA);
            }
            var before = jdbc.queryForMap("SELECT * FROM availability_slots WHERE id=?", slot);
            book(fixture.memberA, fixture.ptA, slot, 409, code);
            assertEquals(before, jdbc.queryForMap("SELECT * FROM availability_slots WHERE id=?", slot));
        }

        @ParameterizedTest @ValueSource(longs = {-1, 0, 1})
        void expiryIsInclusiveVietnamDateAndEndEqualityIsAllowed(long microseconds) throws Exception {
            var expiry = now.atZone(ZoneId.of("Asia/Ho_Chi_Minh")).toLocalDate();
            jdbc.update("UPDATE memberships SET expiry_date=? WHERE id=?", expiry, fixture.membershipA);
            var end = expiry.plusDays(1).atStartOfDay(ZoneId.of("Asia/Ho_Chi_Minh")).toOffsetDateTime().plusNanos(microseconds * 1000);
            UUID slot = slot(fixture.ptA, end.minusMinutes(90), "AVAILABLE");
            book(fixture.memberA, fixture.ptA, slot, microseconds > 0 ? 409 : 201,
                    microseconds > 0 ? "ERR_MEMBERSHIP_NOT_COVERED" : null);
        }

        @ParameterizedTest @ValueSource(longs = {-1, 0})
        void activationUsesMidnightInVietnam(long microseconds) throws Exception {
            var activationDate = fixture.future.toLocalDate();
            now = activationDate.atStartOfDay(ZoneId.of("Asia/Ho_Chi_Minh")).toInstant().plusNanos(microseconds * 1000);
            testClock.fixed.set(now);
            jdbc.update("UPDATE memberships SET start_date=? WHERE id=?", activationDate, fixture.membershipA);
            jdbc.update("UPDATE booking_policy SET effective_from=? WHERE id=?", now.atOffset(ZoneOffset.UTC), policyId);
            UUID slot = slot(fixture.ptA, fixture.future.plusDays(2), "AVAILABLE");
            book(fixture.memberA, fixture.ptA, slot, microseconds < 0 ? 409 : 201,
                    microseconds < 0 ? "ERR_MEMBERSHIP_INACTIVE" : null);
        }

        @ParameterizedTest @ValueSource(strings = {"absent", "inactive", "future"})
        void missingEffectivePolicyRejectsWithoutFallback(String state) throws Exception {
            if (state.equals("absent")) jdbc.update("DELETE FROM booking_policy WHERE id=?", policyId);
            if (state.equals("inactive")) jdbc.update("UPDATE booking_policy SET active=false WHERE id=?", policyId);
            if (state.equals("future")) jdbc.update("UPDATE booking_policy SET effective_from=? WHERE id=?", now.plusNanos(1000).atOffset(ZoneOffset.UTC), policyId);
            UUID slot = slot(fixture.ptA, start(), "AVAILABLE");
            book(fixture.memberA, fixture.ptA, slot, 404, "BOOKING_POLICY_NOT_FOUND");
            assertEquals("AVAILABLE", jdbc.queryForObject("SELECT status FROM availability_slots WHERE id=?", String.class, slot));
            assertEquals(0, jdbc.queryForObject("SELECT count(*) FROM bookings WHERE slot_id=?", Integer.class, slot));
        }

        @ParameterizedTest @ValueSource(longs = {-1, 0, 1})
        void minimumNoticeBoundaryUsesControlledClock(long microseconds) throws Exception {
            var start = now.plus(Duration.ofHours(2)).plusNanos(microseconds * 1000).atOffset(ZoneOffset.UTC);
            // Fixture has an unrelated CONFIRMED slot at +10h, so these intervals do not overlap it.
            UUID slot = slot(fixture.ptA, start, "AVAILABLE");
            book(fixture.memberA, fixture.ptA, slot, microseconds < 0 ? 409 : 201,
                    microseconds < 0 ? "ERR_BOOKING_NOTICE" : null);
        }

        @ParameterizedTest @ValueSource(longs = {-1, 0, 1})
        void maximumAdvanceIs14Times24HoursFromExactNow(long microseconds) throws Exception {
            var start = now.plus(Duration.ofDays(14)).plusNanos(microseconds * 1000).atOffset(ZoneOffset.UTC);
            UUID slot = slot(fixture.ptA, start, "AVAILABLE");
            book(fixture.memberA, fixture.ptA, slot, microseconds > 0 ? 409 : 201,
                    microseconds > 0 ? "ERR_BOOKING_ADVANCE" : null);
        }

        @Test void customPolicyIsAppliedInsteadOfInitialConstants() throws Exception {
            jdbc.update("UPDATE booking_policy SET max_advance_days=1,min_notice_hours=3,max_future_bookings=1 WHERE id=?", policyId);
            UUID slot = slot(fixture.ptA, start(), "AVAILABLE");
            book(fixture.memberA, fixture.ptA, slot, 409, "ERR_BOOKING_ADVANCE");
            jdbc.update("UPDATE booking_policy SET max_advance_days=14 WHERE id=?", policyId);
            book(fixture.memberA, fixture.ptA, slot, 409, "ERR_MAX_FUTURE_BOOKINGS");
        }

        private void futureCount(int desired) {
            int existing = jdbc.queryForObject("SELECT count(*) FROM bookings WHERE member_id=? AND status='CONFIRMED' AND start_at>?",
                    Integer.class, fixture.memberA.profileId, now.atOffset(ZoneOffset.UTC));
            for (int i = existing; i < desired; i++) {
                UUID slot = slot(fixture.ptB, fixture.future.plusDays(3).plusHours(i * 2L), "BOOKED");
                booking(fixture.memberA, slot, "CONFIRMED");
            }
        }

        @ParameterizedTest @ValueSource(ints = {4, 5})
        void fourAllowsOneMoreButFiveRejects(int existing) throws Exception {
            futureCount(existing);
            UUID slot = slot(fixture.ptA, start(), "AVAILABLE");
            book(fixture.memberA, fixture.ptA, slot, existing == 4 ? 201 : 409,
                    existing == 4 ? null : "ERR_MAX_FUTURE_BOOKINGS");
            assertEquals(5, jdbc.queryForObject("SELECT count(*) FROM bookings WHERE member_id=? AND status='CONFIRMED' AND start_at>?",
                    Integer.class, fixture.memberA.profileId, now.atOffset(ZoneOffset.UTC)));
        }

        @Test void onlyFutureConfirmedBookingsCountTowardLimit() throws Exception {
            futureCount(4);
            booking(fixture.memberA, slot(fixture.ptB, fixture.future.minusDays(1), "DISABLED"), "CONFIRMED");
            booking(fixture.memberA, slot(fixture.ptB, fixture.future.plusDays(5), "DISABLED"), "CANCELLED");
            booking(fixture.memberA, slot(fixture.ptB, fixture.future.plusDays(6), "DISABLED"), "COMPLETED");
            UUID slot = slot(fixture.ptA, start(), "AVAILABLE");
            book(fixture.memberA, fixture.ptA, slot, 201, null);
        }

        @Test void memberOverlapAcrossDifferentPtsIsRejected() throws Exception {
            booking(fixture.memberA, slot(fixture.ptB, start().plusMinutes(30), "BOOKED"), "CONFIRMED");
            UUID slot = slot(fixture.ptA, start(), "AVAILABLE");
            book(fixture.memberA, fixture.ptA, slot, 409, "ERR_BOOKING_OVERLAP");
        }

        @Test void ptOverlapIsCheckedEvenForInconsistentDisabledBookingSlot() throws Exception {
            booking(fixture.memberB, slot(fixture.ptA, start().plusMinutes(30), "DISABLED"), "CONFIRMED");
            UUID slot = slot(fixture.ptA, start(), "AVAILABLE");
            book(fixture.memberA, fixture.ptA, slot, 409, "ERR_BOOKING_OVERLAP");
        }

        @Test void touchingSessionsAreAllowedForMemberAndPt() throws Exception {
            booking(fixture.memberA, slot(fixture.ptA, start().minusMinutes(90), "BOOKED"), "CONFIRMED");
            UUID first = slot(fixture.ptA, start(), "AVAILABLE");
            book(fixture.memberA, fixture.ptA, first, 201, null);
            UUID next = slot(fixture.ptA, start().plusMinutes(90), "AVAILABLE");
            book(fixture.memberA, fixture.ptA, next, 201, null);
        }

        private void awaitWaiters(int count) throws Exception {
            long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
            while (System.nanoTime() < deadline) {
                int waiting = jdbc.queryForObject("SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND usename=current_user AND wait_event_type='Lock' AND pid<>pg_backend_pid()", Integer.class);
                if (waiting >= count) return;
                Thread.sleep(20);
            }
            fail("Expected concurrent HTTP requests blocked on the held database lock");
        }

        private List<HttpResponse<String>> race(String table, UUID lockedId, Callable<HttpResponse<String>> first,
                                                Callable<HttpResponse<String>> second) throws Exception {
            assertTrue(Set.of("members", "personal_trainers").contains(table));
            try (var connection = jdbc.getDataSource().getConnection(); var pool = Executors.newVirtualThreadPerTaskExecutor()) {
                connection.setAutoCommit(false);
                try (var statement = connection.prepareStatement("SELECT id FROM " + table + " WHERE id=? FOR NO KEY UPDATE")) {
                    statement.setObject(1, lockedId);
                    try (var rows = statement.executeQuery()) { assertTrue(rows.next()); }
                }
                var a = pool.submit(first);
                try {
                    awaitWaiters(1);
                    var b = pool.submit(second);
                    awaitWaiters(2); // Both requests are pending before releasing; no sequential-request pseudo-race.
                    connection.commit();
                    var responses = List.of(a.get(15, TimeUnit.SECONDS), b.get(15, TimeUnit.SECONDS));
                    responses.forEach(this::remember);
                    return responses;
                } finally { connection.rollback(); }
            }
        }

        @Test void twoMembersCompeteForOneSlotWithExactlyOneWinner() throws Exception {
            UUID slot = slot(fixture.ptA, start(), "AVAILABLE");
            String a = token(fixture.memberA), b = token(fixture.memberB);
            var responses = race("personal_trainers", fixture.ptA.profileId,
                    () -> writeExchange("POST", PATH, a, input(fixture.ptA, slot)),
                    () -> writeExchange("POST", PATH, b, input(fixture.ptA, slot)));
            assertEquals(201, responses.getFirst().statusCode());
            assertBookingCreated(object(json.readValue(responses.getFirst().body(), Object.class)), fixture.memberA, fixture.ptA, slot);
            assertEquals(409, responses.getLast().statusCode());
            assertEquals("ERR_SLOT_NO_LONGER_AVAILABLE", object(object(json.readValue(responses.getLast().body(), Object.class)).get("error")).get("code"));
            assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM bookings WHERE slot_id=?", Integer.class, slot));
        }

        @ParameterizedTest @ValueSource(strings = {"limit", "overlap"})
        void sameMemberConcurrentDifferentSlotsAreSerialized(String kind) throws Exception {
            if (kind.equals("limit")) futureCount(4);
            UUID a = slot(fixture.ptA, start(), "AVAILABLE");
            UUID b = slot(fixture.ptB, kind.equals("limit") ? start().plusHours(3) : start().plusMinutes(30), "AVAILABLE");
            String access = token(fixture.memberA);
            var responses = race("members", fixture.memberA.profileId,
                    () -> writeExchange("POST", PATH, access, input(fixture.ptA, a)),
                    () -> writeExchange("POST", PATH, access, input(fixture.ptB, b)));
            assertEquals(201, responses.getFirst().statusCode());
            assertEquals(409, responses.getLast().statusCode());
            String expected = kind.equals("limit") ? "ERR_MAX_FUTURE_BOOKINGS" : "ERR_BOOKING_OVERLAP";
            assertEquals(expected, object(object(json.readValue(responses.getLast().body(), Object.class)).get("error")).get("code"));
            assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM bookings WHERE slot_id IN (?,?)", Integer.class, a, b));
            assertEquals("AVAILABLE", jdbc.queryForObject("SELECT status FROM availability_slots WHERE id=?", String.class, b));
        }

        @ParameterizedTest @ValueSource(strings = {"PATCH-booking", "PATCH-slot", "DELETE-booking", "DELETE-slot"})
        void bookingAndAvailabilityRacePreservesStatusAndTime(String scenario) throws Exception {
            String method = scenario.split("-")[0];
            boolean bookingFirst = scenario.endsWith("booking");
            UUID slot = slot(fixture.ptA, start(), "AVAILABLE");
            String member = token(fixture.memberA), pt = token(fixture.ptA);
            Callable<HttpResponse<String>> book = () -> writeExchange("POST", PATH, member, input(fixture.ptA, slot));
            Callable<HttpResponse<String>> change = () -> writeExchange(method, AVAILABILITY_PATH + "/" + slot, pt,
                    method.equals("DELETE") ? null : times(start().plusHours(3)));
            var responses = race("personal_trainers", fixture.ptA.profileId, bookingFirst ? book : change, bookingFirst ? change : book);
            if (bookingFirst) {
                assertEquals(201, responses.getFirst().statusCode());
                assertBookingCreated(object(json.readValue(responses.getFirst().body(), Object.class)), fixture.memberA, fixture.ptA, slot);
                assertWriteConflict(responses.getLast());
            } else {
                assertEquals(method.equals("DELETE") ? 204 : 200, responses.getFirst().statusCode());
                assertEquals(409, responses.getLast().statusCode());
                assertEquals("ERR_SLOT_NO_LONGER_AVAILABLE", object(object(json.readValue(responses.getLast().body(), Object.class)).get("error")).get("code"));
                assertEquals(0, jdbc.queryForObject("SELECT count(*) FROM bookings WHERE slot_id=?", Integer.class, slot));
                assertEquals(method.equals("DELETE") ? "DISABLED" : "AVAILABLE", jdbc.queryForObject("SELECT status FROM availability_slots WHERE id=?", String.class, slot));
                if (method.equals("PATCH")) {
                    var stored = jdbc.queryForObject("SELECT start_at FROM availability_slots WHERE id=?", (rs, row) -> rs.getObject(1, OffsetDateTime.class), slot);
                    assertEquals(start().plusHours(3).toInstant(), stored.toInstant());
                }
            }
        }

        @Test void databaseConstraintConflictRollsBackPreviouslyFlushedBookedStatus() throws Exception {
            UUID target = slot(fixture.ptA, start(), "AVAILABLE");
            UUID competitor = slot(fixture.ptB, start().plusMinutes(30), "BOOKED");
            String access = token(fixture.memberA);
            try (var connection = jdbc.getDataSource().getConnection(); var pool = Executors.newVirtualThreadPerTaskExecutor()) {
                connection.setAutoCommit(false);
                UUID external = UUID.randomUUID();
                try (var statement = connection.prepareStatement("INSERT INTO bookings(id,member_id,pt_id,slot_id,start_at,end_at,status) SELECT ?,?,pt_id,id,start_at,end_at,'CONFIRMED' FROM availability_slots WHERE id=?")) {
                    statement.setObject(1, external); statement.setObject(2, fixture.memberA.profileId); statement.setObject(3, competitor);
                    assertEquals(1, statement.executeUpdate());
                }
                var response = pool.submit(() -> writeExchange("POST", PATH, access, input(fixture.ptA, target)));
                try {
                    awaitWaiters(1); // INSERT is blocked on an uncommitted exclusion competitor invisible to the read query.
                    connection.commit();
                    writeBookings.add(external);
                    assertWriteConflict(response.get(15, TimeUnit.SECONDS));
                    assertEquals("AVAILABLE", jdbc.queryForObject("SELECT status FROM availability_slots WHERE id=?", String.class, target));
                    assertEquals(0, jdbc.queryForObject("SELECT count(*) FROM bookings WHERE slot_id=?", Integer.class, target));
                } finally { connection.rollback(); }
            }
        }
    }

    private OffsetDateTime writeStart() { return fixture.future.plusDays(10).plusHours(9); }
    private static Map<String, Object> times(OffsetDateTime start) {
        return Map.of("startAt", start.toString(), "endAt", start.plusMinutes(90).toString());
    }

    private Map<String, Object> createSlot(HttpBaselineFixture.Actor actor, OffsetDateTime start) throws Exception {
        var result = object(request("POST", AVAILABILITY_PATH, token(actor), times(start), 201));
        writeSlots.add(UUID.fromString((String) result.get("id")));
        assertSlotPayload(result, actor, start, "AVAILABLE");
        return result;
    }

    private void assertSlotPayload(Map<String, Object> body, HttpBaselineFixture.Actor actor,
                                   OffsetDateTime start, String status) {
        assertEquals(Set.of("id", "ptId", "startAt", "endAt", "status"), body.keySet());
        assertEquals(actor.profileId.toString(), body.get("ptId"));
        assertEquals(start.toInstant().toString(), body.get("startAt"));
        assertEquals(start.plusMinutes(90).toInstant().toString(), body.get("endAt"));
        assertEquals(status, body.get("status"));
        var stored = jdbc.queryForMap("SELECT pt_id,start_at,end_at,status FROM availability_slots WHERE id=?",
                UUID.fromString((String) body.get("id")));
        assertEquals(actor.profileId, stored.get("pt_id"));
        assertEquals(status, stored.get("status"));
        var storedStart = jdbc.queryForObject("SELECT start_at FROM availability_slots WHERE id=?",
                (rs, row) -> rs.getObject(1, OffsetDateTime.class), UUID.fromString((String) body.get("id")));
        assertEquals(start.toInstant(), storedStart.toInstant());
        var storedEnd = jdbc.queryForObject("SELECT end_at FROM availability_slots WHERE id=?",
                (rs, row) -> rs.getObject(1, OffsetDateTime.class), UUID.fromString((String) body.get("id")));
        assertEquals(start.plusMinutes(90).toInstant(), storedEnd.toInstant());
    }

    private UUID rawSlot(String status) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO availability_slots(id,pt_id,start_at,end_at,status) VALUES(?,?,?,?,?)",
                id, fixture.ptA.profileId, writeStart(), writeStart().plusMinutes(90), status);
        writeSlots.add(id);
        return id;
    }

    private UUID rawBooking(UUID slotId, String status) {
        UUID id = UUID.randomUUID();
        jdbc.update("""
                INSERT INTO bookings(id,member_id,pt_id,slot_id,start_at,end_at,status,cancelled_by,cancelled_at,completed_at)
                SELECT ?,?,pt_id,id,start_at,end_at,?,case when ?='CANCELLED' then 'MEMBER' end,
                  case when ?='CANCELLED' then now() end,case when ?='COMPLETED' then end_at end
                FROM availability_slots WHERE id=?
                """, id, fixture.memberA.profileId, status, status, status, status, slotId);
        writeBookings.add(id);
        return id;
    }

    @Test void ptCreates90MinuteSlotUsingAuthenticatedProfileAndExistingReads() throws Exception {
        var payload = new HashMap<>(times(writeStart().withOffsetSameInstant(ZoneOffset.ofHours(7))));
        payload.put("ptId", fixture.ptB.profileId.toString());
        payload.put("status", "BOOKED");
        var body = object(request("POST", AVAILABILITY_PATH, token(fixture.ptA), payload, 201));
        writeSlots.add(UUID.fromString((String) body.get("id")));
        assertSlotPayload(body, fixture.ptA, writeStart(), "AVAILABLE");
        var range = range(writeStart(), writeStart().plusHours(2));
        assertEquals(List.of(body), array(request("GET", "/api/v1/pt/slots" + range, token(fixture.ptA), null, 200)));
        assertTrue(array(request("GET", "/api/v1/pt/slots" + range, token(fixture.ptB), null, 200)).isEmpty());
        assertEquals(List.of(body), array(request("GET", "/api/v1/trainers/" + fixture.ptA.profileId + "/slots" + range,
                token(fixture.memberA), null, 200)));
    }

    @Test void ptEditsUnbookedSlotAndKeepsId() throws Exception {
        var before = createSlot(fixture.ptA, writeStart());
        var after = object(request("PATCH", AVAILABILITY_PATH + "/" + before.get("id"), token(fixture.ptA),
                times(writeStart().plusHours(3)), 200));
        assertEquals(before.get("id"), after.get("id"));
        assertSlotPayload(after, fixture.ptA, writeStart().plusHours(3), "AVAILABLE");
        assertEquals(1L, jdbc.queryForObject("SELECT version FROM availability_slots WHERE id=?", Long.class,
                UUID.fromString((String) before.get("id"))));
        // A PATCH can omit an unchanged field, including an equivalent offset representation.
        var same = object(request("PATCH", AVAILABILITY_PATH + "/" + before.get("id"), token(fixture.ptA),
                Map.of("startAt", writeStart().plusHours(3).withOffsetSameInstant(ZoneOffset.ofHours(7)).toString()), 200));
        assertEquals(after, same);
    }

    @ParameterizedTest @ValueSource(strings = {"CANCELLED", "COMPLETED"})
    void deleteDisablesSlotAndPreservesEveryHistoricalBooking(String historyStatus) throws Exception {
        UUID slot = rawSlot("AVAILABLE"), booking = rawBooking(slot, historyStatus);
        var history = jdbc.queryForMap("SELECT * FROM bookings WHERE id=?", booking);
        request("DELETE", AVAILABILITY_PATH + "/" + slot, token(fixture.ptA), null, 204);
        request("DELETE", AVAILABILITY_PATH + "/" + slot, token(fixture.ptA), null, 204);
        assertEquals(history, jdbc.queryForMap("SELECT * FROM bookings WHERE id=?", booking));
        assertEquals("DISABLED", jdbc.queryForObject("SELECT status FROM availability_slots WHERE id=?", String.class, slot));
        var range = range(writeStart(), writeStart().plusHours(2));
        assertTrue(array(request("GET", "/api/v1/trainers/" + fixture.ptA.profileId + "/slots" + range,
                token(fixture.memberA), null, 200)).isEmpty());
        var ptRows = array(request("GET", "/api/v1/pt/slots" + range, token(fixture.ptA), null, 200));
        assertEquals(1, ptRows.size());
        assertEquals("DISABLED", ptRows.getFirst().get("status"));
        var bookings = array(request("GET", "/api/v1/bookings/me" + range, token(fixture.memberA), null, 200));
        assertEquals(booking.toString(), bookings.getFirst().get("id"));
        assertEquals(historyStatus, bookings.getFirst().get("status"));
    }

    @Test void patchWithHistoryReplacesSlotWithoutChangingBookingOrItsFk() throws Exception {
        UUID old = rawSlot("AVAILABLE"), booking = rawBooking(old, "CANCELLED");
        var before = jdbc.queryForMap("SELECT * FROM bookings WHERE id=?", booking);
        var body = object(request("PATCH", AVAILABILITY_PATH + "/" + old, token(fixture.ptA),
                times(writeStart().plusMinutes(30)), 200));
        UUID replacement = UUID.fromString((String) body.get("id"));
        writeSlots.add(replacement);
        assertNotEquals(old, replacement);
        assertSlotPayload(body, fixture.ptA, writeStart().plusMinutes(30), "AVAILABLE");
        assertEquals("DISABLED", jdbc.queryForObject("SELECT status FROM availability_slots WHERE id=?", String.class, old));
        assertEquals(before, jdbc.queryForMap("SELECT * FROM bookings WHERE id=?", booking));
        error("PATCH", AVAILABILITY_PATH + "/" + old, token(fixture.ptA), times(writeStart().plusHours(4)), 409, "ERR_CONFLICT");
    }

    @Test void failedHistoricalPatchDoesNotDisableOldSlot() throws Exception {
        UUID old = rawSlot("AVAILABLE"), booking = rawBooking(old, "CANCELLED");
        createSlot(fixture.ptA, writeStart().plusHours(3));
        var before = jdbc.queryForMap("SELECT * FROM availability_slots WHERE id=?", old);
        error("PATCH", AVAILABILITY_PATH + "/" + old, token(fixture.ptA), times(writeStart().plusHours(3)), 409, "ERR_CONFLICT");
        assertEquals(before, jdbc.queryForMap("SELECT * FROM availability_slots WHERE id=?", old));
        assertEquals(old, jdbc.queryForObject("SELECT slot_id FROM bookings WHERE id=?", UUID.class, booking));
    }

    @ParameterizedTest @ValueSource(strings = {"PATCH", "DELETE"})
    void bookedSlotCannotBeEditedOrDisabledEvenWithoutBookingRow(String method) throws Exception {
        UUID slot = rawSlot("BOOKED");
        var before = jdbc.queryForMap("SELECT * FROM availability_slots WHERE id=?", slot);
        error(method, AVAILABILITY_PATH + "/" + slot, token(fixture.ptA),
                method.equals("PATCH") ? times(writeStart().plusHours(3)) : null, 409, "ERR_CONFLICT");
        assertEquals(before, jdbc.queryForMap("SELECT * FROM availability_slots WHERE id=?", slot));
    }

    @ParameterizedTest @ValueSource(strings = {"PATCH", "DELETE"})
    void confirmedBookingBlocksChangesEvenWhenSlotStatusIsAvailable(String method) throws Exception {
        UUID slot = rawSlot("AVAILABLE"), booking = rawBooking(slot, "CONFIRMED");
        var before = jdbc.queryForMap("SELECT * FROM bookings WHERE id=?", booking);
        error(method, AVAILABILITY_PATH + "/" + slot, token(fixture.ptA),
                method.equals("PATCH") ? times(writeStart().plusHours(3)) : null, 409, "ERR_CONFLICT");
        assertEquals(before, jdbc.queryForMap("SELECT * FROM bookings WHERE id=?", booking));
        assertEquals("AVAILABLE", jdbc.queryForObject("SELECT status FROM availability_slots WHERE id=?", String.class, slot));
    }

    @Test void confirmedSessionPreventsOverlapEvenIfOriginalSlotIsDisabled() throws Exception {
        UUID slot = rawSlot("DISABLED");
        rawBooking(slot, "CONFIRMED"); // V4 permits this inconsistent state; service must still check bookings.
        error("POST", AVAILABILITY_PATH, token(fixture.ptA), times(writeStart()), 409, "ERR_CONFLICT");
    }

    @Test void overlappingAvailableOrBookedSlotsAreRejectedButOtherPtMayUseSameTime() throws Exception {
        UUID slot = rawSlot("AVAILABLE");
        error("POST", AVAILABILITY_PATH, token(fixture.ptA), times(writeStart().plusMinutes(30)), 409, "ERR_CONFLICT");
        jdbc.update("UPDATE availability_slots SET status='BOOKED' WHERE id=?", slot);
        error("POST", AVAILABILITY_PATH, token(fixture.ptA), times(writeStart()), 409, "ERR_CONFLICT");
        createSlot(fixture.ptB, writeStart());
    }

    @Test void touchingIntervalsAtEitherEndAreAllowed() throws Exception {
        createSlot(fixture.ptA, writeStart());
        createSlot(fixture.ptA, writeStart().minusMinutes(90));
        createSlot(fixture.ptA, writeStart().plusMinutes(90));
    }

    @Test void newSlotOneMicrosecondAfterNowIsInFutureAndDoesNotUseBookingPolicyLimits() throws Exception {
        testClock.fixed.set(writeStart().toInstant());
        createSlot(fixture.ptA, writeStart().plusNanos(1000));
        // Publication is not Member booking; R02 imposes neither min notice nor max advance.
    }

    @Test void disabledSlotDoesNotBlockNewPublicationAndCannotBeReopenedByPatch() throws Exception {
        UUID disabled = rawSlot("DISABLED");
        error("PATCH", AVAILABILITY_PATH + "/" + disabled, token(fixture.ptA), times(writeStart()), 409, "ERR_CONFLICT");
        createSlot(fixture.ptA, writeStart());
    }

    @ParameterizedTest @ValueSource(strings = {"past", "now", "reverse", "zero", "short", "long", "precision", "missingStart", "missingEnd", "offset", "format"})
    void rejectsInvalidCreateTimes(String state) throws Exception {
        testClock.fixed.set(fixture.future.toInstant());
        Map<String, Object> body = new HashMap<>(times(writeStart()));
        switch (state) {
            case "past" -> body = times(fixture.future.minusMinutes(1));
            case "now" -> body = times(fixture.future);
            case "reverse" -> body.put("endAt", writeStart().minusMinutes(1).toString());
            case "zero" -> body.put("endAt", writeStart().toString());
            case "short" -> body.put("endAt", writeStart().plusMinutes(60).toString());
            case "long" -> body.put("endAt", writeStart().plusMinutes(120).toString());
            case "precision" -> body = times(writeStart().plusNanos(1));
            case "missingStart" -> body.remove("startAt");
            case "missingEnd" -> body.remove("endAt");
            case "offset" -> body.put("startAt", "2030-01-02T10:00:00");
            case "format" -> body.put("startAt", "invalid");
        }
        error("POST", AVAILABILITY_PATH, token(fixture.ptA), body, 400, "ERR_VALIDATION");
    }

    @ParameterizedTest @ValueSource(strings = {"empty", "short", "past", "malformed"})
    void rejectsInvalidPatchWithoutChangingStoredSlot(String state) throws Exception {
        UUID slot = rawSlot("AVAILABLE");
        var before = jdbc.queryForMap("SELECT * FROM availability_slots WHERE id=?", slot);
        Map<String, Object> body = switch (state) {
            case "empty" -> Map.of();
            case "short" -> Map.of("endAt", writeStart().plusMinutes(60).toString());
            case "past" -> times(fixture.past);
            default -> Map.of("startAt", "invalid");
        };
        error("PATCH", AVAILABILITY_PATH + "/" + slot, token(fixture.ptA), body, 400, "ERR_VALIDATION");
        assertEquals(before, jdbc.queryForMap("SELECT * FROM availability_slots WHERE id=?", slot));
    }

    @Test void patchCannotRepublishPastSlot() throws Exception {
        UUID slot = rawSlot("AVAILABLE");
        jdbc.update("UPDATE availability_slots SET start_at=?,end_at=? WHERE id=?", fixture.past, fixture.past.plusMinutes(90), slot);
        error("PATCH", AVAILABILITY_PATH + "/" + slot, token(fixture.ptA), times(writeStart()), 409, "ERR_CONFLICT");
    }

    static Stream<Arguments> writeRoleCases() {
        return Stream.of("POST", "PATCH", "DELETE").flatMap(method ->
                Stream.of("admin", "memberA", "memberB").map(actor -> Arguments.of(method, actor)));
    }

    @ParameterizedTest @MethodSource("writeRoleCases")
    void availabilityWritesRequirePtRole(String method, String name) throws Exception {
        String path = AVAILABILITY_PATH + (method.equals("POST") ? "" : "/" + fixture.available.id());
        error(method, path, token(actor(name)), method.equals("DELETE") ? null : times(writeStart()), 403, "ERR_FORBIDDEN");
    }

    @ParameterizedTest @ValueSource(strings = {"POST", "PATCH", "DELETE"})
    void anonymousAvailabilityWritesAreUnauthorized(String method) throws Exception {
        String path = AVAILABILITY_PATH + (method.equals("POST") ? "" : "/" + fixture.available.id());
        error(method, path, null, method.equals("DELETE") ? null : times(writeStart()), 401, "ERR_UNAUTHORIZED");
    }

    @ParameterizedTest @ValueSource(strings = {"PATCH", "DELETE"})
    void ptCannotChangeAnotherTrainersSlot(String method) throws Exception {
        var before = jdbc.queryForMap("SELECT * FROM availability_slots WHERE id=?", fixture.available.id());
        error(method, AVAILABILITY_PATH + "/" + fixture.available.id(), token(fixture.ptB),
                method.equals("DELETE") ? null : times(writeStart()), 404, "ERR_NOT_FOUND");
        assertEquals(before, jdbc.queryForMap("SELECT * FROM availability_slots WHERE id=?", fixture.available.id()));
    }

    @ParameterizedTest @ValueSource(strings = {"PATCH", "DELETE"})
    void missingSlotReturns404(String method) throws Exception {
        error(method, AVAILABILITY_PATH + "/" + UUID.randomUUID(), token(fixture.ptA),
                method.equals("DELETE") ? null : times(writeStart()), 404, "ERR_NOT_FOUND");
    }

    @ParameterizedTest @ValueSource(strings = {"POST", "PATCH", "DELETE"})
    void suspendedOrDisabledPtCannotWriteEvenWithPreviouslyIssuedToken(String method) throws Exception {
        String access = token(fixture.ptA);
        String path = AVAILABILITY_PATH + (method.equals("POST") ? "" : "/" + fixture.available.id());
        for (String state : List.of("SUSPENDED", "DISABLED")) {
            jdbc.update("UPDATE users SET status=? WHERE id=?", state, fixture.ptA.userId);
            try { error(method, path, access, method.equals("DELETE") ? null : times(writeStart()), 401, "ERR_UNAUTHORIZED"); }
            finally { jdbc.update("UPDATE users SET status='ACTIVE' WHERE id=?", fixture.ptA.userId); }
        }
    }

    @ParameterizedTest @ValueSource(strings = {"POST", "PATCH", "DELETE"})
    void activePtWithoutProfileCannotWrite(String method) throws Exception {
        var actor = new HttpBaselineFixture.Actor("PT", "r02-no-pt");
        jdbc.update("INSERT INTO users(id,email,password_hash,role,status) VALUES(?,?,?,'PT','ACTIVE')",
                actor.userId, actor.email, encoder.encode(actor.password));
        try {
            String path = AVAILABILITY_PATH + (method.equals("POST") ? "" : "/" + fixture.available.id());
            error(method, path, token(actor), method.equals("DELETE") ? null : times(writeStart()), 404, "ERR_NOT_FOUND");
        } finally {
            accessTokens.remove(actor.email);
            assertEquals(1, jdbc.update("DELETE FROM users WHERE id=?", actor.userId));
        }
    }

    @ParameterizedTest @ValueSource(ints = {2, 8, 20})
    void concurrentOverlappingCreatesHaveExactlyOneWinnerAndControlledConflicts(int count) throws Exception {
        String access = token(fixture.ptA);
        var gate = new CountDownLatch(1);
        try (var pool = Executors.newVirtualThreadPerTaskExecutor()) {
            var futures = IntStream.range(0, count).mapToObj(index -> pool.submit(() -> {
                assertTrue(gate.await(5, TimeUnit.SECONDS));
                return writeExchange("POST", AVAILABILITY_PATH, access, times(writeStart().plusMinutes(index)));
            })).toList();
            gate.countDown();
            int winners = 0;
            for (var future : futures) {
                var response = future.get(15, TimeUnit.SECONDS);
                if (response.statusCode() == 201) { rememberCreated(response); winners++; }
                else assertWriteConflict(response);
            }
            assertEquals(1, winners);
        }
        assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM availability_slots WHERE pt_id=? AND start_at>=? AND start_at<?",
                Integer.class, fixture.ptA.profileId, writeStart(), writeStart().plusHours(1)));
    }

    @Test void concurrentPatchAndCreateCannotPublishOverlappingSlots() throws Exception {
        var old = createSlot(fixture.ptA, writeStart());
        String access = token(fixture.ptA);
        var gate = new CountDownLatch(1);
        try (var pool = Executors.newVirtualThreadPerTaskExecutor()) {
            var patch = pool.submit(() -> { gate.await(); return writeExchange("PATCH", AVAILABILITY_PATH + "/" + old.get("id"), access, times(writeStart().plusHours(4))); });
            var create = pool.submit(() -> { gate.await(); return writeExchange("POST", AVAILABILITY_PATH, access, times(writeStart().plusHours(4))); });
            gate.countDown();
            var patched = patch.get(15, TimeUnit.SECONDS);
            var created = create.get(15, TimeUnit.SECONDS);
            if (created.statusCode() == 201) { rememberCreated(created); assertWriteConflict(patched); }
            else { assertEquals(200, patched.statusCode()); assertWriteConflict(created); }
        }
    }

    @ParameterizedTest @ValueSource(strings = {"PATCH", "DELETE"})
    void slotLockMakesAvailabilityWaitForConcurrentConfirmationThenReject(String method) throws Exception {
        UUID slot = rawSlot("AVAILABLE");
        String access = token(fixture.ptA);
        try (var connection = jdbc.getDataSource().getConnection(); var pool = Executors.newVirtualThreadPerTaskExecutor()) {
            connection.setAutoCommit(false);
            try (var statement = connection.prepareStatement("SELECT id FROM availability_slots WHERE id=? FOR UPDATE")) {
                statement.setObject(1, slot);
                try (var result = statement.executeQuery()) { assertTrue(result.next()); }
            }
            var response = pool.submit(() -> writeExchange(method, AVAILABILITY_PATH + "/" + slot, access,
                    method.equals("DELETE") ? null : times(writeStart().plusHours(3))));
            try {
                // Observe the application connection waiting on the row lock, rather than assuming a sleep proves it.
                long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
                boolean waiting = false;
                while (!waiting && System.nanoTime() < deadline) {
                    waiting = jdbc.queryForObject("SELECT exists(SELECT 1 FROM pg_stat_activity WHERE datname=current_database() AND wait_event_type='Lock' AND pid<>pg_backend_pid())", Boolean.class);
                    if (!waiting) Thread.sleep(20);
                }
                assertTrue(waiting, "HTTP writer must wait for the locked slot");
                UUID booking = UUID.randomUUID();
                try (var statement = connection.prepareStatement("INSERT INTO bookings(id,member_id,pt_id,slot_id,start_at,end_at,status) SELECT ?,?,pt_id,id,start_at,end_at,'CONFIRMED' FROM availability_slots WHERE id=?")) {
                    statement.setObject(1, booking); statement.setObject(2, fixture.memberA.profileId); statement.setObject(3, slot);
                    assertEquals(1, statement.executeUpdate());
                }
                connection.commit();
                writeBookings.add(booking);
                assertWriteConflict(response.get(15, TimeUnit.SECONDS));
                assertEquals("AVAILABLE", jdbc.queryForObject("SELECT status FROM availability_slots WHERE id=?", String.class, slot));
            } finally { connection.rollback(); }
        }
    }

    private HttpResponse<String> writeExchange(String method, String path, String access, Object body) throws Exception {
        String correlation = "http-baseline-" + UUID.randomUUID();
        var builder = HttpRequest.newBuilder(URI.create("http://127.0.0.1:" + port + path)).timeout(Duration.ofSeconds(12))
                .header("Authorization", "Bearer " + access).header("X-Correlation-Id", correlation);
        if (body != null) builder.header("Content-Type", "application/json");
        var response = client.send(builder.method(method, body == null ? HttpRequest.BodyPublishers.noBody()
                : HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body))).build(), HttpResponse.BodyHandlers.ofString());
        assertEquals(correlation, response.headers().firstValue("X-Correlation-Id").orElse(""));
        if (response.statusCode() >= 400) {
            assertEquals(correlation, object(object(json.readValue(response.body(), Object.class)).get("error")).get("correlationId"));
        }
        return response;
    }

    private void rememberCreated(HttpResponse<String> response) {
        var body = object(json.readValue(response.body(), Object.class));
        UUID id = UUID.fromString((String) body.get("id"));
        writeSlots.add(id);
        assertEquals(fixture.ptA.profileId.toString(), body.get("ptId"));
        assertEquals("AVAILABLE", body.get("status"));
        assertEquals(Duration.ofMinutes(90), Duration.between(Instant.parse((String) body.get("startAt")), Instant.parse((String) body.get("endAt"))));
    }

    private void assertWriteConflict(HttpResponse<String> response) {
        assertEquals(409, response.statusCode());
        var body = object(json.readValue(response.body(), Object.class));
        assertEquals(false, body.get("success"));
        assertEquals(409, body.get("status"));
        assertEquals("ERR_CONFLICT", object(body.get("error")).get("code"));
    }

    @Test void adminReadsEffectivePolicyWithUtcPayloadAndNoWrites() throws Exception {
        testClock.fixed.set(POLICY_NOW);
        withPolicy(true, POLICY_NOW.minusSeconds(3600), id -> assertPolicy(id));
    }

    @Test void adminReadsActualLimitsRatherThanInitialDefaults() throws Exception {
        testClock.fixed.set(POLICY_NOW);
        withPolicy(true, POLICY_NOW, id -> {
            jdbc.update("UPDATE booking_policy SET max_advance_days=21,min_notice_hours=3,cancel_deadline_hours=6,max_future_bookings=8 WHERE id=?", id);
            assertPolicy(id);
        });
    }

    @Test void effectiveFromExactlyNowIsEffective() throws Exception {
        testClock.fixed.set(POLICY_NOW);
        withPolicy(true, POLICY_NOW, id -> assertPolicy(id));
    }

    @ParameterizedTest(name = "policy unavailable: {0}")
    @ValueSource(strings = {"absent", "inactive", "future"})
    void noEffectivePolicyReturnsSpecific404WithoutCreatingDefaults(String state) throws Exception {
        testClock.fixed.set(POLICY_NOW);
        if (state.equals("absent")) {
            error("GET", POLICY_PATH, token(fixture.admin), null, 404, "BOOKING_POLICY_NOT_FOUND");
            assertEquals(0, jdbc.queryForObject("SELECT count(*) FROM booking_policy", Integer.class));
        } else {
            Instant effective = state.equals("future") ? POLICY_NOW.plusNanos(1000) : POLICY_NOW.minusSeconds(3600);
            withPolicy(state.equals("future"), effective, id -> {
                var before = jdbc.queryForMap("SELECT * FROM booking_policy WHERE id=?", id);
                error("GET", POLICY_PATH, token(fixture.admin), null, 404, "BOOKING_POLICY_NOT_FOUND");
                assertEquals(before, jdbc.queryForMap("SELECT * FROM booking_policy WHERE id=?", id));
                assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM booking_policy", Integer.class));
            });
        }
    }

    @Test void inactivePastPolicyIsNotFallbackForFutureActivePolicy() throws Exception {
        testClock.fixed.set(POLICY_NOW);
        withPolicy(false, POLICY_NOW.minusSeconds(3600), pastId ->
                withPolicy(true, POLICY_NOW.plusSeconds(3600), futureId -> {
                    error("GET", POLICY_PATH, token(fixture.admin), null, 404, "BOOKING_POLICY_NOT_FOUND");
                    assertEquals(2, jdbc.queryForObject("SELECT count(*) FROM booking_policy", Integer.class));
                }));
    }

    @ParameterizedTest(name = "policy forbidden for {0}")
    @ValueSource(strings = {"memberA", "memberB", "ptA", "ptB"})
    void onlyAdminCanReadBookingPolicy(String actorName) throws Exception {
        error("GET", POLICY_PATH, token(actor(actorName)), null, 403, "ERR_FORBIDDEN");
    }

    @Test void anonymousPolicyReadIsUnauthorized() throws Exception {
        error("GET", POLICY_PATH, null, null, 401, "ERR_UNAUTHORIZED");
    }

    @FunctionalInterface
    private interface PolicyScenario { void run(UUID id) throws Exception; }

    private void withPolicy(boolean active, Instant effective, PolicyScenario scenario) throws Exception {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO booking_policy(id,max_advance_days,min_notice_hours,cancel_deadline_hours,max_future_bookings,effective_from,active,updated_by) VALUES(?,14,2,4,5,?,?,?)",
                id, effective.atOffset(ZoneOffset.ofHours(7)), active, fixture.admin.userId);
        try { scenario.run(id); }
        finally {
            assertEquals(1, jdbc.update("DELETE FROM booking_policy WHERE id=?", id), "Only this policy fixture must be removed");
        }
    }

    private void assertPolicy(UUID id) throws Exception {
        var stored = jdbc.queryForMap("SELECT * FROM booking_policy WHERE id=?", id);
        var body = object(request("GET", POLICY_PATH, token(fixture.admin), null, 200));
        assertEquals(Set.of("id","maxAdvanceDays","minNoticeHours","cancelDeadlineHours","maxFutureBookings","effectiveFrom"), body.keySet());
        assertEquals(id.toString(), body.get("id"));
        assertEquals(stored.get("max_advance_days"), body.get("maxAdvanceDays"));
        assertEquals(stored.get("min_notice_hours"), body.get("minNoticeHours"));
        assertEquals(stored.get("cancel_deadline_hours"), body.get("cancelDeadlineHours"));
        assertEquals(stored.get("max_future_bookings"), body.get("maxFutureBookings"));
        Instant effective = jdbc.queryForObject("SELECT effective_from FROM booking_policy WHERE id=?",
                (result, row) -> result.getObject(1, OffsetDateTime.class).toInstant(), id);
        assertEquals(effective.toString(), body.get("effectiveFrom"), "effectiveFrom must be ISO-8601 UTC");
        assertEquals(stored, jdbc.queryForMap("SELECT * FROM booking_policy WHERE id=?", id), "GET must not modify policy");
    }

    @ParameterizedTest(name = "login {0}")
    @ValueSource(strings = {"admin", "memberA", "memberB", "ptA", "ptB"})
    void loginWithRealBcrypt(String name) throws Exception {
        assertLogin(login(actor(name)), actor(name).role);
    }

    @Test void wrongPasswordIsRejected() throws Exception {
        error("POST", "/api/v1/auth/login", null,
                Map.of("email", fixture.memberA.email, "password", HttpBaselineFixture.randomSecret()), 401, "ERR_UNAUTHORIZED");
    }

    @Test void emptyLoginIsValidationError() throws Exception {
        error("POST", "/api/v1/auth/login", null, Map.of(), 400, "ERR_VALIDATION");
    }

    @ParameterizedTest(name = "refresh {0}")
    @ValueSource(strings = {"admin", "memberA", "ptA"})
    void refreshProducesUsableAccessToken(String name) throws Exception {
        var actor = actor(name);
        Map<String, Object> original = login(actor);
        Map<String, Object> refreshed = object(request("POST", "/api/v1/auth/refresh", null,
                Map.of("refreshToken", original.get("refreshToken")), 200));
        assertLogin(refreshed, actor.role);
        int index = actor.role.equals("PT") ? 7 : actor.role.equals("MEMBER") ? 8 : 0;
        assertRead(index, actor, (String) refreshed.get("accessToken"));
        // Baseline is stateless: do not require rotation/revocation absent from its contract.
    }

    @Test void invalidRefreshIsRejected() throws Exception {
        error("POST", "/api/v1/auth/refresh", null, Map.of("refreshToken", "invalid"), 401, "ERR_UNAUTHORIZED");
    }

    @Test void accessTokenCannotBeUsedForRefresh() throws Exception {
        error("POST", "/api/v1/auth/refresh", null, Map.of("refreshToken", token(fixture.memberA)), 401, "ERR_UNAUTHORIZED");
    }

    @Test void refreshTokenCannotAuthorizeRead() throws Exception {
        error("GET", "/api/v1/memberships/me", (String) login(fixture.memberA).get("refreshToken"), null, 401, "ERR_UNAUTHORIZED");
    }

    static Stream<Arguments> roles() {
        return Stream.of("admin", "memberA", "ptA")
                .flatMap(role -> IntStream.range(0, 10).mapToObj(index -> Arguments.of(role, index)));
    }

    @ParameterizedTest(name = "role {0}, read API {1}")
    @MethodSource("roles")
    void roleMatrixChecksPayloadWhenAllowed(String name, int index) throws Exception {
        var actor = actor(name);
        boolean allowed = index < 2 ? !actor.role.equals("PT")
                : index == 7 || index == 9 ? actor.role.equals("PT") : actor.role.equals("MEMBER");
        if (allowed) assertRead(index, actor, token(actor));
        else error("GET", path(index), token(actor), null, 403, "ERR_FORBIDDEN");
    }

    @ParameterizedTest(name = "anonymous read API {0}")
    @ValueSource(ints = {0,1,2,3,4,5,6,7,8,9})
    void anonymousCannotRead(int index) throws Exception {
        error("GET", path(index), null, null, 401, "ERR_UNAUTHORIZED");
    }

    @ParameterizedTest(name = "member ownership {0}")
    @ValueSource(strings = {"memberA", "memberB"})
    void memberCannotReadOtherMembersBookings(String name) throws Exception {
        var actor = actor(name);
        var other = name.equals("memberA") ? fixture.memberB : fixture.memberA;
        List<HttpBaselineFixture.Booking> expected = memberBookings(actor);
        Object body = request("GET", path(8) + "&memberId=" + other.profileId, token(actor), null, 200);
        assertBookings(body, expected);
        assertTrue(expected.stream().allMatch(row -> row.memberId().equals(actor.profileId)));
    }

    @ParameterizedTest(name = "membership profile {0}")
    @ValueSource(strings = {"memberA", "memberB"})
    void membershipUsesTheAuthenticatedMembersProfile(String name) throws Exception {
        var actor = actor(name);
        assertNotEquals(actor.userId, actor.profileId);
        assertRead(2, actor, token(actor));
    }

    @ParameterizedTest(name = "PT ownership {0}")
    @ValueSource(strings = {"ptA", "ptB"})
    void trainerCannotReadOtherTrainersBookings(String name) throws Exception {
        var actor = actor(name);
        var other = name.equals("ptA") ? fixture.ptB : fixture.ptA;
        Object body = request("GET", path(9) + "&ptId=" + other.profileId, token(actor), null, 200);
        assertBookings(body, ptBookings(actor));
        assertSlots(request("GET", path(7) + "&ptId=" + other.profileId, token(actor), null, 200),
                fixture.slots.stream().filter(row -> row.ptId().equals(actor.profileId)).toList());
    }

    @ParameterizedTest
    @ValueSource(strings = {"CONFIRMED", "CANCELLED", "COMPLETED"})
    void bookingStatusFiltersMatchFixture(String status) throws Exception {
        List<HttpBaselineFixture.Booking> expected = memberBookings(fixture.memberA).stream()
                .filter(row -> row.status().equals(status)).toList();
        assertBookings(request("GET", path(8) + "&status=" + status, token(fixture.memberA), null, 200), expected);
        assertBookings(request("GET", path(9) + "&status=" + status, token(fixture.ptA), null, 200), expected);
    }

    @ParameterizedTest
    @ValueSource(strings = {"AVAILABLE", "BOOKED", "DISABLED"})
    void slotStatusFiltersMatchFixture(String status) throws Exception {
        assertSlots(request("GET", path(7) + "&status=" + status, token(fixture.ptA), null, 200),
                fixture.slots.stream().filter(row -> row.ptId().equals(fixture.ptA.profileId) && row.status().equals(status)).toList());
    }

    @Test void dateRangeIsInclusiveFromExclusiveTo() throws Exception {
        String range = range(fixture.booked.start().withOffsetSameInstant(java.time.ZoneOffset.ofHours(7)),
                fixture.cancelled.start().withOffsetSameInstant(java.time.ZoneOffset.ofHours(7)));
        assertBookings(request("GET", "/api/v1/bookings/me" + range, token(fixture.memberA), null, 200), List.of(fixture.confirmedA));
        assertBookings(request("GET", "/api/v1/pt/bookings" + range, token(fixture.ptA), null, 200), List.of(fixture.confirmedA));
        assertSlots(request("GET", "/api/v1/pt/slots" + range, token(fixture.ptA), null, 200), List.of(fixture.booked));
        String availableRange = range(fixture.available.start(), fixture.booked.start());
        assertSlots(request("GET", "/api/v1/trainers/" + fixture.ptA.profileId + "/slots" + availableRange,
                token(fixture.memberA), null, 200), List.of(fixture.available));
    }

    @Test void validEmptyRangeReturnsEmptyArray() throws Exception {
        String range = range(fixture.future.plusDays(10), fixture.future.plusDays(11));
        assertBookings(request("GET", "/api/v1/bookings/me" + range, token(fixture.memberA), null, 200), List.of());
        assertBookings(request("GET", "/api/v1/pt/bookings" + range, token(fixture.ptA), null, 200), List.of());
        assertSlots(request("GET", "/api/v1/pt/slots" + range, token(fixture.ptA), null, 200), List.of());
    }

    @Test void invalidRangeAndStatusAreValidationErrors() throws Exception {
        error("GET", "/api/v1/bookings/me" + range(fixture.future, fixture.past), token(fixture.memberA), null, 400, "ERR_VALIDATION");
        error("GET", path(8) + "&status=PENDING", token(fixture.memberA), null, 400, "ERR_VALIDATION");
        error("GET", path(9) + "&status=REJECTED", token(fixture.ptA), null, 400, "ERR_VALIDATION");
        error("GET", path(7) + "&status=UNKNOWN", token(fixture.ptA), null, 400, "ERR_VALIDATION");
    }

    @Test void inactiveAndMissingResourcesAreNotFound() throws Exception {
        error("GET", "/api/v1/membership-plans/" + fixture.inactivePlanId, token(fixture.memberA), null, 404, "ERR_NOT_FOUND");
        error("GET", "/api/v1/membership-plans/" + UUID.randomUUID(), token(fixture.admin), null, 404, "ERR_NOT_FOUND");
        error("GET", "/api/v1/trainers/" + UUID.randomUUID(), token(fixture.memberA), null, 404, "ERR_NOT_FOUND");
    }

    @Test void repeatFixtureLifecyclePreservesExistingRows() {
        List<String> tables = List.of("users", "members", "personal_trainers", "membership_plans", "memberships", "availability_slots", "bookings");
        Map<String, Set<UUID>> before = new HashMap<>();
        for (String table : tables) before.put(table, new HashSet<>(jdbc.queryForList("SELECT id FROM " + table, UUID.class)));
        // The main fixture is unrelated pre-existing data from this second fixture's perspective.
        try (var second = new HttpBaselineFixture(jdbc, new TransactionTemplate(transactions))) {
            second.seed(encoder);
            assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM bookings WHERE id=?", Integer.class, second.confirmedA.id()));
        }
        for (String table : tables) {
            assertEquals(before.get(table), new HashSet<>(jdbc.queryForList("SELECT id FROM " + table, UUID.class)), "Rows changed outside second fixture: " + table);
        }
    }

    @Test void cleanupRefusesToCascadeIntoUnownedNotifications() {
        UUID notificationId = UUID.randomUUID();
        try (var second = new HttpBaselineFixture(jdbc, new TransactionTemplate(transactions))) {
            second.seed(encoder);
            try {
                jdbc.update("INSERT INTO notifications(id,user_id,type,title) VALUES(?,?,'TEST','Outside fixture ownership')",
                        notificationId, second.memberA.userId);
                assertThrows(IllegalStateException.class, second::close);
                assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM notifications WHERE id=?", Integer.class, notificationId));
                assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM bookings WHERE id=?", Integer.class, second.confirmedA.id()),
                        "A refused cleanup must roll back earlier deletions");
            } finally {
                jdbc.update("DELETE FROM notifications WHERE id=?", notificationId);
            }
        }
    }

    private String path(int index) {
        String range = range(fixture.past.minusDays(1), fixture.future.plusDays(3));
        return switch (index) {
            case 0 -> "/api/v1/membership-plans";
            case 1 -> "/api/v1/membership-plans/" + fixture.planId;
            case 2 -> "/api/v1/memberships/me";
            case 3 -> "/api/v1/trainers";
            case 4 -> "/api/v1/trainers/" + fixture.ptA.profileId;
            case 5 -> "/api/v1/trainers/" + fixture.ptA.profileId + "/slots" + range;
            case 6 -> "/api/v1/trainers/" + fixture.ptA.profileId + "/availability" + range;
            case 7 -> "/api/v1/pt/slots" + range;
            case 8 -> "/api/v1/bookings/me" + range;
            case 9 -> "/api/v1/pt/bookings" + range;
            default -> throw new IllegalArgumentException("Unknown read case");
        };
    }

    private void assertRead(int index, HttpBaselineFixture.Actor actor, String accessToken) throws Exception {
        Object body = request("GET", path(index), accessToken, null, 200);
        switch (index) {
            case 0 -> {
                var rows = array(body);
                assertFalse(rows.stream().anyMatch(row -> fixture.inactivePlanId.toString().equals(row.get("id"))));
                assertPlan(rows.stream().filter(row -> fixture.planId.toString().equals(row.get("id"))).findFirst().orElseThrow());
            }
            case 1 -> assertPlan(object(body));
            case 2 -> {
                var rows = array(body);
                assertEquals(1, rows.size());
                var row = rows.getFirst();
                assertEquals((actor == fixture.memberA ? fixture.membershipA : fixture.membershipB).toString(), row.get("id"));
                assertEquals(fixture.planId.toString(), row.get("planId"));
                assertEquals(fixture.planName, row.get("planName"));
                assertEquals(fixture.today.toString(), row.get("startDate"));
                assertEquals(fixture.expiry.toString(), row.get("endDate"));
                assertEquals("ACTIVE", row.get("status"));
            }
            case 3 -> {
                for (var trainer : List.of(fixture.ptA, fixture.ptB)) {
                    assertTrainer(array(body).stream().filter(row -> trainer.profileId.toString().equals(row.get("id"))).findFirst().orElseThrow(), trainer);
                }
            }
            case 4 -> assertTrainer(object(body), fixture.ptA);
            case 5, 6 -> assertSlots(body, List.of(fixture.available));
            case 7 -> assertSlots(body, fixture.slots.stream().filter(row -> row.ptId().equals(actor.profileId)).toList());
            case 8 -> assertBookings(body, memberBookings(actor));
            case 9 -> assertBookings(body, ptBookings(actor));
            default -> fail("Unknown read case");
        }
    }

    private void assertPlan(Map<String, Object> row) {
        assertEquals(fixture.planId.toString(), row.get("id"));
        assertEquals(fixture.planName, row.get("name"));
        assertEquals("Synthetic plan", row.get("description"));
        assertEquals(30, ((Number) row.get("durationDays")).intValue());
        assertEquals(0, new java.math.BigDecimal("100000.00").compareTo(new java.math.BigDecimal(row.get("price").toString())));
    }

    private void assertTrainer(Map<String, Object> row, HttpBaselineFixture.Actor trainer) {
        assertEquals(trainer.profileId.toString(), row.get("id"));
        assertEquals(trainer.label, row.get("fullName"));
        assertEquals("Synthetic bio", row.get("bio"));
        assertEquals("Synthetic training", row.get("specialization"));
        assertEquals("Fixture only", row.get("experienceSummary"));
    }

    private void assertSlots(Object body, List<HttpBaselineFixture.Slot> expected) {
        var ordered = expected.stream().sorted(Comparator.comparing(HttpBaselineFixture.Slot::start)).toList();
        var rows = array(body);
        assertEquals(ordered.stream().map(row -> row.id().toString()).toList(), rows.stream().map(row -> row.get("id")).toList());
        for (int index = 0; index < ordered.size(); index++) {
            var actual = rows.get(index);
            var wanted = ordered.get(index);
            assertEquals(wanted.ptId().toString(), actual.get("ptId"));
            assertTime(wanted.start(), actual.get("startAt"));
            assertTime(wanted.end(), actual.get("endAt"));
            assertEquals(wanted.status(), actual.get("status"));
        }
    }

    private void assertBookings(Object body, List<HttpBaselineFixture.Booking> expected) {
        var ordered = expected.stream().sorted(Comparator.comparing(row -> row.slot().start())).toList();
        var rows = array(body);
        assertEquals(ordered.stream().map(row -> row.id().toString()).toList(), rows.stream().map(row -> row.get("id")).toList());
        for (int index = 0; index < ordered.size(); index++) {
            var actual = rows.get(index);
            var wanted = ordered.get(index);
            assertEquals(wanted.memberId().toString(), actual.get("memberId"));
            assertEquals(wanted.slot().ptId().toString(), actual.get("ptId"));
            assertEquals(wanted.slot().id().toString(), actual.get("slotId"));
            assertTime(wanted.slot().start(), actual.get("startAt"));
            assertTime(wanted.slot().end(), actual.get("endAt"));
            assertEquals(wanted.status(), actual.get("status"));
            assertEquals(wanted.cancelledBy(), actual.get("cancelledBy"));
            assertEquals(wanted.reason(), actual.get("cancelReason"));
            assertTime(wanted.cancelledAt(), actual.get("cancelledAt"));
            assertTime(wanted.completedAt(), actual.get("completedAt"));
        }
    }

    private static void assertTime(OffsetDateTime expected, Object actual) {
        if (expected == null) assertNull(actual);
        else assertEquals(expected.toInstant(), OffsetDateTime.parse((String) actual).toInstant());
    }

    private List<HttpBaselineFixture.Booking> memberBookings(HttpBaselineFixture.Actor actor) {
        return fixture.bookings.stream().filter(row -> row.memberId().equals(actor.profileId)).toList();
    }
    private List<HttpBaselineFixture.Booking> ptBookings(HttpBaselineFixture.Actor actor) {
        return fixture.bookings.stream().filter(row -> row.slot().ptId().equals(actor.profileId)).toList();
    }
    private HttpBaselineFixture.Actor actor(String name) {
        return switch (name) {
            case "admin" -> fixture.admin;
            case "memberA" -> fixture.memberA;
            case "memberB" -> fixture.memberB;
            case "ptA" -> fixture.ptA;
            case "ptB" -> fixture.ptB;
            default -> throw new IllegalArgumentException("Unknown synthetic actor");
        };
    }

    private Map<String, Object> login(HttpBaselineFixture.Actor actor) throws Exception {
        return object(request("POST", "/api/v1/auth/login", null, Map.of("email", actor.email, "password", actor.password), 200));
    }
    private String token(HttpBaselineFixture.Actor actor) throws Exception {
        if (!accessTokens.containsKey(actor.email)) {
            var login = login(actor);
            assertLogin(login, actor.role);
            accessTokens.put(actor.email, (String) login.get("accessToken"));
        }
        return accessTokens.get(actor.email);
    }
    private void assertLogin(Map<String, Object> body, String role) {
        assertEquals(role, body.get("role"));
        assertTrue(body.get("accessToken") instanceof String value && !value.isBlank(), "Missing access token");
        assertTrue(body.get("refreshToken") instanceof String value && !value.isBlank(), "Missing refresh token");
    }

    private Object request(String method, String path, String token, Object body, int expected) throws Exception {
        var request = HttpRequest.newBuilder(URI.create("http://127.0.0.1:" + port + path)).timeout(Duration.ofSeconds(10));
        String correlationId = "http-baseline-" + UUID.randomUUID();
        request.header("X-Correlation-Id", correlationId);
        if (token != null) request.header("Authorization", "Bearer " + token);
        if (body != null) request.header("Content-Type", "application/json");
        request.method(method, body == null ? HttpRequest.BodyPublishers.noBody() : HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body)));
        var response = client.send(request.build(), HttpResponse.BodyHandlers.ofString());
        assertEquals(expected, response.statusCode(), "Unexpected HTTP status for " + method + " " + path.split("\\?")[0]);
        assertEquals(correlationId, response.headers().firstValue("X-Correlation-Id").orElse(""));
        if (expected == 204) {
            assertTrue(response.body().isEmpty());
            return null;
        }
        assertTrue(response.headers().firstValue("Content-Type").orElse("").startsWith("application/json"));
        // Never include raw response bodies/headers in assertions: auth responses contain tokens.
        Object parsed = json.readValue(response.body(), Object.class);
        if (parsed instanceof Map<?, ?> envelope && envelope.get("error") instanceof Map<?, ?> detail) {
            assertEquals(correlationId, detail.get("correlationId"));
        }
        return parsed;
    }

    private void error(String method, String path, String token, Object body, int expected, String code) throws Exception {
        var response = object(request(method, path, token, body, expected));
        assertEquals(false, response.get("success"));
        assertEquals(expected, ((Number) response.get("status")).intValue());
        var detail = object(response.get("error"));
        assertEquals(code, detail.get("code"));
        assertTrue(detail.get("correlationId") instanceof String value && !value.isBlank());
        assertTrue(detail.get("details") instanceof Map);
    }

    private static String range(OffsetDateTime from, OffsetDateTime to) {
        return "?from=" + URLEncoder.encode(from.toString(), StandardCharsets.UTF_8)
                + "&to=" + URLEncoder.encode(to.toString(), StandardCharsets.UTF_8);
    }
    @SuppressWarnings("unchecked") private static Map<String, Object> object(Object value) {
        assertTrue(value instanceof Map, "Expected JSON object");
        return (Map<String, Object>) value;
    }
    @SuppressWarnings("unchecked") private static List<Map<String, Object>> array(Object value) {
        assertTrue(value instanceof List, "Expected JSON array");
        return (List<Map<String, Object>>) value;
    }
}
