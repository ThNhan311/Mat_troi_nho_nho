import java.nio.file.*;
import java.sql.*;
import java.util.*;
import org.postgresql.ds.PGSimpleDataSource;

/** Local synthetic fixture maintenance only; never starts Flyway or changes credentials. */
class SetLocalDemoAliases {
    static Map<String,String> snapshot(Connection connection) throws Exception {
        var tables = new ArrayList<String>();
        try (var s = connection.createStatement(); var rows = s.executeQuery(
                "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename")) {
            while (rows.next()) tables.add(rows.getString(1));
        }
        var result = new TreeMap<String,String>();
        for (String table : tables) {
            if (!table.matches("[a-z_]+")) throw new IllegalStateException("Unexpected table");
            String row = table.equals("users") ? "to_jsonb(t)-'email'-'updated_at'" : "to_jsonb(t)";
            try (var s = connection.createStatement(); var rows = s.executeQuery(
                    "SELECT coalesce(jsonb_agg(j ORDER BY j::text),'[]'::jsonb)::text FROM "
                    + "(SELECT " + row + " j FROM " + table + " t)x")) {
                rows.next(); result.put(table, rows.getString(1));
            }
        }
        return result;
    }
    static void run(Path file) throws Exception {
        var input = new Properties();
        try (var stream = Files.newInputStream(file)) { input.load(stream); }
        String database = input.getProperty("database", "");
        if (!database.matches("fitcenter_account_[a-f0-9]{12}_history_test"))
            throw new IllegalStateException("Dedicated history database required");
        var source = new PGSimpleDataSource();
        source.setURL("jdbc:postgresql://127.0.0.1:15441/" + database);
        source.setUser("fitcenter_account_app"); source.setPassword(System.getenv("DB_PASSWORD"));
        try (var connection = source.getConnection()) {
            connection.setTransactionIsolation(Connection.TRANSACTION_REPEATABLE_READ);
            connection.setAutoCommit(false);
            try {
                try (var s = connection.createStatement(); var rows = s.executeQuery(
                        "SELECT current_database(),current_user,rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls "
                        + "FROM pg_roles WHERE rolname=current_user")) {
                    if (!rows.next() || !database.equals(rows.getString(1))
                            || !"fitcenter_account_app".equals(rows.getString(2)) || rows.getBoolean(3))
                        throw new IllegalStateException("Database identity/role mismatch");
                }
                try (var s = connection.createStatement(); var rows = s.executeQuery(
                        "SELECT string_agg(version,',' ORDER BY installed_rank) FROM flyway_schema_history WHERE success")) {
                    rows.next();
                    if (!"1,2,3,4,5,6,8,9,10,11,12,13".equals(rows.getString(1)))
                        throw new IllegalStateException("Unexpected migration history");
                }
                var before = snapshot(connection);
                var seenIds = new HashSet<UUID>(); var seenEmails = new HashSet<String>();
                // Lock all fixture users in UUID order; writers in this helper use the same order.
                var order = new ArrayList<Integer>();
                for (int i = 0; i < 5; i++) order.add(i);
                order.sort(Comparator.comparing(i -> input.getProperty("user." + i + ".id")));
                for (int i : order) {
                    UUID id = UUID.fromString(input.getProperty("user." + i + ".id"));
                    String oldEmail = input.getProperty("user." + i + ".email");
                    String alias = input.getProperty("user." + i + ".alias");
                    String role = input.getProperty("user." + i + ".role");
                    if (!seenIds.add(id) || !seenEmails.add(alias)
                            || !Set.of("admin@example.test", "membera@example.test", "memberb@example.test",
                                       "pta@example.test", "ptb@example.test").contains(alias))
                        throw new IllegalStateException("Invalid fixture mapping");
                    try (var q = connection.prepareStatement("SELECT email,role,status FROM users WHERE id=? FOR UPDATE")) {
                        q.setObject(1,id);
                        try (var rows = q.executeQuery()) {
                            if (!rows.next() || !oldEmail.equals(rows.getString(1))
                                    || !role.equals(rows.getString(2)) || !"ACTIVE".equals(rows.getString(3)))
                                throw new IllegalStateException("Fixture identity/status changed");
                        }
                    }
                    try (var q = connection.prepareStatement("UPDATE users SET email=? WHERE id=?")) {
                        q.setString(1,alias); q.setObject(2,id);
                        if (q.executeUpdate()!=1) throw new IllegalStateException("Wrong affected row count");
                    }
                }
                if (!before.equals(snapshot(connection)))
                    throw new IllegalStateException("Business data/password changed; rollback");
                connection.commit();
                System.out.println("Five demo aliases committed; password hashes and business snapshot preserved");
            } catch (Exception error) { connection.rollback(); throw error; }
        }
    }
    public static void main(String[] args) throws Exception {
        try { run(Path.of(args[0])); }
        catch (SQLException error) {
            // Never expose parameter values, JDBC credential or PostgreSQL detail through logs.
            throw new IllegalStateException("Alias update rolled back; SQLSTATE=" + error.getSQLState());
        }
    }
}