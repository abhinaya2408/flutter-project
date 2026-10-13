# Crumb & Cream — order placement and reference photos: diagnosis

This document records what was found, what was changed, what was **verified**,
and the single action that still needs your approval.

> **Nothing was deployed.** No rule was changed, no Cloud Function was deployed,
> no billing change was made. Everything below under "verified" was verified by
> running tests locally.

---

## 1. Root cause of `cloud_firestore/permission-denied`

### The evidence

`firestore.rules` in this repository allows public reads of `app_meta`:

```rules
match /app_meta/{doc} {
  allow read: if true;          // ← the rules in the repo
  ...
}
```

A read-only probe against the **live** project returns 403 instead:

```bash
KEY="<web apiKey from lib/firebase_options.dart>"   # public, not a secret
curl -s -w '\nHTTP %{http_code}\n' \
  "https://firestore.googleapis.com/v1/projects/bakeflow-20fb9/databases/(default)/documents/app_meta/demo_seed?key=$KEY"
```

```
{ "error": { "code": 403, "message": "Missing or insufficient permissions." } }
HTTP 403
```

**Conclusion: the deployed ruleset is not the `firestore.rules` in this repo.**
If it were, that read would return 200.

Corroborating evidence that the repo's rules were never deployed:

| Check | Result |
| --- | --- |
| `.firebase/` contents | a single `hosting.YnVpbGRcd2Vi.cache` — no rules deploy record |
| `docs/WEB_DEPLOYMENT.md` deployment record | `firebase deploy --only hosting`; rules mentioned only as an optional extra |
| `firebase projects:list` | the CLI **is** authenticated, so a deploy is one command away |

A Firestore database created from the console without deploying custom rules
runs Firebase's locked default (`allow read, write: if false`), which denies
every operation the app makes.

### Why this explains both of your symptoms

| Symptom | Cause |
| --- | --- |
| `cloud_firestore/permission-denied` on Place Order | the create on `orders/{orderId}` is denied by the deployed rules |
| Reference-photo uploads failing "with Firebase Storage errors" | `storage.rules` was never deployed either, so the write to `reference_images/...` is denied |

It is **not** the order id, not the serialized fields, and not the rules file in
the repo. Those are all consistent — the rules just are not live.

### The write path, for the record

For a student `ananya.sharma@yourcollege.edu` signed in as `uid = <their Auth uid>`:

| Step | Value | Governing rule (repo) |
| --- | --- | --- |
| Auth session | `request.auth.uid` | required by every rule |
| Profile document | `students/{uid}` | `allow read: if request.auth != null` |
| `studentId` on the order | taken from that profile (`STU2024001`) | rules do **not** compare it to the profile |
| Order document | `orders/{orderId}` | `allow read, write: if request.auth != null` |
| Serialized fields | the 19 keys from `Order.toMap()` — all `String`/`int`/`List<String>` | no type constraints in the rules |

So under the repo's rules the write is permitted and the payload matches. The
only thing standing in the way is that those rules are not deployed.

---

## 2. Code defects found and fixed (independent of the rules)

### 2.1 `generateOrderId()` read the whole collection — fixed

```dart
// BEFORE: one full-collection read, and any failure silently became CK1024
int maxNumber = 1023;
try {
  final snapshot = await _orders.get();
  ...
} on FirebaseException {
  // swallowed
}
return 'CK${maxNumber + 1}';
```

Two separate defects:

1. **It required a collection-wide read.** No sane rule set grants a student that,
   so this would break the moment the rules were tightened — including by
   `firestore.rules.proposed`.
2. **The failure fallback returned `CK1024` for every order.** A permissions
   problem was therefore indistinguishable from success, and every subsequent
   order overwrote the previous `CK1024` document.

Now (`OrderService.generateOrderId` + `OrderNumbering`):

* the number is issued from a **single counter document**, `app_meta/order_counter`,
  inside a `runTransaction`, so concurrent orders can never share a number and
  no collection is ever read;
* `app_meta` is readable/writable by signed-in users under **both** the current
  rules and `firestore.rules.proposed`, so this needs no rule change now or later;
* errors **propagate** — there is no fallback path left in the method;
* the counter starts at 1999, so the first issued id is `CK2000`: above the demo
  records (`CK1001`–`CK1005`) and above the poisoned `CK1024`, and a missing or
  tampered counter value can never move it backwards.

### 2.2 Order placement could fail silently

```dart
final student = context.read<SessionController>().student;
if (student == null) return;      // BEFORE: no message, no navigation
```

