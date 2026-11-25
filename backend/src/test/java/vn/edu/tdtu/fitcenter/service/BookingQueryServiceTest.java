package vn.edu.tdtu.fitcenter.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.MethodSource;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.server.ResponseStatusException;
import vn.edu.tdtu.fitcenter.domain.entity.Booking;
import vn.edu.tdtu.fitcenter.domain.entity.Member;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.BookingStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.dto.booking.BookingResponse;
import vn.edu.tdtu.fitcenter.repository.BookingRepository;
import vn.edu.tdtu.fitcenter.repository.MemberRepository;
import vn.edu.tdtu.fitcenter.repository.PersonalTrainerRepository;
import vn.edu.tdtu.fitcenter.repository.UserRepository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class BookingQueryServiceTest {
    private static final String EMAIL = "member@example.test";
    private static final OffsetDateTime FROM = OffsetDateTime.parse("2020-01-01T00:00:00+07:00");
    private static final OffsetDateTime TO = FROM.plusDays(1);

    @Mock UserRepository users;
    @Mock MemberRepository members;
    @Mock BookingRepository bookings;
    @Mock PersonalTrainerRepository trainers;
    @InjectMocks BookingQueryService service;

    private User user;
    private Member member;

    @BeforeEach
    void setUp() {
        user = User.builder().id(UUID.randomUUID()).email(EMAIL)
                .role(Role.MEMBER).status(AccountStatus.ACTIVE).build();
        member = Member.builder().id(UUID.randomUUID()).user(user).build();
    }

    private void mockMember() {
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.of(user));
        when(members.findByUser_Id(user.getId())).thenReturn(Optional.of(member));
    }

    private Booking booking(BookingStatus status, int hour) {
        return Booking.builder().id(UUID.randomUUID()).memberId(member.getId())
                .ptId(UUID.randomUUID()).slotId(UUID.randomUUID())
                .startAt(FROM.plusHours(hour)).endAt(FROM.plusHours(hour + 1)).status(status).build();
    }

    @Test
    void allStatusesAndPastBookingsAreReturnedUsingMemberProfileId() {
        mockMember();
        var records = List.of(booking(BookingStatus.CONFIRMED, 0),
                booking(BookingStatus.CANCELLED, 1), booking(BookingStatus.COMPLETED, 2));
        when(bookings.findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), FROM, TO)).thenReturn(records);

        var result = service.getMyBookings(EMAIL, FROM, TO, null);

        assertNotEquals(user.getId(), member.getId());
        assertEquals(List.of("CONFIRMED", "CANCELLED", "COMPLETED"),
                result.stream().map(BookingResponse::status).toList());
        assertEquals(records.stream().map(Booking::getStartAt).toList(),
                result.stream().map(BookingResponse::startAt).toList());
        assertEquals(FROM, result.getFirst().startAt());
        assertTrue(result.stream().allMatch(r -> member.getId().equals(r.memberId())));
        verify(bookings).findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), FROM, TO);
        verifyNoMoreInteractions(bookings);
    }

    @ParameterizedTest
    @EnumSource(BookingStatus.class)
    void statusFilterAndExactBoundsAreDelegatedToRepository(BookingStatus status) {
        mockMember();
        when(bookings.findByMemberIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), status, FROM, TO)).thenReturn(List.of(booking(status, 0)));
        var result = service.getMyBookings(EMAIL, FROM, TO, status);
        assertEquals(1, result.size());
        assertEquals(status.name(), result.getFirst().status());
        verify(bookings).findByMemberIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), status, FROM, TO);
        verifyNoMoreInteractions(bookings);
    }

    @Test
    void cancellationMetadataIsMappedToTheExistingSchemaFields() {
        mockMember();
        Booking record = booking(BookingStatus.CANCELLED, 1);
        record.setCancelledBy("PT");
        record.setCancelReason("Schedule conflict");
        record.setCancelledAt(FROM.minusDays(1));
        when(bookings.findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), FROM, TO)).thenReturn(List.of(record));

        assertEquals(new BookingResponse(record.getId(), member.getId(), record.getPtId(),
                        record.getSlotId(), record.getStartAt(), record.getEndAt(), "CANCELLED",
                        "PT", "Schedule conflict", record.getCancelledAt(), null),
                service.getMyBookings(EMAIL, FROM, TO, null).getFirst());
    }

    @Test
    void completionMetadataAndNullCancellationFieldsArePreserved() {
        mockMember();
        Booking record = booking(BookingStatus.COMPLETED, 2);
        record.setCompletedAt(record.getEndAt());
        when(bookings.findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), FROM, TO)).thenReturn(List.of(record));
        var response = service.getMyBookings(EMAIL, FROM, TO, null).getFirst();
        assertEquals(record.getCompletedAt(), response.completedAt());
        assertNull(response.cancelledBy());
        assertNull(response.cancelReason());
        assertNull(response.cancelledAt());
    }

    static Stream<Arguments> invalidRanges() {
        return Stream.of(Arguments.of(null, TO), Arguments.of(FROM, null),
                Arguments.of(TO, FROM), Arguments.of(FROM, FROM),
                Arguments.of(FROM, OffsetDateTime.parse("2019-12-31T17:00:00Z")));
    }

    @ParameterizedTest
    @MethodSource("invalidRanges")
    void invalidRangesReturn400BeforeReadingRepositories(OffsetDateTime from, OffsetDateTime to) {
        var error = assertThrows(ResponseStatusException.class,
                () -> service.getMyBookings(EMAIL, from, to, null));
        assertEquals(HttpStatus.BAD_REQUEST, error.getStatusCode());
        verifyNoInteractions(users, members, bookings);
    }

    @Test
    void noBookingsReturnsAnEmptyList() {
        mockMember();
        when(bookings.findByMemberIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                member.getId(), FROM, TO)).thenReturn(List.of());
        assertEquals(List.of(), service.getMyBookings(EMAIL, FROM, TO, null));
    }

    @Test
    void missingMemberProfileReturns404() {
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.of(user));
        when(members.findByUser_Id(user.getId())).thenReturn(Optional.empty());
        var error = assertThrows(ResponseStatusException.class,
                () -> service.getMyBookings(EMAIL, FROM, TO, null));
        assertEquals(HttpStatus.NOT_FOUND, error.getStatusCode());
        verifyNoInteractions(bookings);
    }

    @Test
    void missingUserFailsAuthentication() {
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.empty());
        assertThrows(BadCredentialsException.class,
                () -> service.getMyBookings(EMAIL, FROM, TO, null));
        verifyNoInteractions(members, bookings);
    }

    @ParameterizedTest
    @EnumSource(value = Role.class, names = {"PT", "ADMIN"})
    void nonMemberIsRejectedEvenWhenServiceIsCalledDirectly(Role role) {
        user.setRole(role);
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.of(user));
        assertThrows(AccessDeniedException.class, () -> service.getMyBookings(EMAIL, FROM, TO, null));
        verifyNoInteractions(members, bookings);
    }

    @ParameterizedTest
    @EnumSource(value = AccountStatus.class, names = {"SUSPENDED", "DISABLED"})
    void inactiveUserIsRejected(AccountStatus status) {
        user.setStatus(status);
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.of(user));
        assertThrows(AccessDeniedException.class, () -> service.getMyBookings(EMAIL, FROM, TO, null));
        verifyNoInteractions(members, bookings);
    }
}
