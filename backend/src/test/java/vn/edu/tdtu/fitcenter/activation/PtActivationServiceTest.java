package vn.edu.tdtu.fitcenter.activation;
import org.junit.jupiter.api.*;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import java.time.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicReference;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class PtActivationServiceTest {
    private final ActivationStore store=mock(ActivationStore.class);
    private final ActivationMailer mail=mock(ActivationMailer.class);
    private final MutableClock clock=new MutableClock();
    private final BCryptPasswordEncoder encoder=new BCryptPasswordEncoder(4);
    private final PtActivationService service=new PtActivationService(store,mail,encoder,clock,true);
    private final UUID id=UUID.randomUUID();
    private final String email="pt-test@example.invalid";
    private final AtomicReference<ActivationStore.State> state=new AtomicReference<>();
    private final AtomicReference<String> delivered=new AtomicReference<>();
    @BeforeEach void setup(){
        when(store.findUser(email)).thenReturn(Optional.of(id));
        when(store.lockUser(id)).thenReturn(new ActivationStore.Account(id,email,"PT","DISABLED",true));
        when(store.lockState(id)).thenAnswer(i->state.get());
        doAnswer(i->{state.set(i.getArgument(0));return null;}).when(store).save(any());
        doAnswer(i->{delivered.set(i.getArgument(1));return null;}).when(mail).send(eq(email),anyString());
    }
    private String issued(){service.request(email);return delivered.get();}
    private ActivationFailure failure(Runnable action,String code){var e=assertThrows(ActivationFailure.class,action::run);assertEquals(code,e.getCode());return e;}
    @Test void defaultGateNeverTouchesDatabaseOrMail(){var disabled=new PtActivationService(store,mail,encoder,clock,false);failure(()->disabled.request(email),"ERR_ACTIVATION_NOT_READY");failure(()->disabled.verify(email,"000000"),"ERR_ACTIVATION_NOT_READY");failure(()->disabled.password("x","test-only-password"),"ERR_ACTIVATION_NOT_READY");verifyNoInteractions(store,mail);}
    @Test void generatesSixDigitCodeStoresOnlyBcryptExpiresInFiveMinutes(){var code=issued();assertTrue(code.matches("[0-9]{6}"));assertNotEquals(code,state.get().otpDigest);assertTrue(encoder.matches(code,state.get().otpDigest));assertEquals(clock.instant().plusSeconds(300),state.get().otpExpiresAt);assertNull(state.get().grantDigest);}
    @Test void resendCooldownEqualityAndOldCodeInvalidation(){String first=issued();clock.now=clock.now.plusSeconds(59);failure(()->service.request(email),"ERR_OTP_RESEND_TOO_SOON");clock.now=clock.now.plusSeconds(1);service.request(email);assertEquals(2,state.get().sendCount);assertNull(state.get().grantDigest);assertEquals(0,state.get().attempts);verify(mail,times(2)).send(eq(email),anyString());}
    @Test void limitsFiveSendsPerHourAndReopensAtBoundary(){for(int i=0;i<5;i++){service.request(email);clock.now=clock.now.plusSeconds(60);}failure(()->service.request(email),"ERR_OTP_SEND_LIMIT");clock.now=Instant.parse("2030-01-01T01:00:00Z");service.request(email);assertEquals(1,state.get().sendCount);}
    @Test void unknownEmailIsGenericAndNoMail(){when(store.findUser(email)).thenReturn(Optional.empty());service.request(email);verifyNoInteractions(mail);verify(store,never()).lockUser(any());}
    @ParameterizedTest @ValueSource(strings={"MEMBER","ADMIN","ACTIVE","SUSPENDED","LEGACY"})
    void noMemberFlowOrReactivation(String value){String role=Set.of("MEMBER","ADMIN").contains(value)?value:"PT";String status=Set.of("ACTIVE","SUSPENDED").contains(value)?value:"DISABLED";when(store.lockUser(id)).thenReturn(new ActivationStore.Account(id,email,role,status,!value.equals("LEGACY")));service.request(email);verifyNoInteractions(mail);failure(()->service.verify(email,"000000"),"ERR_ACTIVATION_INVALID");}
    @Test void failedAttemptsCountAndSixthCannotMatchEvenCorrectCode(){String actual=issued();String wrong=actual.equals("000000")?"999999":"000000";for(int i=0;i<5;i++)failure(()->service.verify(email,wrong),"ERR_ACTIVATION_INVALID");assertEquals(5,state.get().attempts);failure(()->service.verify(email,actual),"ERR_OTP_ATTEMPT_LIMIT");}
    @ParameterizedTest @ValueSource(longs={300,301})
    void expiresAtAndAfterBoundary(long seconds){String otp=issued();clock.now=clock.now.plusSeconds(seconds);failure(()->service.verify(email,otp),"ERR_OTP_EXPIRED");}
    @Test void justBeforeExpiryAllowedAndOtpCannotVerifyAgain(){String otp=issued();clock.now=clock.now.plusSeconds(299);String grant=service.verify(email,otp);assertEquals(43,grant.length());assertNotEquals(grant,state.get().grantDigest);assertEquals(PtActivationService.digest(grant),state.get().grantDigest);assertNull(state.get().otpDigest);failure(()->service.verify(email,otp),"ERR_OTP_ALREADY_USED");}
    @Test void newCodeInvalidatesAlreadyVerifiedGrant(){String otp=issued();String grant=service.verify(email,otp);clock.now=clock.now.plusSeconds(60);service.request(email);assertNull(state.get().grantDigest);assertNotNull(state.get().otpDigest);when(store.findGrant(PtActivationService.digest(grant))).thenReturn(Optional.empty());failure(()->service.password(grant,"test-only-password"),"ERR_ACTIVATION_INVALID");}
    @Test void passwordRequiresGrantThenAtomicActivationAndConsumption(){failure(()->service.password("x","test-only-password"),"ERR_ACTIVATION_INVALID");String grant=service.verify(email,issued());when(store.findGrant(PtActivationService.digest(grant))).thenReturn(Optional.of(id));service.password(grant,"test-only-password");assertNotNull(state.get().completedAt);assertNull(state.get().grantDigest);var order=inOrder(store);order.verify(store).findGrant(PtActivationService.digest("x"));order.verify(store).findUser(email);order.verify(store).lockUser(id);order.verify(store).lockState(id);order.verify(store).save(any());order.verify(store).findUser(email);order.verify(store).lockUser(id);order.verify(store).lockState(id);order.verify(store).save(any());order.verify(store).findGrant(PtActivationService.digest(grant));order.verify(store).lockUser(id);order.verify(store).lockState(id);order.verify(store).activate(eq(id),argThat(h->encoder.matches("test-only-password",h)));order.verify(store).save(any());failure(()->service.password(grant,"test-only-password"),"ERR_ACTIVATION_INVALID");verify(store,times(1)).activate(eq(id),anyString());}
    @Test void expiredGrantDoesNotActivate(){String grant=service.verify(email,issued());when(store.findGrant(PtActivationService.digest(grant))).thenReturn(Optional.of(id));clock.now=clock.now.plusSeconds(300);failure(()->service.password(grant,"test-only-password"),"ERR_ACTIVATION_INVALID");verify(store,never()).activate(any(),anyString());}
    @ParameterizedTest @ValueSource(strings={"", "short", "                                                                  ", "ééééééééééééééééééééééééééééééééééééé"})
    void passwordValidationNoBcryptTruncation(String password){failure(()->service.password("x",password),"ERR_VALIDATION");verify(store,never()).activate(any(),anyString());}
    @Test void clockSampledAfterWaitingForUserAndStateLocks(){String otp=issued();doAnswer(i->{clock.now=clock.now.plusSeconds(300);return state.get();}).when(store).lockState(id);failure(()->service.verify(email,otp),"ERR_OTP_EXPIRED");}
    @Test void completedOrRevokedAccountCannotActivate(){String otp=issued();when(store.lockUser(id)).thenReturn(new ActivationStore.Account(id,email,"PT","DISABLED",false));failure(()->service.verify(email,otp),"ERR_ACTIVATION_INVALID");verify(store,never()).activate(any(),anyString());}
    static final class MutableClock extends Clock {
        Instant now=Instant.parse("2030-01-01T00:00:00Z");
        @Override public ZoneId getZone(){return ZoneOffset.UTC;} @Override public Clock withZone(ZoneId z){return this;} @Override public Instant instant(){return now;}
    }
}