A student with a stale profile (in-memory profile present, Firebase Auth session
gone) reached the write, and the rules rejected it with `permission-denied`
because `request.auth` was null. Now:

* `OrderPlacementGuard.blockReason(...)` checks the profile **and** the live
  Firebase Auth uid, and reports which one is missing;
* the screen says why, signs the stale session out, and routes to sign-in instead
  of looking like a dead button;
* raw exceptions are no longer dumped into a toast: `permission-denied`,
  `unauthenticated`, `unavailable` and `deadline-exceeded` each get their own
  message.

### 2.3 Duplicate submissions and duplicate uploads

* `_pendingOrderId` — one id per submission, reused by every retry, so a timeout
  or a double tap cannot create a second order.
* `_uploadedImageUrl` keyed by the pick — a retry after a failed order write does
  not upload the same photo again, so no orphaned asset is created.
* Success is reported only after `createOrder` resolves.

---

## 3. Reference photos: Cloudinary was not implemented — now it is

**Important correction to the brief:** there was no Cloudinary code in this
repository. `grep -ri cloudinary lib test pubspec.yaml` returned nothing before
this change; `lib/services/reference_image_service.dart` uploaded to **Firebase
Storage** (`reference_images/{orderId}/{fileName}`). The migration you described
had not been made.

What exists now:

| File | What it does |
| --- | --- |
| `lib/services/cloudinary_image_service.dart` | **New.** Unsigned upload: `POST https://api.cloudinary.com/v1_1/haryqfbk/image/upload` with the `crumbly_reference_upload` preset and the file as multipart |
| `lib/config/app_config.dart` | Cloud name + preset (both public by design), and `useCloudinaryForReferenceImages` to switch providers |
| `lib/services/reference_image_service.dart` | Delegates uploads to Cloudinary; the Firebase Storage upload is kept as the switchable fallback |
| `pubspec.yaml` | Added `http_parser` (already a transitive dependency) for the correct part content type |

Behaviour, unit-tested:

* validates extension, emptiness and the 2 MB limit **before** any request;
* checks the HTTP status, then extracts `secure_url`;
* only accepts an absolute **https** URL — a 200 without a usable `secure_url`
  is treated as a failure, never as an upload;
* surfaces Cloudinary's own `error.message` (for example `Upload preset not found`);
* timeouts and network failures get plain-language messages;
* **no API key, secret or signature is sent or stored** — asserted by a test that
  greps the outgoing body for `api_secret`, `api_key` and `signature`;
* the current rate/`Date.now()`-independent path means a failed upload never
  produces an order with a fabricated image URL: the upload throws, the order is
  not written, and the student can retry or submit without a photo.

### Cloudinary dashboard settings you must confirm

I could not test a real upload — see §6. Before the photo path can be called
working, confirm in the Cloudinary console:

1. `crumbly_reference_upload` exists and its signing mode is **Unsigned**. A
   signed preset rejects a client upload with `Upload preset ... is not unsigned`.
2. The preset allows the **image** resource type (not "raw").
3. The preset's size limits allow at least 2 MB (the app's limit).
4. Incoming transformation / "return delete token" are not required by anything here.
5. The cloud name is exactly `haryqfbk` (case-sensitive).

If the preset is signed, the correct fix is to make it unsigned — **not** to put
an API secret in the app.

---

## 4. Registration: automatic account + profile

Confirmed by inspection of `AuthService.registerStudent`:

1. `createUserWithEmailAndPassword` → the Auth account;
2. the Auth `uid` is used as the profile document id (`students/{uid}`);
3. the profile is written with `studentId`, `fullName`, `email`, `phone`,
   `updatedAt` and `createdAt`;
4. the session is established (`SessionController._student`) and the screen
   routes straight to `/customize` (the student home) with no second login;
5. session restoration on restart goes through `FirebaseAuth` → `restoreStudent()`.

**Change made — partial failure.** Previously, if the Firestore profile write
failed, the app called `signOut()` and threw a generic error. That left an
account the student could neither use (no profile) nor re-create (the email was
already in use) — a dead end. Now:

* `ProfileWriteFailure` is thrown, the Auth session is **kept**;
* the registration form stays usable and offers `Finish Setting Up Profile`;
* the next attempt calls `AuthService.ensureStudentProfile(...)`, which writes
  (merge) only under the current user's own uid and never rewrites `createdAt`;
* `phoneVerified` is never touched, so a value written by the trusted OTP backend
  is preserved by a repair.

---

## 5. Checkout: persistent action bar

`StudentPageScaffold` gained an optional `bottomBar`, and `CustomizeScreen` now
uses it:

