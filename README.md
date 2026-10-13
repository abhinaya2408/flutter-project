# Crumb & Cream — Flutter app

A **Flutter + Dart + Firebase** recreation of the existing
[`college-bakery`](../college-bakery) prototype (HTML / CSS / vanilla JS /
LocalStorage).

This project is a **conversion, not a redesign**. The screens, wording, layout,
colours, pricing, validation, statuses, notifications and workflow are the ones
already implemented in `college-bakery`. The existing folder is untouched — this
project was written entirely inside `college_bakery_flutter/`.

Only the technology changed:

| Existing prototype | This project |
| --- | --- |
| HTML pages | Flutter screens (`lib/screens`) |
| `css/*.css` | `lib/theme` + widget styles |
| `js/*.js` | `lib/services`, `lib/state`, `lib/utils`, `lib/data` |
| LocalStorage | Cloud Firestore |
| Plaintext passwords in LocalStorage | Firebase Authentication |
| Data-URL reference image on the order | Firebase Storage upload + download URL |

---

## 1. Firebase setup (required before the app runs)

`lib/firebase_options.dart` ships with **placeholder** values. Until it is
replaced, the app opens a setup notice instead of the landing page. To wire up
your own project:

1. **Create a Firebase project** (or reuse one), then add an **Android app** and
   an **iOS app** to it. The Android package name is
   `com.crumbandcream.college_bakery_flutter` (see
   `android/app/build.gradle.kts`); the iOS bundle id is
   `com.crumbandcream.collegeBakeryFlutter`.
2. **Generate the config** from this folder:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=<your-firebase-project-id>
   ```
   This rewrites `lib/firebase_options.dart` and adds
   `android/app/google-services.json` + `ios/Runner/GoogleService-Info.plist`.
3. **Enable Email/Password** sign-in: Firebase console → Authentication →
   Sign-in method → Email/Password → Enable.
4. **Create Cloud Firestore** (production mode) and **Cloud Storage**.
5. **Publish the rules** (with the Firebase CLI):
   ```bash
   firebase deploy --only firestore:rules,storage
   ```
   The rules live in `firestore.rules` and `storage.rules`; `firebase.json`
   points at them. `firestore.indexes.json` is intentionally empty — every list
   is filtered with a single field and sorted in Dart, so no composite index is
   needed.
6. **Run it**:
   ```bash
   flutter pub get
   flutter run
   ```

On the first launch the app seeds the same demo data the prototype seeds
(`seedDemoData()`), including the three demo student accounts and the bakery
account, created through Firebase Authentication.

### Demo credentials (unchanged from the prototype)

| Role | Email | Password |
| --- | --- | --- |
| Student | `ananya.sharma@yourcollege.edu` | `demo1234` |
| Student | `priya.verma@yourcollege.edu` | `demo1234` |
| Student | `rahul.nair@yourcollege.edu` | `demo1234` |
| Bakery member | `owner@collegebakery.com` | `bakery123` |

New students self-register with an address ending in `@yourcollege.edu`
(`COLLEGE_EMAIL_DOMAIN` → `AppConfig.collegeEmailDomain` in
`lib/config/app_config.dart`).

---

## 2. Screen map

Every page of the prototype has exactly one Flutter screen, reached by the same
navigation path.

| `college-bakery` | Flutter | Route |
| --- | --- | --- |
| `index.html` | `LandingScreen` | `/` |
| `student-login.html` | `StudentLoginScreen` | `/student-login` |
| `student-register.html` | `StudentRegisterScreen` | `/student-register` |
| `customize.html` | `CustomizeScreen` | `/customize` |
| `order-confirmation.html` | `OrderConfirmationScreen` | `/order-confirmation` |
| `my-orders.html` | `MyOrdersScreen` | `/my-orders` |
| `order-details.html` | `OrderDetailsScreen` | `/order-details` |
| `notifications.html` | `NotificationsScreen` | `/notifications` |
| `bakery-login.html` | `BakeryLoginScreen` | `/bakery-login` |
| `owner-dashboard.html` | `OwnerDashboardScreen` | `/owner-dashboard` |
| `owner-order-details.html` | `OwnerOrderDetailsScreen` | `/owner-order-details` |

Workflow, unchanged:

```text
Landing ─┬─ Student Login ──> Student Register
         │        └──────────────> Customize ──> Order Confirmation
         │                                 └──> My Orders ──> Order Details
         │                                 └──> Notifications ──> Order Details
         └─ Bakery Member Login ──> Dashboard ──> Order Details (actions)
