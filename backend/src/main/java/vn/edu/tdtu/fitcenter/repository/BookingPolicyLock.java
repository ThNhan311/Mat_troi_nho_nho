package vn.edu.tdtu.fitcenter.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** Database-scoped, transaction-scoped lock; works even before the first policy row exists. */
@Component
@RequiredArgsConstructor
@Transactional(propagation = Propagation.MANDATORY)
public class BookingPolicyLock {
    private final JdbcTemplate jdbc;

    public void read() { jdbc.execute("SELECT pg_advisory_xact_lock_shared(20261120,22)"); }
    public void write() { jdbc.execute("SELECT pg_advisory_xact_lock(20261120,22)"); }
}
