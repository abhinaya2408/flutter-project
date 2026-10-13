# Crumb & Cream — WhatsApp OTP authentication (Twilio Verify)

This document covers the WhatsApp one-time-code sign-in that was added to the
existing Flutter app, what is finished, what is verified, and **exactly** what
you still have to set up before a real code can be delivered.

> **Status: implemented and unit-tested, not live.**
> No Twilio account exists yet, no Function has been deployed, Firebase has not
> been upgraded to Blaze, and no security rule has been changed. Nothing about
> your current sign-in changes until you complete § 6.
> **Real WhatsApp delivery has not been tested and is not claimed to work.**

---

## 1. What was added

Nothing was replaced. Email + password sign-in and registration are untouched
and remain the working path.

### Backend — `functions/` (new)

| File | Purpose |
| --- | --- |
| `src/config.ts` | Env-var configuration, SID validation, and the guard that makes the mock provider unreachable outside the emulator |
| `src/phone.ts` | Server-side E.164 normalisation, masking, code-shape validation |
| `src/errors.ts` | The 12 machine-readable failure reasons and their `HttpsError` codes |
| `src/rate_limiter.ts` | Pure sliding-window limiter logic + hashed bucket keys |
| `src/ports.ts` | The provider / auth / profile / limiter interfaces the handlers depend on |
| `src/providers/twilio.ts` | Twilio Verify REST client (WhatsApp channel only) |
| `src/providers/mock.ts` | Emulator-only provider, triple-gated, no built-in code |
| `src/handlers.ts` | `requestWhatsAppOtp` + `verifyWhatsAppOtp` — all the security logic |
| `src/admin_adapters.ts` | The `firebase-admin` implementations of the ports |
| `src/index.ts` | The two callable Cloud Functions |
| `test/` | 74 vitest tests. Fake verification lives here, never in `src/` |

### App — `lib/`

| File | Purpose |
| --- | --- |
| `lib/screens/whatsapp_verify_screen.dart` | The OTP screen (sign-in and link modes) |
| `lib/services/whatsapp_otp_service.dart` | Callable client, failure mapping, user copy |
| `lib/models/otp_verification.dart` | Strict result parsing (no Firebase import) |
| `lib/utils/phone_number.dart` | Client mirror of the server's normalisation |
| `lib/data/country_codes.dart` | Dial-code list, India default |
| `lib/services/auth_service.dart` | **Added** `signInWithCustomToken` + `SessionSignIn` (existing methods unchanged) |
| `lib/state/session_controller.dart` | **Added** `loginWithWhatsAppOtp` + `reloadStudentProfile` |
| `lib/models/student_profile.dart` | **Added** `phoneE164` / `phoneVerified` (both optional) |
| `lib/utils/validators.dart` | **Added** `otpPhoneNumber` / `otpCode` (existing `phone()` untouched) |
| `lib/config/app_config.dart` | Region + the two callable names. **No credentials.** |
| `lib/main.dart` | `/whatsapp-verify` route |
| `lib/screens/student_login_screen.dart` | One link: "Or sign in by verifying your WhatsApp number" |

Entry point: the student sign-in screen → `/whatsapp-verify`.

---

## 2. How a sign-in works

```
Student                 App                 Cloud Function            Twilio Verify
   |  phone number  ->   |                       |                       |
   |                     |  requestWhatsAppOtp   |                       |
   |                     |---------------------->|  normalise to E.164   |
   |                     |                       |  rate limit (phone)   |
   |                     |                       |  rate limit (IP)      |
   |                     |                       |---------------------->|  send code
   |  <--- "sent to +91••••••3210, resend in 60s" |                       |
   |  code               |                       |                       |
   |  123456         ->  |  verifyWhatsAppOtp    |                       |
   |                     |---------------------->|  rate limit (phone)   |
   |                     |                       |---------------------->|  check code
   |                     |                       |  <--- approved        |
   |                     |                       |  resolve phone -> uid |
   |                     |                       |  (Admin SDK)          |
   |                     |  <--- custom token    |                       |
   |                     |  signInWithCustomToken                        |
   |  <--- real Firebase session, routed by role  |                       |
```

