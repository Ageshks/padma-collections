# Padma Collections

A Flutter storefront for a jewellery store, backed by Firebase.

- **Customer app** — browse the catalogue, manage a cart and wishlist, place an
  order request, and confirm it over WhatsApp. There is no payment gateway by
  design: the order is written to Firestore first, then confirmed with the seller.
- **Admin app** — the same build, split at the login screen by the `role` field
  on the user's Firestore profile.

---

## Firebase

The app is permanently wired to the live project **`padma-cb65f`**. There is no
demo fallback: if Firebase cannot start, the app shows a blocking retry screen
rather than serving invented stock levels or fake orders.

| Service | Status |
| --- | --- |
| Authentication (email/password + Google) | Enabled |
| Cloud Firestore | Enabled, `asia-south1` |
| Cloud Functions | Enabled, `asia-south1` |
| Cloud Messaging (FCM) | Wired |
| Analytics | Enabled |
| Crashlytics | Enabled (release builds only) |
| App Check (Play Integrity) | Enabled |

### Images: Cloudinary

All product, category, banner and logo imagery is stored and delivered by
**Cloudinary**. Firebase Storage is not used and its rules have been deleted —
it cannot be deployed anyway, because the project is on the Spark (free) plan,
which cannot create a Cloud Storage bucket.

The app POSTs compressed image bytes **directly** to Cloudinary using an
**unsigned upload preset**:

```text
Admin app → Cloudinary /image/upload (multipart, unsigned preset)
          → public id + secure URL
          → Firestore (metadata only)
```

No API key or secret is ever in the app, in Firestore, or in git.

**This is a deliberate trade-off.** Cloud Functions require the Blaze plan and
this project is on Spark, so a signing backend cannot be deployed. The cost is
that uploads are unauthenticated — the preset name ships inside the APK, so
anyone who extracts it can push files into the Cloudinary account. That blast
radius is contained by the **preset configuration in the Cloudinary dashboard**
(fixed folder, format allowlist, max file size), which is the real security
boundary.

**The app cannot delete images.** Cloudinary's delete endpoint always requires
the API secret and has no unsigned equivalent, so removed and replaced images
leave their assets behind in the Media Library. Firestore is updated correctly,
so customers never see a stale image — orphans only cost storage, and are swept
manually.

Full setup, the preset hardening table, the cleanup routine, and the steps to
move to a signed backend once the plan justifies it:
**[docs/cloudinary-images.md](docs/cloudinary-images.md)**. One-time setup:

```bash
# 1. Create an unsigned preset in the Cloudinary dashboard, then:
#    set both fields on settings/app in Firestore
#      cloudinaryCloudName    = "<your cloud name>"
#      cloudinaryUploadPreset = "<preset name>"
#    (both are read at runtime, so neither needs an app release)
```

Delivery URLs are
`https://res.cloudinary.com/{CLOUD}/image/upload/{transform}/{PUBLIC_ID}`. Only
the public id is stored; the transformation is chosen at render time, so a
product card loads a 500px image and the detail gallery loads 1200px from the
same record. `f_auto` lets Cloudinary serve AVIF or WebP where supported.


### Platform support: Android only

Only an Android app (`com.padmacollections.app`) is registered. `currentPlatform`
throws a clear, actionable error on any other platform rather than failing
silently at the first query. To add iOS:

```
firebase apps:create IOS com.padmacollections.app
flutterfire configure
```

### Admin provisioning

`firestore.rules` deliberately blocks a user from promoting themselves, and
blocks anyone but an admin from creating a second admin. Both are correct — that
is what stops a customer account from reaching the admin app. The side effect is
that the **first** admin cannot be created from inside the app, so it is
provisioned out of band:

```
python3 tool/provision_admin.py            # creates the credential + admin role
python3 tool/verify_admin_login.py <email> <password>   # end-to-end check
```

`provision_admin.py` creates the Firebase Auth credential with the public API key
(no service account needed), then writes `users/{uid}` with `role: 'admin'`.
The generated password is printed once and stored nowhere.

### Making an *existing* account an admin

If the person has already signed in, promote their account instead — this
reuses their existing password, so there is no new credential to hand over:

```bash
python3 tool/provision_admin.py --promote you@example.com
```

The tool promotes **every** profile matching that email, which matters because
Firebase does not auto-link a Google sign-in with an email/password sign-in.
Someone who has used both ends up with two separate `users/{uid}` documents, and
promoting only one would leave the other sign-in method silently signed in as a
customer. Re-running is safe; profiles that are already admins are skipped.

**Sign out and back in afterwards** — the app reads the role when it loads the
profile, so a session opened before the promotion still has the old role cached.

**Change the password after first login.** The Admin Sign In screen at
`/admin/login` checks the Firestore role and falls back to the customer app for
anyone who is not an admin, so a leaked credential cannot reach the admin UI —
but the account is still a real credential, so rotate it.

> There is an older account, `admin@padmacollection.com` (singular), whose
> password is unknown. It has an admin profile but is effectively locked out.
> Delete it in the Firebase console when convenient.

---

## Tooling

All commands run from the repository root.

### Seed the catalogue

The seed is generated from the app's own models, so a field can never drift
between what is stored and what the app expects.

```
flutter test test/tools/export_seed_test.dart   # writes tool/seed_data.json
python3 tool/seed_firestore.py                  # uploads it (12 categories, 31 products)
```

`--force` overwrites existing documents; `--provision-only` skips the catalogue.

### Regenerate indexes

Indexes are generated from the queries the app actually issues, so a new query
shows up as a diff here instead of a production `FAILED_PRECONDITION`.

```
python3 tool/generate_indexes.py
firebase deploy --only firestore:indexes
```

### Test the security rules

Rules are the only thing between the catalogue and anyone who reverse-engineers
the app, so every guarantee has a test. The suite runs against the emulator,
because a live project cannot prove that a rule still *blocks* something.

```
./tool/run_rules_tests.sh     # 48 tests
```

Requires a JDK 21+ for the emulator; the script finds one, or tells you to run
`brew install openjdk@25`.

### Deploy everything

```
firebase deploy --only firestore:rules,firestore:indexes
```

Note there is no `functions` target. Cloud Functions require the Blaze plan and
this project is on Spark, so `functions/` cannot be deployed — it is retained
only as the ready-to-use signed backend for when the plan is upgraded. Image
uploads do not depend on it.

### Cloud Functions (not currently deployed)

```
cd functions && npm install && npm test     # unit tests, no emulator needed
```

These tests still pass and are worth keeping green. The code holds the signed
upload/delete implementation that replaces the unsigned preset path once Blaze
is enabled — see the migration steps in
[docs/cloudinary-images.md](docs/cloudinary-images.md).

---

## Android release builds

Release signing is read from `android/key.properties`, which is **git-ignored**:

```properties
storeFile=upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Without that file the release build still succeeds (debug-signed) so it can be
smoke-tested, but the artifact would be rejected by the Play Store.

`android/app/proguard-rules.pro` keeps the classes that R8 cannot see through
reflection — without them Google Sign-In works in debug and fails in release.

---

## Getting Started

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter online documentation](https://docs.flutter.dev/)

