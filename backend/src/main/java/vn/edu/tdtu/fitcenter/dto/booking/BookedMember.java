package vn.edu.tdtu.fitcenter.dto.booking;

import java.util.UUID;

/** What a trainer may see about a member who booked them, to know and reach them. */
public record BookedMember(UUID memberId, String fullName, String phone, String gender) {}
