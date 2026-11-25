package vn.edu.tdtu.fitcenter.activation;
import org.junit.jupiter.api.*;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.jdbc.core.JdbcTemplate;
import javax.sql.DataSource;
import java.sql.*;
import java.math.BigDecimal;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
class MemberActivationGuardTest {
 @Test void defaultOffDoesNotConnect(){var ds=mock(DataSource.class);new MemberActivationSchemaGuard(false,new MockEnvironment(),ds,mock(JdbcTemplate.class)).afterPropertiesSet();verifyNoInteractions(ds);}
 @Test void cannotEnableOutsideRehearsal(){assertThrows(IllegalStateException.class,()->new MemberActivationSchemaGuard(true,new MockEnvironment(),mock(DataSource.class),mock(JdbcTemplate.class)).afterPropertiesSet());}
 @Test void missingGuardRefusesBeforeConnection(){var ds=mock(DataSource.class);assertThrows(IllegalStateException.class,()->AccountIntegrationRehearsalConfiguration.verify(ds,false));verifyNoInteractions(ds);}
 @ParameterizedTest @ValueSource(strings={"jdbc:postgresql://example.com:15441/fitcenter_account_abcdef123456_history_test","jdbc:postgresql://127.0.0.1:5432/fitcenter_account_abcdef123456_history_test","jdbc:postgresql://127.0.0.1:15441/production","jdbc:postgresql://127.0.0.1:15439/fitcenter_activation_abcdef123456_history_test"})
 void rejectsWrongDatasource(String url)throws Exception{var ds=mock(DataSource.class);var c=mock(Connection.class);var md=mock(DatabaseMetaData.class);when(ds.getConnection()).thenReturn(c);when(c.getMetaData()).thenReturn(md);when(md.getURL()).thenReturn(url);assertThrows(IllegalStateException.class,()->AccountIntegrationRehearsalConfiguration.verify(ds,true));}
}
