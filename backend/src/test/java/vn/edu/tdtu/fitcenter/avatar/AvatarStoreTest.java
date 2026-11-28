package vn.edu.tdtu.fitcenter.avatar;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.web.server.ResponseStatusException;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class AvatarStoreTest {
    @TempDir Path directory;

    static byte[] image(int width, int height, String format) throws Exception {
        var picture = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        var output = new ByteArrayOutputStream();
        ImageIO.write(picture, format, output);
        return output.toByteArray();
    }

    private int status(byte[] upload) {
        var failure = assertThrows(ResponseStatusException.class, () -> AvatarStore.toSquareJpeg(upload));
        return failure.getStatusCode().value();
    }

    @Test void storesAnySupportedImageAsASmallSquareJpeg() throws Exception {
        var store = new AvatarStore(directory.toString());
        UUID user = UUID.randomUUID();
        store.save(user, image(900, 600, "png"));
        byte[] saved = store.load(user).orElseThrow();
        var decoded = ImageIO.read(new ByteArrayInputStream(saved));
        assertEquals(512, decoded.getWidth());
        assertEquals(512, decoded.getHeight());
        assertEquals((byte) 0xFF, saved[0]);
        assertEquals((byte) 0xD8, saved[1]);
    }

    @Test void smallImagesAreNotEnlarged() throws Exception {
        var decoded = ImageIO.read(new ByteArrayInputStream(AvatarStore.toSquareJpeg(image(80, 120, "jpg"))));
        assertEquals(80, decoded.getWidth());
        assertEquals(80, decoded.getHeight());
    }

    @Test void hiddenDataAfterTheImageIsNotKept() throws Exception {
        byte[] clean = image(64, 64, "jpg");
        byte[] marker = "SECRET-LOCATION-10.77,106.69".getBytes(StandardCharsets.US_ASCII);
        byte[] upload = java.util.Arrays.copyOf(clean, clean.length + marker.length);
        System.arraycopy(marker, 0, upload, clean.length, marker.length);
        assertFalse(new String(AvatarStore.toSquareJpeg(upload), StandardCharsets.ISO_8859_1).contains("SECRET-LOCATION"));
    }

    @Test void rejectsWrongOrDangerousUploads() throws Exception {
        assertEquals(400, status(new byte[0]));
        assertEquals(400, status("<svg onload=alert(1)>".getBytes(StandardCharsets.UTF_8)));
        assertEquals(400, status(image(10, 10, "gif")));
        assertEquals(400, status(new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 1, 2, 3})); // truncated
        assertEquals(400, status(image(AvatarStore.MAX_SIDE + 1, 1, "png")));
        assertEquals(413, status(new byte[AvatarStore.MAX_BYTES + 1]));
    }

    @Test void deleteAndMissingAreHarmlessAndNoTemporaryFilesRemain() throws Exception {
        var store = new AvatarStore(directory.toString());
        UUID user = UUID.randomUUID();
        assertTrue(store.load(user).isEmpty());
        store.delete(user);
        store.save(user, image(50, 50, "png"));
        store.save(user, image(60, 60, "png"));
        try (var files = Files.list(directory)) {
            assertEquals(1, files.count());
        }
        store.delete(user);
        assertTrue(store.load(user).isEmpty());
    }
}
