'use strict';

/**
 * Unit tests for the Cloudinary helper module.
 *
 * These cover the pure logic — folder construction, public-id sanitisation and
 * the configuration guard — with no network and no credentials. The admin
 * authorization path is covered by the Firestore-rules suite plus the emulator
 * callable tests.
 *
 * Run: npm test
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  ROOT_FOLDER,
  FOLDERS,
  config,
  folderFor,
  publicFolderFor,
  publicIdFor,
  toMetadata,
  MAX_UPLOAD_BYTES,
  MAX_DIMENSION,
  ALLOWED_FORMATS,
} = require('../lib/cloudinary');

test('every asset type lives under the store root folder', () => {
  assert.equal(ROOT_FOLDER, 'padma_collections');
  for (const folder of Object.values(FOLDERS)) {
    assert.ok(folder.startsWith('padma_collections/'), `${folder} is outside root`);
  }
});

test('folderFor maps each asset type to its folder', () => {
  assert.equal(folderFor('products'), 'padma_collections/products');
  assert.equal(folderFor('categories'), 'padma_collections/categories');
  assert.equal(folderFor('banners'), 'padma_collections/banners');
  assert.equal(folderFor('store'), 'padma_collections/store');
});

test('folderFor rejects an unknown asset type', () => {
  assert.throws(() => folderFor('secrets'), /Unknown image type/);
});

test('products and categories get a per-entity sub-folder', () => {
  // Per-product folders make cleanup a prefix operation in the Media Library.
  assert.equal(
    publicFolderFor('products', 'PC-NK-001'),
    'padma_collections/products/PC-NK-001',
  );
  assert.equal(
    publicFolderFor('categories', 'necklaces'),
    'padma_collections/categories/necklaces',
  );
});

test('banners and the logo share a flat folder', () => {
  assert.equal(publicFolderFor('banners'), 'padma_collections/banners');
  assert.equal(publicFolderFor('banners', 'ignored'), 'padma_collections/banners');
  assert.equal(publicFolderFor('store'), 'padma_collections/store');
});

test('entity ids cannot escape the store folder', () => {
  // Path traversal in a folder name would write outside padma_collections/.
  const folder = publicFolderFor('products', '../../etc/passwd');
  assert.ok(folder.startsWith('padma_collections/products/'));
  assert.ok(!folder.includes('..'));
});

test('publicIdFor strips the extension and unsafe characters', () => {
  // The extension is re-attached at delivery time, which is what lets f_auto
  // negotiate a modern format per client.
  assert.equal(
    publicIdFor('padma_collections/products/p1', 'My Necklace.jpg'),
    'padma_collections/products/p1/My_Necklace',
  );
  assert.equal(
    publicIdFor('padma_collections/products/p1', 'a/b\\c*d.png'),
    'padma_collections/products/p1/a_b_c_d',
  );
});

test('publicIdFor never returns an empty name', () => {
  assert.equal(
    publicIdFor('padma_collections/store', '...'),
    'padma_collections/store/image',
  );
});

test('toMetadata keeps only the public, non-secret fields', () => {
  const metadata = toMetadata({
    public_id: 'padma_collections/products/p1/a',
    secure_url: 'https://res.cloudinary.com/demo/image/upload/x.jpg',
    insecure_url: 'http://res.cloudinary.com/demo/image/upload/x.jpg',
    resource_type: 'image',
    format: 'jpg',
    width: 1200,
    height: 1600,
    bytes: 2048,
    // Cloudinary echoes these back; they must never be persisted or returned.
    api_key: 'should-not-be-stored',
    signature: 'should-not-be-stored',
  });

  assert.deepEqual(metadata, {
    publicId: 'padma_collections/products/p1/a',
    secureUrl: 'https://res.cloudinary.com/demo/image/upload/x.jpg',
    resourceType: 'image',
    format: 'jpg',
    width: 1200,
    height: 1600,
    bytes: 2048,
  });

  // HTTPS only, and no credentials anywhere in the payload.
  assert.ok(metadata.secureUrl.startsWith('https://'));
  assert.ok(!JSON.stringify(metadata).includes('should-not-be-stored'));
});

test('toMetadata coerces missing dimensions to zero', () => {
  const metadata = toMetadata({ public_id: 'p', secure_url: 'https://s' });
  assert.equal(metadata.width, 0);
  assert.equal(metadata.height, 0);
  assert.equal(metadata.resourceType, 'image');
});

test('config throws when the API secret is missing', () => {
  const saved = { ...process.env };
  delete process.env.CLOUDINARY_API_SECRET;
  delete process.env.CLOUDINARY_API_KEY;
  delete process.env.CLOUDINARY_CLOUD_NAME;
  try {
    assert.throws(() => config(), /CLOUDINARY_API_SECRET/);
  } finally {
    Object.assign(process.env, saved);
  }
});

test('config returns all three values when everything is present', () => {
  const saved = { ...process.env };
  process.env.CLOUDINARY_CLOUD_NAME = 'demo';
  process.env.CLOUDINARY_API_KEY = 'key';
  process.env.CLOUDINARY_API_SECRET = 'secret';
  try {
    assert.deepEqual(config(), {
      cloudName: 'demo',
      apiKey: 'key',
      apiSecret: 'secret',
    });
  } finally {
    Object.assign(process.env, saved);
  }
});

test('accepted formats and limits match the documented policy', () => {
  assert.deepEqual(ALLOWED_FORMATS, ['jpg', 'jpeg', 'png', 'webp']);
  assert.equal(MAX_UPLOAD_BYTES, 10 * 1024 * 1024);
  assert.equal(MAX_DIMENSION, 6000);
});
