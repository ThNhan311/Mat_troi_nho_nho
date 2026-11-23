package vn.edu.tdtu.fitcenter.membershipinitial;
public class InitialActivationFailure extends RuntimeException {
 public final int status; public final String code;
 public InitialActivationFailure(int status,String code,String message){super(message);this.status=status;this.code=code;}
 public static InitialActivationFailure conflict(String code,String message){return new InitialActivationFailure(409,code,message);}
}