`link` mode (already signed in) is the same flow, except that instead of a
custom token the backend attaches the number to `request.auth.uid` and sets
`phoneVerified: true` on the profile document that already exists.

**The code never exists in your codebase.** Twilio generates and verifies it.
This backend never generates, stores, compares, returns or logs a code — it can
only ask for one to be sent and ask whether a supplied one is correct.

### Why a custom token, and not Firebase phone auth

Firebase's own phone sign-in is SMS-only; it has no WhatsApp channel, and its
`PhoneAuthProvider.credential(verificationId, code)` path can only be completed
by Firebase's own SMS flow — a third-party provider's result cannot be fed into
it. So the verified phone number is turned into a **Firebase custom token**
(`admin.auth().createCustomToken(uid)`) and exchanged by the client with
`signInWithCustomToken`. That produces a normal Firebase session and ID token,
so `firestore.rules` treats it exactly like a password sign-in.

---

## 3. Security properties (and where each one is enforced)

| Property | Enforced in |
| --- | --- |
| No provider credential in the app | Only `functions/` reads `TWILIO_*`; `app_config.dart` has no secret |
| The code is never seen by your code | `providers/twilio.ts` only calls `Verifications` / `VerificationCheck` |
| No account enumeration | `verifyWhatsAppOtp` resolves the account only *after* Twilio approves the code |
| Brute-force resistance | Per-phone verify limit (5 / 10 min) checked *before* the provider call, plus every wrong code counting against it |
| Resend abuse | 60s cooldown + 3 per 15 min per phone, 10 per hour per IP |
| Replay / duplicate taps | Provider-owned single-use codes; the screen disables its action while a call is in flight |
| Linking only to *your own* account | `link` requires a runtime-verified `request.auth.uid`; a uid in the request body is ignored |
| One number, one account | `phone-in-use` when the number already belongs to a different uid |
| No privilege escalation | The backend only ever *reads* the role and only writes `phoneVerified*` on a document that already exists. It never creates a profile and never writes a `role` field |
| No fake verification | The mock provider refuses to construct outside the emulator/tests, and requires an explicit `OTP_MOCK_CODE` |
| Malformed response ≠ success | `OtpChallenge.fromMap` / `WhatsAppVerification.fromMap` throw on anything incomplete (a `signed_in` result without a custom token is rejected) |
| Phone numbers are not stored raw in limiter/audit docs | Bucket keys and audit ids are SHA-256 hashes; the response carries only a masked number |

---

## 4. Test results

### Dart — `flutter test`

```
108 tests passed  (69 pre-existing + 39 new)
```

The 69 pre-existing tests still pass unchanged — run on their own to confirm:
`flutter test test/customize_controller_test.dart test/formatters_test.dart
test/order_model_test.dart test/order_status_test.dart
test/phone_navigation_test.dart test/pricing_test.dart
`test/screens_widget_test.dart test/validators_test.dart` → `+69: All tests passed!`.

New: `test/phone_number_test.dart` (11), `test/whatsapp_otp_service_test.dart`
(13), `test/whatsapp_verify_screen_test.dart` (15).

`flutter analyze` → **No issues found.**

### Backend — `npm test` in `functions/`

```
Test Files  5 passed (5)
     Tests  74 passed (74)
