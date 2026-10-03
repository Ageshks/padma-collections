# Cloudinary

Padma Collections stores and delivers **all** product, category, banner and logo
imagery through [Cloudinary](https://cloudinary.com/documentation). Firebase
Storage is not used and its rules have been deleted — it cannot be deployed
anyway, because the project is on the Spark (free) plan.

---

## Current architecture: direct unsigned uploads

```text
Admin app → Cloudinary /image/upload  (multipart, unsigned preset)
         → public id + secure URL → Firestore
```

The Flutter app POSTs compressed image bytes **straight to Cloudinary**. There is
no Cloud Function in this path.

### Why it is built this way

Cloud Functions require the **Blaze** plan. `padma-cb65f` is on Spark
(`billingEnabled: false`), so the signed-upload Cloud Function built earlier
cannot be deployed at all. An unsigned upload preset needs no server and no
billing plan, which makes it the only option that works today.

A signed backend is strictly the more secure design, and `functions/` still
contains a complete, tested implementation of it. It becomes the right choice
the moment the plan is upgraded — see [Moving to a signed backend](#moving-to-a-signed-backend).

---

## The trade-off you are accepting

**Read this before changing anything about uploads.**

An unsigned preset means uploads are **unauthenticated**. The preset name ships
inside the APK, so anyone who unzips the app can extract it and push arbitrary
files into this Cloudinary account, at your expense.

This is contained entirely by the **preset configuration in the Cloudinary
dashboard** — not by the app. The dashboard settings *are* the security
boundary. Configure the preset exactly as below and keep it that way:

| Preset setting | Value | Why |
| --- | --- | --- |
| `unsigned` | `true` | Required — this is what authorises the app. |
| `folder` | `padma_collections` | Uploads cannot land outside your own folder. |
| `allowed_formats` | `jpg,png,webp` | Blocks PDFs, videos, SVGs, etc. |
| `max_file_size` | `10485760` (10 MB) | Caps what one upload can cost. |
| `tags` | *(forced)* `padma` | Makes stray uploads easy to find and sweep. |

The app independently re-checks the extension and the byte size before
uploading, but those client-side checks are a convenience, not a control —
anyone bypassing them still hits the preset's limits.

### The second consequence: deletion is impossible

Cloudinary's Admin API `destroy` endpoint **always requires the API secret**,
and there is no unsigned equivalent. An upload preset authorises uploads only.

So while this architecture is in place, **the app cannot delete images**. Every
image an admin removes or replaces leaves its asset behind in the Media Library,
still consuming storage and bandwidth. Firestore is updated correctly, so
customers never see a removed image — the orphaned file is just invisible.

This is a known, accepted, temporary gap. It is recorded in code as
`CloudinaryConfig.canDeleteRemotely == false`, and the delete helpers are
documented no-ops rather than pretending to work.

---

## Setup

### 1. Create the unsigned upload preset

Cloudinary Dashboard → **Settings → Upload presets → Add upload preset**, using
the table above. Name it something recognisable (e.g. `padma_unsigned`).

### 2. Note your cloud name

Cloudinary Dashboard → **Settings → API Keys**. The cloud name appears in every
delivery URL — it is public, not a secret.

### 3. Set the two fields in Firestore

```bash
firebase firestore:settings:set --project padma-cb65f \
  cloudinaryCloudName="<your cloud name>" \
  cloudinaryUploadPreset="<preset name>"
```

Or edit `settings/app` in the Firebase console. Both fields are read at runtime,
so they can be changed later **without shipping an app update** — which is how
you would rotate a leaked preset name.

### 4. Verify

1. Sign in as an admin, open a product, and add an image.
2. Confirm it appears in the gallery and renders.
3. Cloudinary Dashboard → **Media Library** → `padma_collections/products/…`:
   the file should be there with a unique suffix on its name.
4. Confirm it is tagged `padma` and `products`.

---

## Folder structure

Assets are organised by type, and products additionally get a per-product folder:

```text
padma_collections/
├── products/{productId}/{file}-{suffix}   ← up to 8 per product
├── categories/{categoryId}/{file}-{suffix}
├── banners/{file}-{suffix}
└── store/{file}-{suffix}
```

The per-product folder exists so that, once signed deletes are available,
clearing a product's images is a single prefix operation rather than a walk over
ids. Keep it even while deletes are manual — it makes sweeping orphans trivial.

`{suffix}` is appended client-side. The Cloud Function set
`overwrite: false, unique_filename: true`, but neither parameter may be sent on an
unsigned upload, so the app generates the uniqueness itself. This prevents
re-uploading a same-named file from silently overwriting an image another
product still references.

---

## Manual cleanup

Because the app cannot delete, assets accumulate. Sweep them periodically:

1. Cloudinary Dashboard → **Media Library**.
2. Every app upload is tagged `padma`. Filter by that tag.
3. Anything under `padma_collections/` that is **not** referenced by a Firestore
   product, category, banner or `settings/app.logoImage` is an orphan and can be
   deleted.

Per-product orphans are easy to spot: they live in
`padma_collections/products/{productId}/`, and the product id tells you exactly
what they belonged to.

---

## Moving to a signed backend

Upgrade the Firebase project to the **Blaze** plan, then:

```bash
firebase functions:secrets:set CLOUDINARY_API_SECRET
firebase deploy --only functions
```

Then, in the app:

1. In `lib/core/services/cloudinary_image_service.dart`, change `uploadOne` to
   call the `uploadImageToCloudinary` callable instead of POSTing to Cloudinary.
   Everything else works off the returned map and needs no change.
2. Point `deleteImage`, `deleteImages` and `deleteProductImages` back at the
   `deleteImageFromCloudinary` and `deleteProductImagesFromCloudinary` callables.
   Their signatures were kept stable for exactly this reason.
3. Flip `CloudinaryConfig.canDeleteRemotely` to `true`.

That closes the open-upload-pipe and restores real deletion. The
`cloudinaryUploadPreset` field in `settings/app` can be left in place or cleared.

The signed path is strictly better: uploads are verified against
`users/{uid}.role == 'admin'` and `users/{uid}.isActive == true` server-side, and
the preset name stops being a usable credential.

---

## Folder structure

---

## Delivery

```text
https://res.cloudinary.com/{CLOUD}/image/upload/{TRANSFORMATION}/{PUBLIC_ID}.{FORMAT}
```

Only the public id is stored in Firestore. The transformation is chosen at render
time:

| Transformation | Size | Used for |
| --- | --- | --- |
| `c_fill,w_200,h_200,q_auto,f_auto` | 200 × 200 | Wishlist rows, cart rows, admin grid |
| `c_fill,w_500,h_500,q_auto,f_auto` | 500 × 500 | Home rails, category listings, search |
| `c_fill,w_1200,h_1200,q_auto,f_auto` | 1200 × 1200 | Product detail gallery and zoom |
| `c_fill,w_1600,h_700,q_auto,f_auto` | 1600 × 700 | Home and promotional carousel |
| `q_auto,f_auto` | original | Store logo (must keep its aspect ratio) |

`q_auto` picks a quality per image, and `f_auto` lets Cloudinary serve AVIF or
WebP where the client supports them, falling back to the stored format
otherwise. These are declared once in `CloudinaryTransform`
(`lib/core/constants/cloudinary_config.dart`).

### What Firestore stores

Metadata only — never image bytes:

```json
{
  "publicId": "padma_collections/products/PC-NK-001/necklace",
  "secureUrl": "https://res.cloudinary.com/demo/image/upload/.../necklace.jpg",
  "resourceType": "image",
  "format": "jpg",
  "width": 1600,
  "height": 1600,
  "isPrimary": true,
  "sortOrder": 0,
  "createdAt": "Timestamp"
}
```

Categories (`categories/{id}.image`), banners (`banners/{id}.image`) and the logo
(`settings/app.logoImage`) use the same nested shape.

### Legacy documents

Documents written before this migration stored bare URL strings
(`"images": ["https://…"]`). Those still parse: a string becomes an *external*
image with an empty `publicId`, which renders from the stored URL and offers no
re-upload or delete actions. Nothing breaks; re-uploading through the admin
migrates a product to Cloudinary-native metadata.

---

**Images upload before the document is written.** The admin form uploads first,
then saves the product, so a product is never saved pointing at an image that
failed to upload. A failed upload offers a retry that re-sends only the files
that failed. This ordering matters more than usual now: the image bytes are gone
from the device once the upload completes, so a save that somehow skipped the
upload could not be recovered locally.

**Firestore is the single source of truth for what is shown.** Even though
Cloudinary assets can linger, nothing stale is ever displayed: every read path
resolves images through the document. Orphans cost storage, never correctness.

**Products are capped at 8 images.** Enforced in the admin form and mirrored in
`CloudinaryConfig.maxProductImages`.

**Deactivated products keep their images.** A product set to `isActive: false`
can be restored, so its images stay. A permanent delete removes the document;
its assets become orphans for the manual sweep.

---

## Pre-deployment checklist

- [ ] Cloudinary account active, billing plan matches expected volume
- [ ] An unsigned upload preset exists, configured per the table in
      [The trade-off you are accepting](#the-trade-off-you-are-accepting)
- [ ] `settings/app.cloudinaryCloudName` is set
- [ ] `settings/app.cloudinaryUploadPreset` is set
- [ ] Admin sign-in → upload → image appears on the storefront
- [ ] Multiple images upload, reorder, and set a primary
- [ ] Removing an image updates the storefront (Cloudinary asset is **expected**
      to remain — this is not a bug)
- [ ] Category, banner and logo upload work
- [ ] An unsupported file is rejected with a readable message
- [ ] Customer app loads images over a slow connection
- [ ] `./tool/run_rules_tests.sh` passes
- [ ] `cd functions && npm test` passes
- [ ] `flutter test` passes
- [ ] No Cloudinary **secret** appears in the built APK

### Not checkable yet

These require the Blaze plan and a deployed function, so they cannot pass on
Spark. Revisit after upgrading:

- [ ] A customer account is refused an upload (`permission-denied`)
- [ ] A deactivated admin is refused
- [ ] Image deletion and replacement both remove the Cloudinary asset


Uploads are organised so the Media Library is navigable and cleanup is a prefix
operation rather than a hunt through thousands of files:

```text
padma_collections/
├── products/{productId}/      one folder per product
├── categories/{categoryId}/    one folder per category
├── banners/                    flat — one list of carousel art
└── store/                      flat — the logo
```

A public id looks like `padma_collections/products/PC-NK-001/necklace`. The
extension is deliberately excluded: the format is stored separately and
re-attached at delivery time, which is what lets `f_auto` switch formats per
client.
