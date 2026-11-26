package vn.edu.tdtu.fitcenter.kiosk;

import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class KioskTest {
    private static final class MovingClock extends Clock {
        Instant now = Instant.parse("2030-01-01T00:00:00Z");

        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }

    private final MovingClock clock = new MovingClock();
    private final KioskDesk desk = new KioskDesk(clock);

    @Test
    void onlyTheWaitingRequestCanBeFinishedAndOnlyOnce() {
        assertNull(desk.current());
        var first = desk.request(UUID.randomUUID(), "A");
        var second = desk.request(UUID.randomUUID(), "B");
        assertFalse(desk.finish(first.requestId(), KioskDesk.Status.SUCCESS));
        assertTrue(desk.finish(second.requestId(), KioskDesk.Status.SUCCESS));
        assertFalse(desk.finish(second.requestId(), KioskDesk.Status.FAILED));
        assertEquals(KioskDesk.Status.SUCCESS, desk.current().status());
    }

    @Test
    void requestExpiresAndCancelStopsIt() {
        var old = desk.request(UUID.randomUUID(), "A");
        clock.now = clock.now.plus(KioskDesk.PENDING_TTL);
        assertEquals(KioskDesk.Status.EXPIRED, desk.current().status());
        assertFalse(desk.finish(old.requestId(), KioskDesk.Status.SUCCESS));
        var next = desk.request(UUID.randomUUID(), "B");
        desk.cancel();
        assertEquals(KioskDesk.Status.CANCELLED, desk.current().status());
        assertFalse(desk.finish(next.requestId(), KioskDesk.Status.SUCCESS));
    }

    @Test
    void repeatedScansAreMergedAndTheListIsShort() {
        var member = UUID.randomUUID();
        desk.scanned(member, "A", "MEMBER", true);
        desk.scanned(member, "A", "MEMBER", true);
        assertEquals(1, desk.recent().size());
        clock.now = clock.now.plus(KioskDesk.REPEAT_WINDOW);
        desk.scanned(member, "A", "MEMBER", true);
        assertEquals(2, desk.recent().size());
        for (int i = 0; i < 20; i++) {
            desk.scanned(UUID.randomUUID(), "B" + i, "PT", false);
        }
        assertEquals(KioskDesk.RECENT_LIMIT, desk.recent().size());
        assertEquals("B19", desk.recent().get(0).memberName());
    }

    @Test
    void faceRegistrySurvivesARestartAndKeepsRemovalsUntilDone(@org.junit.jupiter.api.io.TempDir java.nio.file.Path dir) {
        var file = dir.resolve("faces.properties");
        var id = UUID.randomUUID();
        var faces = new KioskFaces(file);
        assertEquals(KioskFaces.State.NONE, faces.state(id));
        faces.enrolled(id);
        assertEquals(KioskFaces.State.ENROLLED, new KioskFaces(file).state(id));
        faces.requestRemoval(id);
        faces.seen(id);
        assertEquals(java.util.List.of(id), new KioskFaces(file).pendingRemovals());
        faces.removed(id);
        assertEquals(KioskFaces.State.NONE, new KioskFaces(file).state(id));
    }

    @Test
    void openingNeedsAConfiguredScriptAndPassesNoSecrets() {
        var none = assertThrows(org.springframework.web.server.ResponseStatusException.class,
                () -> new KioskLauncher("", clock).open());
        assertEquals(503, none.getStatusCode().value());
        var env = new java.util.HashMap<>(java.util.Map.of("DB_PASSWORD", "a", "JWT_SECRET", "b",
                "FITCENTER_SMTP_APP_PASSWORD", "c", "PGPASSWORD", "d", "Path", "e", "LOCALAPPDATA", "f"));
        KioskLauncher.withoutSecrets(env);
        assertEquals(java.util.Set.of("Path", "LOCALAPPDATA"), env.keySet());
    }

    @Test
    void kioskTokenWorksOnlyFromThisComputer() {
        var token = "k".repeat(KioskSecurity.MIN_TOKEN_LENGTH);
        assertTrue(KioskSecurity.allowed("127.0.0.1", token, token));
        assertFalse(KioskSecurity.allowed("192.168.1.5", token, token));
        assertFalse(KioskSecurity.allowed("127.0.0.1", token + "x", token));
        assertFalse(KioskSecurity.allowed("127.0.0.1", null, token));
    }
}