```

Owner actions, unchanged:

```text
PENDING   → Accept Order / Reject Order
ACCEPTED  → Start Preparing
PREPARING → Mark Cake Ready
READY     → Mark Collected
COMPLETED / REJECTED → no further actions
```

Each action writes the new status **and** creates the student notification with
the same text as `STATUS_MESSAGES` in `js/app.js`, then shows the same toast.

---

## 3. Where each piece of behaviour lives

| Prototype | Flutter |
| --- | --- |
| `FLAVORS`, `cakeImages`, `SIZE_PRICES`, `DECORATION_PRICES`, cream/deco icons | `lib/data/catalog.dart` |
| `calculatePrice`, `flavorSurcharge` | `lib/utils/pricing.dart` |
| `STATUS_STEPS`, `STATUS_MESSAGES`, `STATUS_TOASTS`, `statusLabel`, `matchesTab` | `lib/data/order_status.dart` |
| `formatDate`, `formatTime`, `timeAgo`, `statusLabel` | `lib/utils/formatters.dart` |
| Every validation message | `lib/utils/validators.dart` |
| `seedDemoData()` / `clearDemoData()` | `lib/services/demo_seed_service.dart` |
| `createOrder`, `generateOrderId`, `updateOrderStatus` | `lib/services/order_service.dart` |
| `createNotification`, `markAllNotificationsRead`, `unreadNotificationCount` | `lib/services/notification_service.dart` |
| `initStudentLoginPage`, `initStudentRegisterPage`, `initOwnerLoginPage` | `lib/services/auth_service.dart` + the three screens |
| `customizeState`, `updatePreview`, `updateSummary`, `placeOrder` | `lib/state/customize_controller.dart` + `CustomizeScreen` |
| `requireStudent()` / `requireOwner()` | `StudentPageScaffold` / `OwnerPageScaffold` in `lib/widgets/page_scaffold.dart` |
| `showToast()` | `lib/widgets/app_toast.dart` (same 3200 ms + 300 ms timings) |
| `renderTracker()` | `lib/widgets/status_tracker.dart` |

### Firestore shape (LocalStorage key → collection)

```text
bakery_students       -> students/{uid}          studentId, fullName, email, phone
bakery_owner_session  -> bakery_members/{uid}    email, role
bakery_orders         -> orders/{orderId}        the same fields as createOrder()
bakery_notifications  -> notifications/{id}       id, studentId, orderId, message, read, createdAt
bakery_seeded         -> app_meta/demo_seed      { seeded: true, seededAt }
bakery_current_user   -> Firebase Auth session   (no document)
                       -> app_meta/demo_accounts { ownerUid, students[] }
