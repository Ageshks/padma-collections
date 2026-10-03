'use strict';

/**
 * Cloudinary configuration and upload helpers.
 *
 * IMPORTANT — where these values live:
 *
 *   CLOUDINARY_API_SECRET   Firebase Secret Manager ONLY. This is the credential
 *                           that makes a Cloudinary write possible, so it must
 *                           never appear in the Flutter app, in Firestore, in a
 *                           committed `.env`, in git, or in the APK/IPA. It is
 *                           injected at runtime by the Firebase runtime and is
 *                           readable only by this process.
 *   CLOUDINARY_API_KEY      Identifies the account for a signed upload. Paired
 *                           with the secret to sign requests, so it is treated
 *                           as server-side too — shipping it would be half a
 *                           credential.
 *   CLOUDINARY_CLOUD_NAME   Public: it appears in every delivery URL the app
 *                           loads. The Flutter app reads it from `settings/app`
 *                           rather than hardcoding it, so the Cloudinary account
 *                           can be moved without shipping an app release.
 *
 * Values are read through `process.env` at *call* time, not at module load, so
 * a redeploy with a rotated secret takes effect immediately.
 */

const { v2: cloudinary } = require('cloudinary');

/**
 * Root folder for every asset. Keeping the store's media under one prefix
 * makes the Cloudinary Media Library navigable and allows a single deletion
 * sweep to target Padma Collections without touching anything else in the
 * account.
 */
const ROOT_FOLDER = 'padma_collections';

/** Sub-folder per asset type. */
const FOLDERS = {
  products: `${ROOT_FOLDER}/products`,
  categories: `${ROOT_FOLDER}/categories`,
  banners: `${ROOT_FOLDER}/banners`,
  store: `${ROOT_FOLDER}/store`,
};

/**
 * Formats we accept. Cloudinary supports more, but the app only ever sends
 * raster photography, and narrowing the list keeps a surprising upload (a PDF,
 * an MP4) from being accepted by the server when the client check is bypassed.
 */
const ALLOWED_FORMATS = ['jpg', 'jpeg', 'png', 'webp'];

/** MIME types the client may declare. */
const ALLOWED_CONTENT_TYPES = [
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
];

/**
 * Hard ceiling on an uploaded file, in bytes.
 *
 * The client compresses to 1600px before sending, so legitimate catalogue
 * photography lands far below this. Anything larger is either a mistake or an
 * attempt to push something enormous through a metered pipeline.
 */
const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;

/**
 * Longest edge we accept, in pixels.
 *
 * Guards against a decompression-bomb style upload: a 20000x20000 PNG is a few
 * megabytes on the wire but gigabytes of memory once decoded.
 */
const MAX_DIMENSION = 6000;

/** Minimum edge. Rejects slivers and 1x1 spacers. */
const MIN_DIMENSION = 50;

/**
 * Reads and validates the Cloudinary environment configuration.
 *
 * @returns {{cloudName: string, apiKey: string, apiSecret: string}}
 * @throws {Error} when anything is missing — misconfiguration must fail loudly
 *   at call time rather than silently issuing unauthenticated requests.
 */
function config() {
  const cloudName = (process.env.CLOUDINARY_CLOUD_NAME || '').trim();
  const apiKey = (process.env.CLOUDINARY_API_KEY || '').trim();
  const apiSecret = (process.env.CLOUDINARY_API_SECRET || '').trim();

  const missing = [];
  if (!cloudName) missing.push('CLOUDINARY_CLOUD_NAME');
  if (!apiKey) missing.push('CLOUDINARY_API_KEY');
  if (!apiSecret) missing.push('CLOUDINARY_API_SECRET');

  if (missing.length) {
    throw new Error(
      `Cloudinary is not configured. Missing: ${missing.join(', ')}. ` +
        'Set the secret with `firebase functions:secrets:set CLOUDINARY_API_SECRET`.',
    );
  }

  return { cloudName, apiKey, apiSecret };
}

/**
 * Applies configuration to the SDK instance.
 *
 * Called immediately before each operation rather than once at module load, so
 * a rotated secret is picked up without a restart.
 */
function configure() {
  const cfg = config();
  cloudinary.config({
    cloud_name: cfg.cloudName,
    api_key: cfg.apiKey,
    api_secret: cfg.apiSecret,
    secure: true,
  });
  return cfg;
}

/**
 * Normalises an asset type into its Cloudinary folder.
 *
 * @param {string} type one of products | categories | banners | store
 * @returns {string}
 */
