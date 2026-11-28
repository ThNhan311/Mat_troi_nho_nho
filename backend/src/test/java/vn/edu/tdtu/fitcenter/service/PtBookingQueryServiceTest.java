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
import vn.edu.tdtu.fitcenter.domain.entity.PersonalTrainer;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.BookingStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.dto.booking.BookedMember;
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
class PtBookingQueryServiceTest {
    private static final String EMAIL = "pt@example.test";
    private static final OffsetDateTime FROM = OffsetDateTime.parse("2020-01-01T00:00:00+07:00");
    private static final OffsetDateTime TO = FROM.plusDays(1);

    @Mock UserRepository users;
    @Mock MemberRepository members;
    @Mock PersonalTrainerRepository trainers;
    @Mock BookingRepository bookings;
    @InjectMocks BookingQueryService service;

    private User user;
    private PersonalTrainer trainer;

    @BeforeEach
    void setUp() {
        user = User.builder().id(UUID.randomUUID()).email(EMAIL)
                .role(Role.PT).status(AccountStatus.ACTIVE).build();
        trainer = PersonalTrainer.builder().id(UUID.randomUUID()).user(user).build();
    }

    private void mockTrainer() {
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.of(user));
        when(trainers.findByUser_Id(user.getId())).thenReturn(Optional.of(trainer));
    }

    private Booking booking(BookingStatus status, int hour) {
        Booking record = Booking.builder().id(UUID.randomUUID()).ptId(trainer.getId())
                .memberId(UUID.randomUUID()).slotId(UUID.randomUUID()).status(status)
                .startAt(FROM.plusHours(hour)).endAt(FROM.plusHours(hour + 1)).build();
        if (status == BookingStatus.CANCELLED) {
            record.setCancelledBy("MEMBER");
            record.setCancelReason("Schedule conflict");
            record.setCancelledAt(FROM.minusDays(1));
        } else if (status == BookingStatus.COMPLETED) {
            record.setCompletedAt(record.getEndAt());
        }
        return record;
    }

    @Test
    void bookedMemberNamesAreAskedForTheSignedInTrainerOnly() {
        mockTrainer();
        var named = List.of(new BookedMember(UUID.randomUUID(), "Member A", "0901234567", "FEMALE"));
        when(members.findBookedWith(trainer.getId())).thenReturn(named);

        assertEquals(named, service.getMyBookedMembers(EMAIL));
        verify(members).findBookedWith(trainer.getId());
        verifyNoMoreInteractions(members);
    }

    @ParameterizedTest
    @EnumSource(value = Role.class, names = "PT", mode = EnumSource.Mode.EXCLUDE)
    void otherRolesGetNoMemberNames(Role role) {
        user.setRole(role);
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.of(user));

        assertThrows(AccessDeniedException.class, () -> service.getMyBookedMembers(EMAIL));
        verifyNoInteractions(members);
    }

    @Test
    void allStatusesAndPastBookingsUseTrainerProfileIdAndExistingDto() {
        mockTrainer();
        var records = List.of(booking(BookingStatus.CONFIRMED, 0),
                booking(BookingStatus.CANCELLED, 1), booking(BookingStatus.COMPLETED, 2));
        when(bookings.findByPtIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO)).thenReturn(records);

        var result = service.getMyPtBookings(EMAIL, FROM, TO, null);

        assertNotEquals(user.getId(), trainer.getId());
        assertEquals(List.of("CONFIRMED", "CANCELLED", "COMPLETED"),
                result.stream().map(BookingResponse::status).toList());
        assertEquals(records.stream().map(Booking::getStartAt).toList(),
                result.stream().map(BookingResponse::startAt).toList());
        assertEquals(FROM, result.getFirst().startAt());
        assertTrue(result.stream().allMatch(r -> trainer.getId().equals(r.ptId())));
        Booking cancelled = records.get(1);
        assertEquals(new BookingResponse(cancelled.getId(), cancelled.getMemberId(), trainer.getId(),
                        cancelled.getSlotId(), cancelled.getStartAt(), cancelled.getEndAt(), "CANCELLED",
                        "MEMBER", "Schedule conflict", cancelled.getCancelledAt(), null), result.get(1));
        assertEquals(records.get(2).getCompletedAt(), result.get(2).completedAt());
        verify(bookings).findByPtIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO);
        verifyNoMoreInteractions(bookings);
        verifyNoInteractions(members);
    }

    @ParameterizedTest
    @EnumSource(BookingStatus.class)
    void delegatesStatusAndExactTimeBoundsUsingTrainerId(BookingStatus status) {
        mockTrainer();
        when(bookings.findByPtIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), status, FROM, TO)).thenReturn(List.of(booking(status, 0)));
        var result = service.getMyPtBookings(EMAIL, FROM, TO, status);
        assertEquals(1, result.size());
        assertEquals(status.name(), result.getFirst().status());
        verify(bookings).findByPtIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), status, FROM, TO);
        verifyNoMoreInteractions(bookings);
        verifyNoInteractions(members);
    }

    static Stream<Arguments> invalidRanges() {
        return Stream.of(Arguments.of(null, TO), Arguments.of(FROM, null), Arguments.of(TO, FROM),
                Arguments.of(FROM, FROM), Arguments.of(FROM, OffsetDateTime.parse("2019-12-31T17:00:00Z")));
    }

    @ParameterizedTest
    @MethodSource("invalidRanges")
    void invalidRangesFailBeforeAnyRepositoryAccess(OffsetDateTime from, OffsetDateTime to) {
        var error = assertThrows(ResponseStatusException.class,
                () -> service.getMyPtBookings(EMAIL, from, to, null));
        assertEquals(HttpStatus.BAD_REQUEST, error.getStatusCode());
        verifyNoInteractions(users, members, trainers, bookings);
    }

    @Test
    void noBookingsReturnsAnEmptyList() {
        mockTrainer();
        when(bookings.findByPtIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO)).thenReturn(List.of());
        assertEquals(List.of(), service.getMyPtBookings(EMAIL, FROM, TO, null));
    }

    @Test
    void missingProfileReturns404WithoutReadingBookings() {
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.of(user));
        when(trainers.findByUser_Id(user.getId())).thenReturn(Optional.empty());
        var error = assertThrows(ResponseStatusException.class,
                () -> service.getMyPtBookings(EMAIL, FROM, TO, null));
        assertEquals(HttpStatus.NOT_FOUND, error.getStatusCode());
        verifyNoInteractions(members, bookings);
    }

    @Test
    void missingUserFailsAuthentication() {
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.empty());
        assertThrows(BadCredentialsException.class, () -> service.getMyPtBookings(EMAIL, FROM, TO, null));
        verifyNoInteractions(members, trainers, bookings);
    }

    @ParameterizedTest
    @EnumSource(value = Role.class, names = {"MEMBER", "ADMIN"})
    void otherRolesCannotReadPtHistoryThroughTheService(Role role) {
        user.setRole(role);
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.of(user));
        assertThrows(AccessDeniedException.class, () -> service.getMyPtBookings(EMAIL, FROM, TO, null));
        verifyNoInteractions(members, trainers, bookings);
    }

    @ParameterizedTest
    @EnumSource(value = AccountStatus.class, names = {"SUSPENDED", "DISABLED"})
    void inactiveUsersCannotReadHistory(AccountStatus status) {
        user.setStatus(status);
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.of(user));
        assertThrows(AccessDeniedException.class, () -> service.getMyPtBookings(EMAIL, FROM, TO, null));
        verifyNoInteractions(members, trainers, bookings);
    }
}