```

Field names, value types and string formats are kept identical to the original
records — `estimatedPrice` is an integer, `requiredDate` is `YYYY-MM-DD`,
`requiredTime` is `HH:mm`, and `createdAt` / `updatedAt` are ISO-8601 strings.
`app_meta/demo_accounts` is the one addition: Firebase Authentication accounts
cannot be re-listed from a client, so the demo uids are remembered there so the
dashboard's **Clear Demo Data** link can re-seed exactly like `clearDemoData()`.

Live updates use Firestore listeners; the prototype refreshed on page load. The
user-visible behaviour is the same (the bakery sees new orders, the student sees
the new status and the unread badge), just without a manual refresh.

---

## 4. Differences that the platform requires

Everything below is a mechanism change, not a UI/behaviour change; each one is
called out so nothing is hidden.

1. **Passwords live in Firebase Authentication** (rule: no plaintext passwords in
   Firestore). The `students` documents hold only the profile fields of
   `setCurrentStudent()`: `studentId`, `fullName`, `email`, `phone`.
2. **Student ID uniqueness** is checked against `students` right after the Auth
   account is created (the account is rolled back if the id is taken), because
   the original checked a local array before creating the record. The message is
   the original `This Student ID is already registered.`; a duplicate email is
   reported by Firebase Authentication with the original
   `An account with this email already exists.`
3. **Bakery membership** is stored in `bakery_members/{uid}` instead of a
   hard-coded credential pair. Any failure still shows
   `Incorrect email or password.` on the password field, exactly like
   `initOwnerLoginPage()`. The single demo account is seeded as
   `owner@collegebakery.com` / `bakery123`.
4. **Reference photos** are uploaded to Firebase Storage
   (`reference_images/{orderId}/{fileName}`) and the download URL is stored in
   the order's `referenceImage` field. The accept list (JPG/JPEG/PNG), the 2 MB
   limit, the validation messages, the preview and the remove behaviour are
   unchanged, and the same limits are enforced by `storage.rules`.
5. **Date and time** use the platform date/time pickers instead of the browser's
   inline `<input type="date">` / `<input type="time">` widgets. They show the
   app's own formats (`8 October 2026`, `4:00 PM`) and the same validation runs
   (`Please select a date.`, `Please choose a date that is today or later.`,
   `Please select a time.`).
6. **`app_meta` bootstrap documents** exist because Firestore has no LocalStorage
   equivalent for the one-time seed flag.
7. **A setup notice screen** (`lib/screens/firebase_setup_screen.dart`) is shown
   only while `lib/firebase_options.dart` still contains placeholders.
8. **The customize preview column** is sticky at ≥ 980 px (as the CSS
   `position: sticky` does) and scrolls independently if it is taller than the
   viewport.
9. **The footer copyright line is kept verbatim**, including
   `built with HTML, CSS & JavaScript`, because the brief was to preserve the
   existing content.
10. **Responsive rules** are ported from the CSS media queries: `900px` (hero
    stacking, 2-column grids, stat/detail grids), `980px` (customize layout,
    owner sidebar, table), `640px` (hamburger nav, single-column grids),
    `560px` and `520px` (form rows).

Nothing was added: no dark mode, no search, no extra screens, no extra roles, no
renamed statuses, no new pricing rules and no new validation.

---

## 5. Verification

```bash
flutter analyze   # no issues
flutter test      # 63 tests
```

The tests cover the logic that has to stay identical:

* `test/pricing_test.dart` — every price combination, including the five seeded
  orders (`CK1001` ₹680, `CK1002` ₹850, `CK1003` ₹340, `CK1004` ₹1240,
  `CK1005` ₹680).
* `test/formatters_test.dart` — date, time, `timeAgo` and file-size formatting.
* `test/validators_test.dart` — every validation message, verbatim.
* `test/order_status_test.dart` — status progressions, My Orders tab buckets,
  notification texts, owner action buttons.
* `test/customize_controller_test.dart` — live preview, order summary and the
  `placeOrder()` validation (including the missing-field sentence).
* `test/order_model_test.dart` — the order/notification document shapes.
* `test/screens_widget_test.dart` — the landing page content, the three sign-in /
  registration screens and their field errors.

The end-to-end flow (place order → bakery accepts → status → notification) needs
a real Firebase project, since it exercises Authentication, Firestore and
Storage. Once `flutterfire configure` has been run, walk through it with the demo
accounts listed above; every screen reads and writes through the services above.

---

## 6. Project structure

```text
college_bakery_flutter/
├── lib/
│   ├── main.dart                    # routes + theme + session provider
│   ├── firebase_options.dart        # placeholder Firebase config
│   ├── config/app_config.dart       # COLLEGE_EMAIL_DOMAIN, demo accounts
│   ├── data/                        # flavours, prices, images, statuses
│   ├── models/                      # order, notification, student, draft
│   ├── screens/                     # the 11 screens listed above
│   ├── services/                    # Firebase: auth, orders, notifications,
│   │                                # storage upload, demo seeding, bootstrap
│   ├── state/                       # session + customize controllers
│   ├── theme/                       # colours, spacing, radii, shadows, text
│   ├── utils/                       # pricing, validation, formatting
│   └── widgets/                     # navbar, buttons, fields, cards, tracker,
│                                    # pills, toast, upload area, responsive
├── test/                            # unit + widget tests
├── firestore.rules / storage.rules
├── firebase.json / firestore.indexes.json
├── android/ · ios/
└── pubspec.yaml
```

Dependencies: `firebase_core`, `firebase_auth`, `cloud_firestore`,
`firebase_storage`, `provider`, `google_fonts` (Inter + Poppins, the same two
families the pages load from Google Fonts) and `image_picker`.

---

## 7. Flutter Web / PWA deployment

The app now also builds for the **web** and deploys to **Firebase Hosting** as an
installable PWA, so anyone with the link can open Crumb & Cream on a phone and
add it to the home screen. Full instructions live in
[`docs/WEB_DEPLOYMENT.md`](docs/WEB_DEPLOYMENT.md).

What was added for that:

| File | Purpose |
| --- | --- |
| `web/` | Flutter web shell — `index.html`, `manifest.json`, icons |
| `web/manifest.json` | App name, coral `#FF6F61` theme, 192/512 + maskable icons, `standalone` |
| `lib/firebase_options.dart` | Added the `web` Firebase options (`kIsWeb` previously threw `UnsupportedError`) |
| `lib/services/firebase_bootstrap.dart` | Stops on a placeholder config instead of showing a half-working app |
| `firebase.json` | `hosting` target publishing `build/web` |
| `.firebaserc` | Default project `bakeflow-20fb9`, so `firebase deploy` does not prompt |

```bash
flutter build web --release
firebase deploy --only hosting
```

Two things are still needed before the web build is functional: registering a
**Web** app in Firebase (it has its own `apiKey`/`appId`, which cannot be reused
from the Android/iOS entries), and having the Hosting domain on the
Authentication **authorized domains** list. See `docs/WEB_DEPLOYMENT.md` §2–3.

> **Deployed and live at <https://bakeflow-20fb9.web.app>.** A Firebase Web app
> (`Crumb & Cream Web`) was registered and `firebase deploy --only hosting`
> released the build. See `docs/WEB_DEPLOYMENT.md` §9 for the verification record.