* the estimated total and the single **Place Cake Order** action are pinned below
  the scroll area, so nothing has to be scrolled back to;
* the duplicate button that used to live at the end of the summary card was
  removed — there is exactly one Place Order control on the screen;
* the bar is laid out **outside** the scroll view, so it cannot cover fields, and
  it sits in a `SafeArea(top: false)` so it clears the Android system navigation;
* with the keyboard open the bar rises with the content instead of hiding under it;
* the price still comes from `CustomizeController`/`calculatePrice`, and the
  selections, reference image and pickup date/time are untouched;
* a live hint under the button names what is still missing
  (`Please complete: cake size, required date.`).

The action stays tappable while selections are incomplete **on purpose**: a
disabled button that explains nothing is exactly the "silently does nothing"
failure mode, and tapping is what surfaces the detailed field errors. It is
disabled while a submission is running.

---

## 6. Verified vs. not verified

### Actually run, locally

| Check | Result |
| --- | --- |
| `flutter analyze` | no issues |
| `flutter test` | **140 passed** (108 before + 32 new) |
| New tests | `order_numbering_test.dart`, `cloudinary_image_service_test.dart`, `order_placement_test.dart` |
| `flutter build web` | see the report for the final run |
| `npm test` in `functions/` | see the report (WhatsApp backend unchanged) |

What the new tests cover: order numbering (uniqueness, the `CK1024` regression,
monotonicity, no collision with demo ids), the `Order` model's 19 fields and
round-trip, the Cloudinary request shape and every failure branch, the placement
guard, and the registration partial-failure recovery through the real widget.

### Not verified — needs a device, a deploy or credentials

1. **An order actually reaching Firestore.** Impossible until the rules are
   deployed, and I will not deploy without your approval.
2. **A real Cloudinary upload**, and therefore the two end-to-end photo paths.
   The request shape and failure handling are unit-tested against a mock; the
   live preset has never been called.
3. **Firebase Storage uploads** — unchanged code path, still governed by
   `storage.rules`, which is also not deployed.
4. **Android/iOS builds.** Only web is built here.

---

## 7. What you need to do

### The one action that unblocks orders and photos

```bash
firebase login                        # already authenticated on this machine
firebase deploy --only firestore:rules,storage --project bakeflow-20fb9
```

That deploys the **existing** `firestore.rules` and `storage.rules` — no rule is
loosened or rewritten, so this is the smallest correction that makes the app's
own expectations true. Then verify:

```bash
# should now be 200 with the seed flag
curl -s -w '\nHTTP %{http_code}\n' \
  "https://firestore.googleapis.com/v1/projects/bakeflow-20fb9/databases/(default)/documents/app_meta/demo_seed?key=<web apiKey>"
```

and then, signed in as a student: place an order without a photo, then with one,
and check that both appear in **My Orders** and in the bakery dashboard.

> Do **not** deploy `firestore.rules.proposed` yet. It is the stricter set for
> later; §5.2 of `docs/WHATSAPP_OTP.md` explains the two demo-seeder consequences
> that must be resolved first. The new order-id approach is already compatible
> with it — the *old* one was not.

### Then

1. Confirm the Cloudinary preset is **unsigned** (§3).
2. Order ids change: new orders are `CK2000`, `CK2001`, … Existing
   `CK1001`–`CK1005` records are untouched. Nothing else about the order model,
   confirmation screen or history changed.

---

## 8. Files changed in this pass

| File | Change |
| --- | --- |
| `lib/services/order_service.dart` | Counter-based `generateOrderId`, `OrderNumbering`, `OrderPlacementGuard`, documented `createOrder` |
| `lib/services/firestore_paths.dart` | Added `orderCounter` |
| `lib/services/cloudinary_image_service.dart` | **New** unsigned upload service |
| `lib/services/reference_image_service.dart` | Cloudinary-first, Storage fallback |
| `lib/config/app_config.dart` | Cloudinary + provider switch |
| `lib/screens/customize_screen.dart` | Auth guard, error mapping, idempotent retry, single-upload cache, persistent bottom bar |
| `lib/widgets/page_scaffold.dart` | Optional `bottomBar` |
| `lib/services/auth_service.dart` | `ProfileWriteFailure`, `ensureStudentProfile` |
| `lib/state/session_controller.dart` | `ensureStudentProfile` |
| `lib/screens/student_register_screen.dart` | Profile-completion retry |
| `pubspec.yaml` | `http_parser` added, `cloud_functions` (previous pass) |
| `test/*` | 32 new tests |