```

Covers: E.164 normalisation and masking, the sliding window + cooldown maths,
Twilio request shape (URL, Basic auth, `Channel=whatsapp`, form body), every
provider status mapping, credential/network/invalid-number failure mapping,
config validation, the mock-provider guard, and both handlers — including
"the sixth attempt never reaches the provider", "a token is never issued for an
account with no profile", "a number owned by another account is refused", and
"a student cannot be promoted by verifying a number".

### Formatting — read this

`dart format --set-exit-if-changed lib test` reports **62 files** would change,
**including files this task did not touch** (`pricing_test.dart`,
`screens_widget_test.dart`, …). The repository predates the Dart 3.7+
formatter's "tall style", so this is pre-existing drift, not something the OTP
work introduced. I deliberately did **not** reformat the repository, because a
62-file cosmetic diff would bury the real changes. New files are hand-formatted
to the repository's existing 80-column style.

---

## 5. Firestore rules review

The tightened rules are staged in **`firestore.rules.proposed`**. `firebase.json`
still points at `firestore.rules`, so **nothing is live** — review it, then
switch the pointer and deploy when you are ready.

### 5.1 Every change, and its impact

| Collection | Before | Proposed | Impact |
| --- | --- | --- | --- |
| `students/{uid}` read | any signed-in user | owner only | Nothing in the app reads another student's document (`studentIdExists()` is never called; the dashboard renders student details from the *order*). Reopen with an explicit `\|\| isBakeryMember()` if that changes. |
| `students/{uid}` create | any signed-in user, any uid | own uid, field shape enforced, `phoneVerified` must be `false` | Registration still works unchanged (`AuthService.registerStudent` writes its own uid, and `toMap()` now emits `phoneVerified: false`). A forged `phoneVerified: true` is rejected. |
| `students/{uid}` update | unrestricted | `fullName`, `phone`, `updatedAt` only; verification fields frozen | `email` and `studentId` become immutable; no screen edits them today. A verified number cannot be silently un-verified by a client. |
| `students/{uid}` delete | any signed-in user | `false` | **Breaks `DemoSeedService._wipe()`**, which deletes demo student documents from the client. See §5.2. |
| `bakery_members/{uid}` write | any signed-in user | `false` (server only) | **This closes a real privilege escalation**: previously any student could create their own bakery-member document and open the bakery dashboard. **Breaks the seed of the demo owner document** — see §5.2. |
| `orders` read | any signed-in user | own orders, or any order for a bakery member | A student can no longer read other students' orders. Requires the history query to filter on `studentId` (it already does). |
| `orders` create | any signed-in user | own `studentId` only | Matches the existing client behaviour. |
| `orders` update | any signed-in user | bakery member, `status`/`updatedAt` only | Students can no longer rewrite an order's price, image URL or pickup time. |
| `orders` delete | any signed-in user | bakery member | Keeps the dashboard usable. |
| `notifications` | any signed-in user read/write | own notifications; students may only flip `read` | A student cannot forge a notification or edit another student's. |
| `otp_rate_limits`, `otp_verifications` | do not exist | `false` for clients | New server-only collections. The Cloud Functions use the Admin SDK, which bypasses rules, so this costs nothing. |
| `app_meta` | public read / signed-in write | unchanged | Unchanged on purpose: the demo-seed flag must be readable before sign-in. |

### 5.2 Two consequences you must decide on

Applying the proposed file changes how the **client-side demo seeder** behaves:

1. **The demo owner document can no longer be created from the app**, because
   `bakery_members` writes become server-only. That is the point — but it means
   the demo bakery account must be provisioned once from the Firebase console
   (Auth user + `bakery_members/{uid}` document), or by an Admin SDK task.
2. **"Clear Demo Data" loses its permission to delete student documents**
   (`allow delete: if false`).

Both are fixed properly by moving seeding to a Cloud Function using the Admin
SDK. Until you decide, this is why the file is staged rather than applied.

This also removes a weakness worth naming: `DemoSeedService` currently creates
Firebase Auth accounts from the client with passwords that ship in
`app_config.dart` (`demo1234`, `bakery123`). Any client able to do that can
pre-create accounts, which interacts badly with phone linking. Moving the seed
behind the Admin SDK fixes it.

### 5.3 Do this before applying the `orders` rules

`OrderService.generateOrderId()` reads the **entire** `orders` collection to
derive the next `CK####` id, and it **swallows** the failure:

```dart
} on FirebaseException {
  // Fall back to the default counter if the collection cannot be read.
}
return 'CK${maxNumber + 1}';   // -> CK1024 on any read failure
```

Under the proposed rules that read is denied for a student, so the fallback
returns `CK1024` and the next order collides. Two independent problems: the
denied read, and the silent fallback that hides it. Replace this with a counter
document (or a collision-resistant id) and stop swallowing the error. This is
the same defect that produces the `permission-denied` on order placement.

---

## 6. What you must set up before a real code can be sent

Nothing here can be done by me, and none of it has been done.

### 6.1 Twilio

1. Create a Twilio account.
2. **WhatsApp sender registration** — a WhatsApp Business Account and a sender
   with an approved display name. This is the slowest step and it is external
   to this repository.
3. Create a **Verify Service** → copy its **SID** (`VA…`).
4. Create an **API Key + Secret** (preferred over the account Auth Token).
5. Enable the **WhatsApp channel** on the Verify Service and register an
   **authentication template** (the OTP wording) with Meta.

| Variable | Where it lives |
| --- | --- |
| `TWILIO_ACCOUNT_SID` | backend env / Secret Manager |
| `TWILIO_API_KEY` + `TWILIO_API_SECRET` (or `TWILIO_AUTH_TOKEN`) | backend env / Secret Manager |
| `TWILIO_VERIFY_SERVICE_SID` | backend env / Secret Manager |
| `OTP_PROVIDER=twilio`, `OTP_FUNCTIONS_REGION`, `OTP_DEFAULT_COUNTRY_CODE` | backend env |

**None of these ever go in the Flutter app.** See `functions/.env.example`.

### 6.2 Firebase

1. **Upgrade the project to the Blaze (pay-as-you-go) plan.** Cloud Functions
   cannot be deployed on Spark. This needs a payment method and is a decision
   for you, not for me. Functions stay inside the free quota at this scale.
2. Deploy the Functions (`firebase deploy --only functions`) — requires your
   approval; I have not deployed anything.
3. Keep `AppConfig.otpFunctionsRegion` and `OTP_FUNCTIONS_REGION` identical
   (both `us-central1` by default).
4. Recommended, optional: enable **App Check**, then set
   `OTP_ENFORCE_APP_CHECK=true`. Until then it is deliberately `false`.
5. Recommended: a Firestore **TTL policy** on `otp_rate_limits.expiresAt`.
6. Decide on the demo-seeder consequences in §5.2 before applying
   `firestore.rules.proposed`.

### 6.3 Emulator (no money, no real messages)

```bash
cd functions
npm install
# OTP_PROVIDER=mock, OTP_MOCK_CODE=<6 digits of your choosing>, FUNCTIONS_EMULATOR=true
npm run serve
```

The mock provider refuses to construct in a deployed runtime, and refuses to
construct without an explicit `OTP_MOCK_CODE` — there is no hidden default code.

---

## 7. What still stands between this and a working WhatsApp login

1. Twilio account, WhatsApp sender approval, Verify Service, auth template.
2. Blaze upgrade and a Function deploy.
3. Secrets in the backend environment.
4. A decision on §5.2, then deploying the rules (or keeping them staged).
5. The `generateOrderId()` fix in §5.3 if you want the `orders` rules applied.
6. One real end-to-end run on a device with a real number. **I have not done
   this and cannot do it**, so treat real delivery as unverified until you do.

Until every one of those is in place, tapping the WhatsApp button on a build
with no Functions deployed shows the `not-configured` / `provider-unavailable`
message and **email + password sign-in keeps working**, which is exactly the
intended fallback.

---

## 8. Commands

```bash
# App
flutter pub get
flutter analyze
flutter test

# Backend
cd functions
npm install
npm run build     # tsc -> lib/
npm test          # vitest
npm run lint      # typecheck src + test
```
