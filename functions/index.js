'use strict';

/**
 * Padma Collections — Cloudinary image gateway.
 *
 * The Flutter app never holds a Cloudinary credential. It authenticates with
 * Firebase, sends the image bytes here, and this function performs the signed
 * upload using the API secret from the runtime environment. The secret is never
 * returned to the client and never appears in the app.
 *
 * Functions:
 *   uploadImageToCloudinary              upload one image            (admin only)
 *   deleteImageFromCloudinary            delete one image by id      (admin only)
 *   deleteProductImagesFromCloudinary    delete a product's images   (admin only)
 *
 * See ../docs/cloudinary-images.md for the setup runbook.
 */

const { initializeApp } = require('firebase-admin/app');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const { getFirestore } = require('firebase-admin/firestore');

const {
  ALLOWED_CONTENT_TYPES,
  MAX_UPLOAD_BYTES,
  MAX_DIMENSION,
  MIN_DIMENSION,
  configure,
  publicFolderFor,
  upload,
  destroy,
  toMetadata,
} = require('./lib/cloudinary');
const { assertActiveAdmin } = require('./lib/auth');

initializeApp();

const REGION = 'asia-south1'; // matches the Firestore location.

/** Asset types this gateway accepts, and the folder each maps to. */
const ASSET_TYPES = ['products', 'categories', 'banners', 'store'];

/** Config or a user-safe `internal` error. */
function requireConfig() {
  try {
    return configure();
  } catch (error) {
    logger.error('Cloudinary configuration error', { error: String(error) });
    throw new HttpsError(
      'internal',
      'Image service is not configured. Please contact support.',
    );
  }
}

/**
 * Turns a Cloudinary failure into an `internal` error with a message that is
 * safe to show an admin.
 *
 * The raw Cloudinary error body is logged, never returned: it can contain
 * account identifiers and internal details that have no business in a
 * customer-facing app, and "Error 1010: The owner of the website has disabled
 * your browser's User-Agent" helps nobody fix a photo.
 *
 * @param {string} what short description of the attempted operation
 * @param {Error} error
 */
function cloudinaryFailure(what, error) {
  logger.error(`Cloudinary ${what} failed`, {
    error: String(error && error.message ? error.message : error),
  });

  const message = String((error && error.message) || '');
  if (/api key|unauthori/i.test(message)) {
    return new HttpsError(
      'internal',
      'Image service is not authorised. Please contact support.',
    );
  }
  if (/rate limit|too many/i.test(message)) {
    return new HttpsError(
      'resource-exhausted',
      'Too many uploads right now. Please wait a moment and try again.',
    );
  }
  if (/exceed|too large|dimensions/i.test(message)) {
    return new HttpsError('invalid-argument', message);
  }
  return new HttpsError(
    'internal',
    'The image service is temporarily unavailable. Please try again.',
  );
}

/**
 * Validates the request payload before any bytes are forwarded.
 *
 * Everything here is a *server-side* check. The client validates too, but the
 * client is not a control: a modified app can send anything, so the gateway
 * independently re-checks type, size and declared dimensions.
 *
 * @param {Record<string, unknown>} data
 * @returns {{image: string, type: string, entityId: string, contentType: string}}
 */
function validateUpload(data) {
  const contentType = String(data.contentType || '').toLowerCase();
  if (!ALLOWED_CONTENT_TYPES.includes(contentType)) {
    throw new HttpsError(
      'invalid-argument',
      'Unsupported image format. Please select JPG, PNG, or WEBP.',
    );
  }

  const type = String(data.type || '');
  if (!ASSET_TYPES.includes(type)) {
    throw new HttpsError(
      'invalid-argument',
      `\`type\` must be one of: ${ASSET_TYPES.join(', ')}.`,
    );
  }

  // The image itself: a base64 data URL, or a bare base64 payload.
  const raw = String(data.image || '');
  const image = raw.startsWith('data:') ? raw : `data:${contentType};base64,${raw}`;
  if (image.length < 32) {
    throw new HttpsError('invalid-argument', 'The image data was empty.');
  }

  // Base64 inflates by ~4/3, so the wire length is a proxy for the real size.
  // Checked before forwarding anything, so an oversized upload costs nothing.
  const approxBytes = Math.floor((raw.length * 3) / 4);
  if (approxBytes > MAX_UPLOAD_BYTES) {
    throw new HttpsError(
      'invalid-argument',
      `Image is too large. The maximum is ${Math.round(MAX_UPLOAD_BYTES / (1024 * 1024))} MB.`,
    );
  }

  const width = Number(data.width) || 0;
  const height = Number(data.height) || 0;
  if (width && height) {
    // Client-declared dimensions. Cloudinary rejects absurd sizes itself, but
    // checking here gives the admin an immediate, readable error.
    if (width > MAX_DIMENSION || height > MAX_DIMENSION) {
      throw new HttpsError(
        'invalid-argument',
        `Image is too large. The maximum is ${MAX_DIMENSION}px on each side.`,
      );
    }
    if (width < MIN_DIMENSION || height < MIN_DIMENSION) {
      throw new HttpsError('invalid-argument', 'That image is too small.');
    }
  }

  return {
    image,
    type,
    entityId: String(data.entityId || '').slice(0, 64),
    contentType,
  };
}

