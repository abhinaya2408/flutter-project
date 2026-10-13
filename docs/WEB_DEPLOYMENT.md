# Crumb & Cream — Flutter Web / PWA deployment (Firebase Hosting)

This guide takes the **existing** Flutter app to a public HTTPS URL that anyone
can open on a phone and install to their home screen. It changes no app
behaviour: the same screens, the same Firebase Authentication sign-in and the
same Firestore data.

> **This deployment has been performed.** The Web app registration now exists
> and the site is live at **<https://bakeflow-20fb9.web.app>** — see §9 for the
> record and the verification results. The steps below are kept as the reference
> for repeating the deployment or moving it to a different Firebase project.

---

## 1. What was added, and what was left alone

| File | Change |
| --- | --- |
| `web/` *(new)* | Flutter web shell: `index.html`, `manifest.json`, icons |
| `web/manifest.json` | Crumb & Cream name, coral `#FF6F61` theme, 192/512 + maskable icons, `standalone` |
| `web/index.html` | Title, description, `theme-color`, iOS `apple-*` meta tags |
| `lib/firebase_options.dart` | Added the `web` block and `kIsWeb` handling — the web build previously threw `UnsupportedError` |
| `lib/services/firebase_bootstrap.dart` | Refuses to start on a placeholder config instead of showing a half-working app |
| `firebase.json` | Added the `hosting` target (`build/web`, SPA rewrite, `no-cache` on the shell) |
| `.firebaserc` | Default project `bakeflow-20fb9`, so `firebase deploy` does not prompt |
| `.gitignore` | Ignores `.firebase/` (CLI state) |

**Untouched:** every file under `lib/screens`, `lib/services` (other than the
bootstrap guard), `lib/models`, `lib/state`, the Android and iOS projects, and
`firestore.rules` / `storage.rules`.

---

## 2. Firebase **Web** app registration

> **Done.** The Web app **`Crumb & Cream Web`**
> (`1:606802822852:web:1999258d25e844a870ab91`) was created in project
> `bakeflow-20fb9`, and its `apiKey` / `appId` are already wired into
> `lib/firebase_options.dart`. The two options below are how that is done — kept
> for reference if you deploy to a different Firebase project.

A browser is a **separate Firebase app registration** with its own App ID and
browser API key, so the existing Android/iOS values cannot be reused. Two ways
to fill the two remaining placeholders in `lib/firebase_options.dart`:

### Option A — FlutterFire CLI (recommended: also creates the Web app)

```bash
dart pub global activate flutterfire_cli
firebase login
flutterfire configure --project=bakeflow-20fb9 --platforms=web
```

That rewrites `lib/firebase_options.dart` with the real `web` values and leaves
Android/iOS as they are. **`firebase login` opens a browser and is the step that
needs your Google account.**

### Option B — Firebase console

1. Open <https://console.firebase.google.com/project/bakeflow-20fb9/settings/general>
2. **Your apps → Add app → Web (`</>`)** — nickname it e.g. `Crumb & Cream Web`.
3. Copy `apiKey` and `appId` into the `web` block of `lib/firebase_options.dart`,
   replacing `REPLACE_WITH_YOUR_API_KEY` and `REPLACE_WITH_YOUR_WEB_APP_ID`.
   `projectId`, `authDomain`, `messagingSenderId` and `storageBucket` are already
   correct and need no change.

Until this is done, the web build shows the in-app *"Connect your Firebase
project"* notice rather than the landing page. That is deliberate: it prevents a
half-configured deploy from looking like a working one.

---

## 3. Firebase Authentication — authorized domains

Firebase Auth rejects sign-in from any host that is not on the authorized list
with `auth/unauthorized-domain`. Check it at:

<https://console.firebase.google.com/project/bakeflow-20fb9/authentication/settings>

The list must contain:

| Domain | Status |
| --- | --- |
| `localhost` | default — used by `flutter run -d chrome` |
| `bakeflow-20fb9.web.app` | default — **the Hosting URL this guide deploys to** |
| `bakeflow-20fb9.firebaseapp.com` | default |
| any custom domain you add later | **must be added here first** |

The three defaults already cover the URL produced in §5, so no console change is
required for the default Hosting URL.

---

## 4. Build

```bash
flutter pub get
flutter build web --release
```

