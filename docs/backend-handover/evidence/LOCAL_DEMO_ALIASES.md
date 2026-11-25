# Local demo account aliases — 25/11/2026

Base main: `5259f51c967994c85dcd0ff54512d15ce0e52c9e`, branch `chore/local-demo-account-aliases`. Only the two maintenance helpers below are executable changes. Application Backend, Flutter, migrations and default gates are unchanged. The running server/Web builds use merged main; this report is **not** CI or a rerun of the historical full suite.

## Source tested (SHA-256, UTF-8 working-tree bytes)

| Source | SHA-256 |
|---|---|
| `backend/scripts/Set-LocalDemoAliases.ps1` | `d7f8e6c0c742d86edb3560487ad46adb11340cb1b8baa6454819ff73245515c4` |
| `backend/scripts/SetLocalDemoAliases.java` | `f34d673b30a8493a17e21a1f4779d3ae37be2ab0d403206e1f50a919643bf4d1` |

## Actual checks

- Focused helper checks: **4 passed, 0 failed, 0 skipped** — PowerShell parser; wrong full container ID rejected before SQL; rollback after first row UPDATE when the second locked row fails identity validation; repeat execution with aliases already set.
- HTTP login: **5 passed, 0 failed** in the final helper run, covering Admin, two Members and two PTs with exact expected roles. The earlier run is not added to this count.
- Real original Web UI login: **3 passed, 0 failed**, covering Admin3002, Member3000, PT3001. Headless Chrome158 with Playwright; actual form submission and Backend200/role asserted. This checks alias compatibility with unchanged form validation, not the full Booking/Membership flow.
- PostgreSQL17.12 private guarded scope: full-ID/context/image/volume/run/role/history verified; transaction snapshot compared every public table, excluding only users.email/updated_at. Password hashes, account status/profile UUIDs, Memberships/payment/receipts/periods, availability and any booking rows remained unchanged. The rollback check compared complete User rows, including updated_at/password hash, before/after the rejected transaction.
- Private manifests/handoff updated using the same account UUIDs; no new business fixture was seeded, no schema/DDL/Flyway execution. Services intentionally remain running for user testing, with volumes/data retained.

Test development failures fixed before the successful final checks: PowerShell5 pipeline array wrapping caused the five-account preflight to reject valid input; assignment now retains the JSON array. The private UI probe initially tried to re-read a password locator after Flutter semantics changed; it now waits for form updates and asserts actual login response plus navigation. No app validation was changed to make these checks pass.

No Maven/Flutter full suite, analyze/build or biometric evaluation was rerun because application executable source did not change. No GitHub Actions workflow exists in this base tree; manual checks are not CI pass evidence. Source/SQL from PR8 acceptance is historical context only.

## Limits and operation

[Run/recovery instructions](../../LOCAL_DEMO_ALIASES.md). Credentials, exact private resource IDs, before/after checkpoint, DB snapshots and raw logs stay outside Git. No mail is sent during alias maintenance; the existing sink continues to accept only example.invalid for OTP, while example.test is used here for login of already ACTIVE accounts. Logout/login is required to replace old email claims. Face admission remains off; simulator is dev/test only; `targetUpgradeVerified=false`.

Only this maintenance branch is published; no merge, deploy or shared DB operation.