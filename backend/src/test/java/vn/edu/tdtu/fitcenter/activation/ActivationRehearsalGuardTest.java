package vn.edu.tdtu.fitcenter.activation;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import javax.sql.DataSource;
import java.sql.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
class ActivationRehearsalGuardTest {
    @Test void defaultDisabledDoesNotTouchDatabase(){var j=mock(JdbcTemplate.class);new ActivationSchemaGuard(false,false,j).afterPropertiesSet();verifyNoInteractions(j);}
    @Test void productionActivationIsRejectedBeforeDatabaseAccess(){var j=mock(JdbcTemplate.class);assertThrows(IllegalStateException.class,()->new ActivationSchemaGuard(true,false,j).afterPropertiesSet());verifyNoInteractions(j);}
    @Test void enabledRehearsalNeedsTable(){var j=mock(JdbcTemplate.class);when(j.queryForObject(anyString(),eq(Boolean.class))).thenReturn(false);assertThrows(IllegalStateException.class,()->new ActivationSchemaGuard(true,true,j).afterPropertiesSet());}
    @Test void enabledRehearsalAcceptsAppliedTable(){var j=mock(JdbcTemplate.class);when(j.queryForObject(anyString(),eq(Boolean.class))).thenReturn(true);assertDoesNotThrow(()->new ActivationSchemaGuard(true,true,j).afterPropertiesSet());}
    @Test void missingRunnerFlagDoesNotOpenConnection(){var d=mock(DataSource.class);assertThrows(IllegalStateException.class,()->ActivationRehearsalConfiguration.verify(d,false));verifyNoInteractions(d);}
    private DataSource source(String url,String user,boolean privileged) throws Exception {
        var d=mock(DataSource.class);var c=mock(Connection.class);var m=mock(DatabaseMetaData.class);var s=mock(Statement.class);var r=mock(ResultSet.class);when(d.getConnection()).thenReturn(c);when(c.getMetaData()).thenReturn(m);when(m.getURL()).thenReturn(url);when(c.createStatement()).thenReturn(s);when(s.executeQuery(anyString())).thenReturn(r);when(r.next()).thenReturn(true);when(r.getString(1)).thenReturn("fitcenter_activation_abcdef012345_history_test");when(r.getString(2)).thenReturn(user);when(r.getBoolean(3)).thenReturn(privileged);return d;
    }
    @Test void sharedPortRejected() throws Exception {var d=source("jdbc:postgresql://127.0.0.1:5432/fitcenter","fitcenter_activation_app",false);assertThrows(IllegalStateException.class,()->ActivationRehearsalConfiguration.verify(d,true));}
    @Test void privilegedRoleRejected() throws Exception {var d=source("jdbc:postgresql://127.0.0.1:15439/fitcenter_activation_abcdef012345_history_test","fitcenter_activation_app",true);assertThrows(IllegalStateException.class,()->ActivationRehearsalConfiguration.verify(d,true));}
    @Test void differentAppRoleRejected() throws Exception {var d=source("jdbc:postgresql://127.0.0.1:15439/fitcenter_activation_abcdef012345_history_test","postgres",false);assertThrows(IllegalStateException.class,()->ActivationRehearsalConfiguration.verify(d,true));}
    @Test void dedicatedTargetAcceptsDriverUrlEmptyQuerySuffix() throws Exception {var d=source("jdbc:postgresql://127.0.0.1:15439/fitcenter_activation_abcdef012345_history_test?","fitcenter_activation_app",false);assertDoesNotThrow(()->ActivationRehearsalConfiguration.verify(d,true));}
}