The output is written to `build/web`, which is what `firebase.json` publishes.
`build/` is gitignored — never commit it.

---

## 5. Deploy

```bash
firebase login                      # once, on this machine
firebase deploy --only hosting
```

Only if you also change the security rules:

```bash
firebase deploy --only firestore:rules,storage
```

> **Done.** `firebase deploy --only hosting --project bakeflow-20fb9` completed
> and released the site to **<https://bakeflow-20fb9.web.app>**.

To re-deploy after any change:

```bash
flutter build web --release
firebase deploy --only hosting
```

---

## 6. Verify after deploying

| Check | How | Expected |
| --- | --- | --- |
| App loads | open the Hosting URL | the landing page, **not** the setup notice |
| Manifest | DevTools → Application → Manifest | Crumb & Cream, 4 icons, `standalone`, no errors |
| Student sign-in | `ananya.sharma@yourcollege.edu` / `demo1234` | the student dashboard |
| Bakery sign-in | `owner@collegebakery.com` / `bakery123` | the owner dashboard |
| Wrong password | any account | `Incorrect email or password.` |
| Install (Android) | Chrome → ⋮ → **Install app** | icon on the home screen, opens without browser chrome |
| Install (iOS) | Safari → Share → **Add to Home Screen** | icon on the home screen, `standalone` display |

---

## 7. Known limitations

* **No offline mode.** Flutter 3.44 removed `--pwa-strategy`, and the
  `flutter_service_worker.js` it generates is a stub that calls
  `self.registration.unregister()`. Nothing is cached. The app still *installs*
  (a service worker is not required for installability), but it needs a network
  connection to run. A custom service worker can be added later if offline
  support is wanted.
* **CanvasKit / payload size.** `main.dart.js` is ≈3 MB uncompressed (≈0.7 MB
  gzipped), plus CanvasKit fetched on first load. Expect a few seconds on a slow
  connection.
* **Sign-in is Firebase Auth on the web**, so the same accounts and the same
  `students/{uid}` Firestore reads are used as on Android/iOS.

---

## 8. What you must provide

| Item | Why it is needed |
| --- | --- |
| Firebase **Web app** `apiKey` + `appId` (§2) | the two remaining placeholders |
| `firebase login` (your Google account) | to create the Web app registration and to deploy |
| Approval to run `firebase deploy --only hosting` | this publishes the site publicly |

**No service-account key is required, and none should ever be committed.** The
client values in `firebase_options.dart` are not secrets — they are designed to
ship inside every copy of the app, and access is enforced by `firestore.rules`
and `storage.rules` instead.

---

## 9. Deployment record

| Item | Value |
| --- | --- |
| Firebase project | `bakeflow-20fb9` ("BakeFlow") |
| Hosting site | `bakeflow-20fb9` |
| **Live URL** | **https://bakeflow-20fb9.web.app** |
| Web app registered | `Crumb & Cream Web` — `1:606802822852:web:1999258d25e844a870ab91` |
| Deployed artifact | `build/web` (38 files), via `firebase deploy --only hosting` |
| Toolchain | Flutter 3.44.5 stable / Dart 3.12.2 |

### Verified against the live site

| Check | Result |
| --- | --- |
| `/`, `/index.html`, `/manifest.json`, `/main.dart.js`, `/flutter_bootstrap.js`, `/favicon.png`, `/icons/*`, `/version.json` | all **200** |
| Deep link (`/some/deep/link`) | **200** — the SPA rewrite works |
| Shell cache header | `Cache-Control: no-cache` |
| `<title>` | *Crumb & Cream — College Bakery Ordering* |
| Manifest | correct name, `#FF6F61` theme, 4 icons |
| Flutter engine boot (headless Chrome) | mounts (`flutter-view`, `flt-glass-pane`); CanvasKit loads |
| JS console during boot | **no** Firebase or JS errors |
| Sign-in from the live origin, using the Web app key | student **and** bakery accounts both authenticate |
| Build gates | `flutter analyze` clean; `flutter test` **69/69** |

### Not verified from the build machine

Rendered pixels and the on-screen install prompt. The agent environment cannot
read Flutter's canvas output, so the visual landing page and Chrome's
"Install app" affordance should be confirmed once on a real phone.
