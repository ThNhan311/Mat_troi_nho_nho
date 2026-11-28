package vn.edu.tdtu.fitcenter.avatar;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.stream.ImageInputStream;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Optional;
import java.util.UUID;

/**
 * Avatars are files named by user id, outside Git and without a schema change.
 * Every upload is decoded and re-encoded, so stored bytes are always a plain
 * square JPEG without the original metadata.
 */
@Component
@ConditionalOnProperty(name = "fitcenter.avatar.enabled", havingValue = "true")
public class AvatarStore {
    static final int MAX_BYTES = 5 * 1024 * 1024;
    static final int MAX_SIDE = 6000;
    static final int OUTPUT_SIDE = 512;

    private final Path directory;

    public AvatarStore(@Value("${fitcenter.avatar.directory:${user.home}/.fitcenter/avatars}") String directory) {
        this.directory = Path.of(directory).toAbsolutePath().normalize();
    }

    public void save(UUID userId, byte[] upload) {
        byte[] jpeg = toSquareJpeg(upload);
        try {
            Files.createDirectories(directory);
            Path temporary = Files.createTempFile(directory, "upload-", ".tmp");
            try {
                Files.write(temporary, jpeg);
                // An interrupted write never leaves a half-written avatar.
                Files.move(temporary, file(userId), StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
            } finally {
                Files.deleteIfExists(temporary);
            }
        } catch (IOException e) {
            throw new UncheckedIOException("Avatar could not be stored", e);
        }
    }

    public Optional<byte[]> load(UUID userId) {
        try {
            Path path = file(userId);
            return Files.isRegularFile(path) ? Optional.of(Files.readAllBytes(path)) : Optional.empty();
        } catch (IOException e) {
            throw new UncheckedIOException("Avatar could not be read", e);
        }
    }

    public void delete(UUID userId) {
        try {
            Files.deleteIfExists(file(userId));
        } catch (IOException e) {
            throw new UncheckedIOException("Avatar could not be deleted", e);
        }
    }

    private Path file(UUID userId) {
        return directory.resolve(userId + ".jpg"); // A UUID cannot escape the directory.
    }

    static byte[] toSquareJpeg(byte[] upload) {
        if (upload.length > MAX_BYTES) {
            throw new ResponseStatusException(HttpStatus.CONTENT_TOO_LARGE, "Image must be at most 5 MB");
        }
        if (!isJpeg(upload) && !isPng(upload)) {
            throw invalid();
        }
        try (ImageInputStream input = ImageIO.createImageInputStream(new ByteArrayInputStream(upload))) {
            var readers = ImageIO.getImageReaders(input);
            if (!readers.hasNext()) throw invalid();
            ImageReader reader = readers.next();
            try {
                reader.setInput(input);
                // Check the declared size before decoding so a tiny file cannot allocate a huge bitmap.
                int width = reader.getWidth(0), height = reader.getHeight(0);
                if (width < 1 || height < 1 || width > MAX_SIDE || height > MAX_SIDE) throw invalid();
                return encode(reader.read(0));
            } finally {
                reader.dispose();
            }
        } catch (IOException | IllegalArgumentException e) {
            throw invalid();
        }
    }

    private static byte[] encode(BufferedImage source) throws IOException {
        int crop = Math.min(source.getWidth(), source.getHeight());
        int x = (source.getWidth() - crop) / 2, y = (source.getHeight() - crop) / 2;
        int side = Math.min(crop, OUTPUT_SIDE);
        var target = new BufferedImage(side, side, BufferedImage.TYPE_INT_RGB);
        Graphics2D graphics = target.createGraphics();
        try {
            graphics.setColor(Color.WHITE); // JPEG has no transparency.
            graphics.fillRect(0, 0, side, side);
            graphics.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
            graphics.drawImage(source, 0, 0, side, side, x, y, x + crop, y + crop, null);
        } finally {
            graphics.dispose();
        }
        var output = new ByteArrayOutputStream();
        if (!ImageIO.write(target, "jpg", output)) throw new IOException("JPEG writer unavailable");
        return output.toByteArray();
    }

    private static boolean isJpeg(byte[] data) {
        return data.length > 3 && (data[0] & 0xFF) == 0xFF && (data[1] & 0xFF) == 0xD8 && (data[2] & 0xFF) == 0xFF;
    }

    private static boolean isPng(byte[] data) {
        return data.length > 8 && (data[0] & 0xFF) == 0x89 && data[1] == 'P' && data[2] == 'N' && data[3] == 'G';
    }

    private static ResponseStatusException invalid() {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, "Send a valid JPEG or PNG image up to 6000 pixels per side");
    }
}
