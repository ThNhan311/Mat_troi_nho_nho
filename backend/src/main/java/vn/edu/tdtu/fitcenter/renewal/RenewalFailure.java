package vn.edu.tdtu.fitcenter.renewal;
/** Uses the existing error envelope and no-store handler, with independent stable codes. */
public class RenewalFailure extends vn.edu.tdtu.fitcenter.membershipinitial.InitialActivationFailure {
 public RenewalFailure(int status,String code,String message){super(status,code,message);}
 public static RenewalFailure conflict(String code,String message){return new RenewalFailure(409,code,message);}
}
