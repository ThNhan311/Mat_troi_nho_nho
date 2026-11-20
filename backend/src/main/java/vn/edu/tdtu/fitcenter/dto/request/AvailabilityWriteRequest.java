package vn.edu.tdtu.fitcenter.dto.request;

import java.time.OffsetDateTime;

/** POST requires both fields; PATCH may omit either field and retains its stored value. */
public record AvailabilityWriteRequest(OffsetDateTime startAt, OffsetDateTime endAt) {}