function folderFor(type) {
  const folder = FOLDERS[type];
  if (!folder) {
    throw new Error(
      `Unknown image type "${type}". Expected one of: ${Object.keys(FOLDERS).join(', ')}.`,
    );
  }
  return folder;
}

/**
 * Builds the public folder path for one asset.
 *
 * Products get their own sub-folder per product id and categories likewise, so
 * a product's images are a contiguous, obviously-owned group in the Media
 * Library rather than scattered across thousands of unrelated files.
 *
 * Banners and the logo are deliberately **not** scoped per entity: the spec
 * keeps them in a flat `padma_collections/banners/` and `…/store/` folder, so
 * the Media Library shows one tidy list rather than a folder per banner. An
 * `entityId` supplied for those types is ignored.
 *
 * @param {string} type asset type
 * @param {string} [entityId] productId or categoryId; ignored for flat folders
 * @returns {string}
 */
function publicFolderFor(type, entityId) {
  const base = folderFor(type);
  if (!entityId) return base;
  // Only these two types get a per-entity sub-folder.
  if (type !== 'products' && type !== 'categories') return base;
  // Strip anything that could escape the folder or confuse the Media Library.
  const safe = String(entityId).replace(/[^A-Za-z0-9_-]/g, '_');
  if (!safe) return base;
  return `${base}/${safe}`;
}

/**
 * Builds the public id for a new asset.
 *
 * Cloudinary keeps the file's own extension out of the public id; the format is
 * stored separately and re-attached at delivery time, which is what lets
 * `f_auto` negotiate a modern format per client.
 *
 * @param {string} folder target folder
 * @param {string} name caller-supplied name, usually the original filename
 * @returns {string}
 */
function publicIdFor(folder, name) {
  const base = String(name || 'image')
    .replace(/\.[A-Za-z0-9]+$/, '')
    .replace(/[^A-Za-z0-9_-]/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '')
    .slice(0, 60);
  return `${folder}/${base || 'image'}`;
}

/**
 * Uploads a base64 image to Cloudinary.
 *
 * The bytes arrive from the admin app already compressed; the caller re-checks
 * the declared facts server-side because a client check is a convenience, not
 * a control.
 *
 * @param {object} options
 * @param {string} options.dataUrl base64 data URL or bare base64 payload
 * @param {string} options.folder target folder
 * @param {string} options.name original filename
 * @returns {Promise<object>} the raw Cloudinary upload result
 */
async function upload({ dataUrl, folder, name }) {
  configure();

  return cloudinary.uploader.upload(dataUrl, {
    folder,
    public_id: publicIdFor(folder, name),
    resource_type: 'image',
    // A unique public id per upload avoids silently replacing a photo the admin
    // is still editing; replacing an image is a separate, explicit action.
    overwrite: false,
    unique_filename: true,
    invalidate: true,
  });
}

/**
 * Deletes an asset by public id.
 *
 * @param {string} publicId
 * @returns {Promise<{result: string}>} Cloudinary answers `result: 'ok'`, or
 *   `'not found'` when the asset was already gone.
 */
async function destroy(publicId) {
  configure();
  return cloudinary.uploader.destroy(publicId, {
    resource_type: 'image',
    invalidate: true,
  });
}

/**
 * Reduces a Cloudinary upload result to what Firestore should store.
 *
 * Deliberately excludes anything sensitive — the API key and signature are not
 * part of the response, but this keeps the stored shape explicit and small.
 *
 * @param {object} result
 * @returns {{publicId: string, secureUrl: string, resourceType: string,
 *   format: string, width: number, height: number, bytes: number}}
 */
function toMetadata(result) {
  return {
    publicId: result.public_id || '',
    // secure_url is HTTPS; the insecure_url is never used or stored.
    secureUrl: result.secure_url || '',
    resourceType: result.resource_type || 'image',
    format: result.format || '',
    width: Number(result.width) || 0,
    height: Number(result.height) || 0,
    bytes: Number(result.bytes) || 0,
  };
}

module.exports = {
  ROOT_FOLDER,
  FOLDERS,
  ALLOWED_FORMATS,
  ALLOWED_CONTENT_TYPES,
  MAX_UPLOAD_BYTES,
  MAX_DIMENSION,
  MIN_DIMENSION,
  config,
  configure,
  folderFor,
  publicFolderFor,
  publicIdFor,
  upload,
  destroy,
  toMetadata,
};

