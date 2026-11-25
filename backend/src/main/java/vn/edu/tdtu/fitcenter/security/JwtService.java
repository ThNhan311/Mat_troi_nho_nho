package vn.edu.tdtu.fitcenter.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import vn.edu.tdtu.fitcenter.domain.entity.User;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

@Service
public class JwtService {

    @Value("${jwt.secret}")
    private String secret;

    @Value("${jwt.access-expiration-ms}")
    private long accessExpirationMs;

    @Value("${jwt.refresh-expiration-ms}")
    private long refreshExpirationMs;

    public String generateAccessToken(User user) {
        return generateToken(
                user,
                accessExpirationMs,
                "access"
        );
    }

    public String generateRefreshToken(User user) {
        return generateToken(
                user,
                refreshExpirationMs,
                "refresh"
        );
    }

    private String generateToken(
            User user,
            long expirationMs,
            String tokenType
    ) {

        Date now = new Date();
        Date expiration = new Date(
                now.getTime() + expirationMs
        );

        return Jwts.builder()
                .subject(user.getId().toString())
                .claim("email", user.getEmail())
                .claim("role", user.getRole().name())
                .claim("type", tokenType)
                .issuedAt(now)
                .expiration(expiration)
                .signWith(getSigningKey())
                .compact();
    }

    public Claims extractAllClaims(String token) {
        return Jwts.parser()
                .verifyWith(getSigningKey())
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    public String extractUserId(String token) {
        return extractAllClaims(token)
                .getSubject();
    }

    public String extractEmail(String token) {
        return extractAllClaims(token)
                .get("email", String.class);
    }

    public String extractRole(String token) {
        return extractAllClaims(token)
                .get("role", String.class);
    }

    public String extractTokenType(String token) {
        return extractAllClaims(token)
                .get("type", String.class);
    }

    public boolean isAccessTokenValid(String token) {
        try {

            Claims claims = extractAllClaims(token);

            Date expiration = claims.getExpiration();

            String tokenType =
                    claims.get("type", String.class);

            return expiration != null
                    && expiration.after(new Date())
                    && "access".equals(tokenType);

        } catch (Exception e) {

            return false;
        }
    }

    public boolean isRefreshTokenValid(String token) {
        try {

            Claims claims = extractAllClaims(token);

            Date expiration = claims.getExpiration();

            String tokenType =
                    claims.get("type", String.class);

            return expiration != null
                    && expiration.after(new Date())
                    && "refresh".equals(tokenType);

        } catch (Exception e) {

            return false;
        }
    }

    private SecretKey getSigningKey() {

        return Keys.hmacShaKeyFor(
                secret.getBytes(
                        StandardCharsets.UTF_8
                )
        );
    }
}