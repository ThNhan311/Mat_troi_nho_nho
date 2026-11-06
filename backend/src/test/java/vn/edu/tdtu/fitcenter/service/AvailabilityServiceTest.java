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
import vn.edu.tdtu.fitcenter.domain.entity.AvailabilitySlot;
import vn.edu.tdtu.fitcenter.domain.entity.PersonalTrainer;
import vn.edu.tdtu.fitcenter.domain.entity.User;
import vn.edu.tdtu.fitcenter.domain.enums.AccountStatus;
import vn.edu.tdtu.fitcenter.domain.enums.Role;
import vn.edu.tdtu.fitcenter.domain.enums.SlotStatus;
import vn.edu.tdtu.fitcenter.repository.AvailabilitySlotRepository;
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
class AvailabilityServiceTest {
    private static final String EMAIL = "pt@example.test";
    private static final OffsetDateTime FROM = OffsetDateTime.parse("2020-01-01T00:00:00+07:00");
    private static final OffsetDateTime TO = FROM.plusDays(1);

    @Mock UserRepository users;
    @Mock PersonalTrainerRepository trainers;
    @Mock AvailabilitySlotRepository slots;
    @InjectMocks AvailabilityService service;

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

    private AvailabilitySlot slot(SlotStatus status, int hour) {
        return AvailabilitySlot.builder().id(UUID.randomUUID()).personalTrainer(trainer)
                .startAt(FROM.plusHours(hour)).endAt(FROM.plusHours(hour + 1))
                .status(status).version(0L).build();
    }

    @Test
    void noStatusUsesTrainerProfileIdAndPreservesAllStatusesAndPastSlots() {
        mockTrainer();
        var records = List.of(slot(SlotStatus.AVAILABLE, 0), slot(SlotStatus.BOOKED, 1),
                slot(SlotStatus.DISABLED, 2));
        when(slots.findByPersonalTrainerIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO)).thenReturn(records);

        var result = service.getMySlots(EMAIL, FROM, TO, null);

        assertEquals(List.of("AVAILABLE", "BOOKED", "DISABLED"),
                result.stream().map(r -> r.status()).toList());
        assertEquals(records.stream().map(AvailabilitySlot::getStartAt).toList(),
                result.stream().map(r -> r.startAt()).toList());
        assertEquals(records.getFirst().getId(), result.getFirst().id());
        assertEquals(records.getFirst().getEndAt(), result.getFirst().endAt());
        assertTrue(result.stream().allMatch(r -> r.ptId().equals(trainer.getId())));
        verify(slots).findByPersonalTrainerIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO);
        verifyNoMoreInteractions(slots);
    }

    @ParameterizedTest
    @EnumSource(SlotStatus.class)
    void statusFilterIsDelegatedWithTheProfileIdAndExactTimeBounds(SlotStatus status) {
        mockTrainer();
        when(slots.findByPersonalTrainerIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), status, FROM, TO)).thenReturn(List.of(slot(status, 0)));

        var result = service.getMySlots(EMAIL, FROM, TO, status);

        assertEquals(1, result.size());
        assertEquals(status.name(), result.getFirst().status());
        verify(slots).findByPersonalTrainerIdAndStatusAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), status, FROM, TO);
        verifyNoMoreInteractions(slots);
    }

    static Stream<Arguments> invalidRanges() {
        return Stream.of(Arguments.of(null, TO), Arguments.of(FROM, null),
                Arguments.of(TO, FROM), Arguments.of(FROM, FROM),
                Arguments.of(FROM, OffsetDateTime.parse("2019-12-31T17:00:00Z")));
    }

    @ParameterizedTest
    @MethodSource("invalidRanges")
    void invalidRangesFailBeforeAnyRepositoryAccess(OffsetDateTime from, OffsetDateTime to) {
        var error = assertThrows(ResponseStatusException.class,
                () -> service.getMySlots(EMAIL, from, to, null));
        assertEquals(HttpStatus.BAD_REQUEST, error.getStatusCode());
        verifyNoInteractions(users, trainers, slots);
    }

    @Test
    void noSlotsReturnsAnEmptyList() {
        mockTrainer();
        when(slots.findByPersonalTrainerIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                trainer.getId(), FROM, TO)).thenReturn(List.of());
        assertEquals(List.of(), service.getMySlots(EMAIL, FROM, TO, null));
    }

    @Test
    void missingTrainerProfileReturns404WithoutReadingSlots() {
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.of(user));
        when(trainers.findByUser_Id(user.getId())).thenReturn(Optional.empty());
        var error = assertThrows(ResponseStatusException.class,
                () -> service.getMySlots(EMAIL, FROM, TO, null));
        assertEquals(HttpStatus.NOT_FOUND, error.getStatusCode());
        verifyNoInteractions(slots);
    }

    @Test
    void missingPrincipalUserFailsAuthentication() {
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.empty());
        assertThrows(BadCredentialsException.class, () -> service.getMySlots(EMAIL, FROM, TO, null));
        verifyNoInteractions(trainers, slots);
    }

    @ParameterizedTest
    @EnumSource(value = Role.class, names = {"MEMBER", "ADMIN"})
    void nonPtCannotAccessSlotsEvenWhenServiceIsCalledDirectly(Role role) {
        user.setRole(role);
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.of(user));
        assertThrows(AccessDeniedException.class, () -> service.getMySlots(EMAIL, FROM, TO, null));
        verifyNoInteractions(trainers, slots);
    }

    @ParameterizedTest
    @EnumSource(value = AccountStatus.class, names = {"SUSPENDED", "DISABLED"})
    void inactiveUserCannotReadSlots(AccountStatus status) {
        user.setStatus(status);
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.of(user));
        assertThrows(AccessDeniedException.class, () -> service.getMySlots(EMAIL, FROM, TO, null));
        verifyNoInteractions(trainers, slots);
    }
}
