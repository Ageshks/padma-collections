# Privacy Policy & Account Deletion

Static pages required by Google Play, served from Firebase Hosting.

| Page | File | Play Console field |
| --- | --- | --- |
| Privacy Policy | `privacy-policy.html` | **App content → Privacy policy** |
| Delete Account | `delete-account.html` | **App content → Data safety → Data deletion → Web URL** |

## Deploy

```bash
# Host only. Do NOT run a bare `firebase deploy` — it would also try to
# deploy Cloud Functions, which this project cannot do on the Spark plan.
firebase deploy --only hosting
```

The pages will be live at:

```
https://padma-cb65f.web.app/privacy-policy.html
https://padma-cb65f.web.app/delete-account.html
```

Replace `padma-cb65f` if the project ID changes, and point `padmacollections.com`
at the same Hosting site to serve them from your own domain.

Firebase Hosting works on the free Spark plan (10 GB storage, 10 GB/month
transfer), which is why these pages are hosted here rather than on the app's
Cloud Functions — those cannot be deployed on Spark.

## Editing

Both pages are plain self-contained HTML with inline CSS and no scripts, no
cookies and no external requests. Edit the text directly and redeploy.

Two details to keep accurate:

- **Contact details** — email `hello@padmacollections.com` and the Bengaluru
  shop address appear on both pages. Update both if either changes.
- **The "Last updated" date** is a literal string in each file. Bump it whenever
  the policy substantively changes; section 12 promises users it will be.

## Why the content is what it is

The privacy policy is written from what the app actually does, verified against
the code rather than from boilerplate:

| Claim | Verified from |
| --- | --- |
| Email + Google sign-in, no phone sign-in | `auth_repository.dart` |
| Name, email, phone, address on orders | `user_model.dart`, `order_model.dart` |
| Cart and wishlist stored per account | `cart_repository.dart`, `wishlist_repository.dart` |
| **No** card/UPI data collected | no payment SDK anywhere in `lib/` |
| Order details sent to WhatsApp only on tap | `whatsapp_service.dart`, `checkout_view.dart` |
| No location, camera, contacts, ads | `AndroidManifest.xml` requests only INTERNET, ACCESS_NETWORK_STATE, POST_NOTIFICATIONS |
| Crash + analytics data collected | `firebase_bootstrap.dart` |

**If any of that changes, the policy and the Play Data Safety form must change
with it.** Google compares your declaration against observed app behaviour and
can act on discrepancies, so an over- or under-declared Data Safety form is a
policy risk in itself.

## Deletion requests

The pages instruct users to email a request. That satisfies Play's requirement
for a *web* mechanism, but it is only honest if someone actually actions the
email. Play separately requires an **in-app** path to request deletion, which the
app does **not** currently have — see the note in the handover summary.
