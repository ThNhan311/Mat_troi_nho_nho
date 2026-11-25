package vn.edu.tdtu.fitcenter.activation;
/** Closed allow-list: never use a role/table supplied by an HTTP client. */
enum ActivationRole {
 PT("pt_account_activation","personal_trainers","PT_ACCOUNT_ACTIVATED"),
 MEMBER("member_account_activation","members","MEMBER_ACCOUNT_ACTIVATED");
 final String table,profile,event;
 ActivationRole(String table,String profile,String event){this.table=table;this.profile=profile;this.event=event;}
}
