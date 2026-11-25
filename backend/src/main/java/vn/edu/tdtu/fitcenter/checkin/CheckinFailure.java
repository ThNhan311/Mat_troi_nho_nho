package vn.edu.tdtu.fitcenter.checkin;

/** Reuses the existing sanitized error envelope / no-store handler. */
public final class CheckinFailure extends vn.edu.tdtu.fitcenter.membershipinitial.InitialActivationFailure {
    public CheckinFailure(int status,String code,String message) { super(status,code,message); }
}