// ---------------------------------------------------------------------------
// uploadImageToCloudinary
// ---------------------------------------------------------------------------

/**
 * Uploads one image to Cloudinary on behalf of an authenticated admin.
 *
 * Flow:
 *   Admin app → this function (auth + role checked) → Cloudinary Images
 *   Cloudinary returns public_id + secure_url → this function → app
 *   App saves that metadata to Firestore alongside the product
 *
 * The response contains only the public id and delivery URL. The API key,
 * signature and secret never cross this boundary.
 */
exports.uploadImageToCloudinary = onCall(
  { region: REGION, enforceAppCheck: true, maxInstances: 10 },
  async (request) => {
    const uid = await assertActiveAdmin(request);
    const { image, type, entityId, contentType } = validateUpload(
      request.data || {},
    );

    const cfg = requireConfig();
    const folder = publicFolderFor(type, entityId);
    const name = String((request.data || {}).name || 'image');

    let result;
    try {
      result = await upload({ dataUrl: image, folder, name });
    } catch (error) {
      throw cloudinaryFailure('upload', error);
    }

    if (!result || !result.public_id || !result.secure_url) {
      logger.error('Cloudinary upload returned no public_id/secure_url', {
        folder,
      });
      throw new HttpsError(
        'internal',
        'The image service returned an unexpected response. Please try again.',
      );
    }

    const metadata = toMetadata(result);

    // Reject an image Cloudinary accepted but that violates our own dimension
    // floor. Deleting it immediately stops an unusable asset being billed and
    // keeps the catalogue clean.
    if (metadata.width && metadata.height && metadata.width < MIN_DIMENSION) {
      await destroy(metadata.publicId).catch(() => {});
      throw new HttpsError('invalid-argument', 'That image is too small.');
    }

    logger.info('Uploaded image to Cloudinary', {
      structuredData: {
        publicId: metadata.publicId,
        type,
        uid,
      },
    });

    return {
      ...metadata,
      // The cloud name is returned so the app can build delivery URLs without
      // having to know it in advance. It is public — it appears in every URL.
      cloudName: cfg.cloudName,
      contentType,
      uploadedAt: Date.now(),
    };
  },
);

// ---------------------------------------------------------------------------
// deleteImageFromCloudinary
// ---------------------------------------------------------------------------

/**
 * Deletes an image from Cloudinary.
 *
 * Returns `deleted: false` when the asset was already gone, so a retry after a
 * timeout is safe rather than an error.
 */
exports.deleteImageFromCloudinary = onCall(
  { region: REGION, enforceAppCheck: true },
  async (request) => {
    const uid = await assertActiveAdmin(request);
    const publicId = String((request.data || {}).publicId || '').trim();

    if (!publicId) {
      throw new HttpsError('invalid-argument', '`publicId` is required.');
    }
    // Only ever delete from our own folder. Without this an admin (or a
    // compromised admin session) could destroy assets belonging to another
    // project sharing the same Cloudinary account.
    if (!publicId.startsWith('padma_collections/')) {
      throw new HttpsError(
        'invalid-argument',
        'Refusing to delete an image outside the store folder.',
      );
    }

    requireConfig();

    let result;
    try {
      result = await destroy(publicId);
    } catch (error) {
      throw cloudinaryFailure('delete', error);
    }

    const deleted = result && result.result === 'ok';
    logger.info('Deleted image from Cloudinary', {
      structuredData: { publicId, deleted, uid },
    });
    return { deleted, publicId };
  },
);

// ---------------------------------------------------------------------------
// deleteProductImagesFromCloudinary
// ---------------------------------------------------------------------------

/**
 * Deletes every image belonging to a product.
 *
 * Used when a product is permanently removed so Cloudinary does not accumulate
 * orphaned assets. The product id is scoped to its folder, which is why
 * products are uploaded under `padma_collections/products/{productId}/`.
 *
 * Note the ordering rule this enforces for callers: delete Cloudinary first,
 * *then* remove the Firestore document. A leftover image costs storage; a
 * product document pointing at a deleted image breaks the storefront.
 */
exports.deleteProductImagesFromCloudinary = onCall(
  { region: REGION, enforceAppCheck: true },
  async (request) => {
    const uid = await assertActiveAdmin(request);
    const productId = String((request.data || {}).productId || '').trim();

    if (!productId) {
      throw new HttpsError('invalid-argument', '`productId` is required.');
    }

    requireConfig();

    const safeId = productId.replace(/[^A-Za-z0-9_-]/g, '_');
    const folder = `padma_collections/products/${safeId}`;

    try {
      // deleteResources removes the whole folder in one API call.
      const { v2: cloudinary } = require('cloudinary');
      const result = await cloudinary.api.delete_resources_by_prefix(
        folder,
        { resource_type: 'image', invalidate: true },
      );

      const deleted = Array.isArray(result.deleted) ? result.deleted.length : 0;
      logger.info('Deleted product images from Cloudinary', {
        structuredData: { folder, deleted, uid },
      });
      return { deleted, folder };
    } catch (error) {
      throw cloudinaryFailure('delete product images', error);
    }
  },
);

