# Google Sign-In Setup — Padma Collections

Google Sign-In is wired end to end in code **and configured for project
`padma-cb65f`**. The Google provider is enabled and the Web client id below is
in place, so the button appears on the login screen.

> This used to hide the button until `flutterfire configure` had been run.
> The project is configured now, so the button shows as soon as the plugin has
> initialised — which happens after the first frame, by design.

---

## 1. Connect a Firebase project

Done. `lib/data/firebase/firebase_options.dart` holds the real values and
`android/app/google-services.json` is committed.

There is no demo fallback any more: if Firebase fails to start, the app shows a
blocking retry screen rather than serving a fake catalogue.

---

## 2. Enable the Google provider

Firebase console → **Authentication** → **Sign-in method** → **Google** → Enable.

Leave the default support email; Google assigns it automatically.

---

## 3. Add the Web client ID

`flutterfire configure` does **not** create an OAuth web client. Copy it from
Firebase console → **Project settings** → **Your apps** → **Web app** →
**SDK setup and configuration** → *Web client ID*:

```
000000000000-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com
```

Paste it into `lib/data/firebase/firebase_options.dart`:

```dart
static const String webClientId =
    '000000000000-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com';
```

**Android cannot work without this** — it is the `serverClientId` that links the
app back to your Firebase project.

---

## 4. Android — register the SHA-1/SHA-256 fingerprints

Google rejects Android sign-in unless the signing fingerprint is known.

The **debug** fingerprint is already registered — it is the one in
`google-services.json`:

```
F9:06:45:BE:71:85:C4:F2:7D:C2:BE:E4:1E:D8:5E:DA:C0:1C:A3:D4
```

The **release** fingerprint is not, because the upload keystore does not exist
yet. Create it before the first release build and register it, otherwise Google
Sign-In will work in debug and fail in production:

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload

keytool -list -v -keystore android/app/upload-keystore.jks
```

Paste the SHA-1 and SHA-256 into
Firebase console → **Project settings** → **Your apps** → **Android app**.

Already applied in this project:

- `minSdk` raised to **23** (Google Sign-In requires Android 6.0+)
- `com.google.gms.google-services` Gradle plugin applied
- `applicationId` / namespace set to `com.padmacollections.app`

### App Check is off in debug

App Check is activated in **release** builds only. Play Integrity cannot
validate a side-loaded debug APK, and the `debug` provider's token has to be
registered in the console before Firebase will accept it — until then it
silently breaks the Google Sign-In credential exchange. Since the Firestore and
Storage rules do not gate on App Check, it protects nothing locally.

---

## 5. iOS — URL scheme and bundle id

`ios/Runner/Info.plist` already declares a `CFBundleURLTypes` entry for
`com.padmacollections.app`. Replace it with your real Firebase iOS **client id**
(bundle id without `.appspot.com`) if they differ.

Then set the **bundle identifier** in Xcode to match
`com.padmacollections.app`, and download the
`GoogleService-Info.plist` into `ios/Runner/`.

---

## 6. Deploy the rules

```bash
firebase deploy --only firestore:rules,storage:rules
```

`firestore.rules` already enforces the guarantee that matters most for Google
users: a new profile may **only** be created with `role: 'customer'`, and only
for the caller's own uid. A customer can never set their own role to `admin`,
and Google Sign-In is bound by exactly the same rule as email/password.

---

## How it is wired

| Layer | File | Role |
|---|---|---|
| Plugin adapter | `lib/core/services/google_sign_in_service.dart` | `GoogleAuthClient` interface + `GoogleSignInClient` (real) |
| Service | same file | init once, friendly errors, availability check |
| Repository | `lib/data/repositories/auth_repository.dart` | exchanges token via `GoogleAuthProvider.credential`, creates/reuses profile |
| Controller | `lib/modules/common/controllers/app_controller.dart` | `signInWithGoogle()`, routes by role |
| UI | `lib/modules/auth/login_view.dart` + `lib/core/widgets/google_sign_in_button.dart` | button, divider, loading state |

The button is only rendered when `isSupported` is true, so an unconfigured
build never shows a dead control.

## Verified

- 14 unit tests cover init-once, `serverClientId` forwarding, success, missing
  token, unsupported platform, exception mapping, and sign-out resilience.
- `firestore.rules` and `storage.rules` both load without compile errors in the
  Firebase emulator.