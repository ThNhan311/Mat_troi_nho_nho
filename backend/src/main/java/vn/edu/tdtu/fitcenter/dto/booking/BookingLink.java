package vn.edu.tdtu.fitcenter.dto.booking;

import java.util.UUID;

/** Immutable projection for choosing locks without caching a stale Booking entity. */
public record BookingLink(UUID memberId, UUID ptId, UUID slotId) {}
