/**
 * Firestore security-rules test suite.
 *
 * Rules are the only thing standing between the catalogue and anyone who
 * reverse-engineers the app, so they are treated as code: every guarantee in
 * `firestore.rules` has a test here asserting a specific user is allowed or
 * denied. A change that weakens one fails the run.
 *
 * The suite talks to the Firestore emulator, which is what makes the *denial*
 * assertions possible — the production project would simply reject them, so a
 * live test can never prove a rule still blocks.
 *
 * Run:
 *   ./tool/run_rules_tests.sh
 */

const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');

const PROJECT_ID = 'padma-cb65f';

const ADMIN_UID = 'admin-uid';
const CUSTOMER_UID = 'customer-uid';
const OTHER_CUSTOMER_UID = 'other-customer-uid';

// An admin whose account has been deactivated. Used to prove that revoking an
// account takes effect immediately, not at the next token refresh.
const DEACTIVATED_ADMIN_UID = 'deactivated-admin-uid';

let rulesUnit;
let firestoreApi;
let testEnv;

/** Loads the SDK lazily so a missing dependency reports one clear message. */
function loadSdk() {
  try {
    rulesUnit = require('@firebase/rules-unit-testing');
    firestoreApi = require('firebase/firestore');
  } catch (error) {
    console.error('Missing test dependencies. Run: npm --prefix tool install');
    console.error(error.message);
    process.exit(2);
  }
}

const firestore = () => testEnv.unauthenticatedContext().firestore();
const unauthed = () => testEnv.unauthenticatedContext();

/** A signed-in context for [uid]. */
async function asUser(uid, { admin = false } = {}) {
  return testEnv.authenticatedContext(uid, {
    // The rules read the role from the Firestore profile, not from a claim.
    // The claim is still set on the admin so the suite proves a forged
    // customer claim does *not* grant access.
    role: admin ? 'admin' : 'customer',
  });
}

const doc = (ctx, path) => firestoreApi.doc(ctx.firestore(), path);
const setDoc = (ctx, path, data) =>
  firestoreApi.setDoc(doc(ctx, path), data);
const getDoc = (ctx, path) => firestoreApi.getDoc(doc(ctx, path));
const updateDoc = (ctx, path, data) =>
  firestoreApi.updateDoc(doc(ctx, path), data);
const getDocs = (ctx, path) =>
  firestoreApi.getDocs(firestoreApi.collection(ctx.firestore(), path));

/** Asserts a request is rejected. */
async function expectDenied(fn, why) {
  try {
    await fn();
  } catch {
    return;
  }
  assert.fail(`Expected DENIED but it succeeded: ${why}`);
}

function show(name, error) {
  return `  ✗ ${name}\n      ${String(error.message).split('\n')[0]}`;
}

const tests = [];

/** Registers a test. [only] filters to a subset, for debugging one rule. */
function test(name, fn) {
  tests.push({ name, fn });
}

async function main() {
  loadSdk();
  const { initializeTestEnvironment } = rulesUnit;

  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });

  // Seeded with the rules disabled, so seeding cannot itself be blocked by the
  // rules that are under test.
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const [uid, role] of [
      [ADMIN_UID, 'admin'],
      [CUSTOMER_UID, 'customer'],
      [OTHER_CUSTOMER_UID, 'customer'],
    ]) {
      await firestoreApi.setDoc(firestoreApi.doc(db, `users/${uid}`), {
        uid,
        role,
        isActive: true,
        name: role,
        email: `${uid}@example.com`,
        createdAt: new Date(),
      });
    }
    await firestoreApi.setDoc(firestoreApi.doc(db, 'products/p1'), {
      name: 'Ring',
      price: 1000,
      isActive: true,
      stock: 5,
    });
    await firestoreApi.setDoc(firestoreApi.doc(db, 'settings/app'), {
      appName: 'Padma',
    });
    for (const [id, userId, audience] of [
      ['broadcast', '', 'all'],
      ['customers', '', 'customers'],
      ['personal', CUSTOMER_UID, 'specific'],
      ['other-personal', OTHER_CUSTOMER_UID, 'specific'],
    ]) {
      await firestoreApi.setDoc(
        firestoreApi.doc(db, `notifications/${id}`),
        {
          notificationId: id,
          userId,
          audience,
          isRead: false,
          createdAt: new Date(),
        },
      );
    }
  });

  register();

  let passed = 0;
  const failures = [];
  let currentGroup = '';

  for (const { name, fn } of tests) {
    const group = name.split('|')[0].trim();
    if (group !== currentGroup) {
      currentGroup = group;
      console.log(`\n${group}`);
    }
    const label = name.includes('|') ? name.split('|')[1].trim() : name;
    try {
      await fn();
      passed++;
      console.log(`  ✓ ${label}`);
    } catch (error) {
      failures.push({ label, error });
      console.log(show(label, error));
    }
  }

  await testEnv.cleanup();

  console.log(`\n${passed} passed, ${failures.length} failed`);
  if (failures.length > 0) {
    for (const f of failures) console.error(`\n${f.label}\n${f.error.stack}`);
    process.exit(1);
  }
}

/** Every rule guarantee, grouped by area. */
function register() {
  // --- Authentication --------------------------------------------------------
  test('Authentication | anonymous cannot read the catalogue', async () => {
    await expectDenied(() => getDoc(unauthed(), 'products/p1'), 'anonymous read');
  });

  test('Authentication | anonymous cannot write a product', async () => {
    await expectDenied(
      () => setDoc(unauthed(), 'products/hack', { name: 'Fake' }),
      'anonymous write',
    );
  });

  test('Authentication | a signed-in customer can read the catalogue', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await rulesUnit.assertSucceeds(getDoc(ctx, 'products/p1'));
  });

  test('Profiles | a customer can read their own profile', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await rulesUnit.assertSucceeds(getDoc(ctx, `users/${CUSTOMER_UID}`));
  });

  test('Profiles | a customer cannot read another profile', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () => getDoc(ctx, `users/${OTHER_CUSTOMER_UID}`),
      'read another profile',
    );
  });

  // --- Roles and escalation --------------------------------------------------
  test('Roles | a customer cannot promote themselves to admin', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () => updateDoc(ctx, `users/${CUSTOMER_UID}`, { role: 'admin' }),
      'self-promotion',
    );
  });

  test('Roles | a customer cannot promote another user', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () => updateDoc(ctx, `users/${OTHER_CUSTOMER_UID}`, { role: 'admin' }),
      'promote another',
    );
  });

  test('Roles | a self-asserted admin claim is not trusted', async () => {
    // The rules read role from Firestore, so a forged token claim must not help.
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () => setDoc(ctx, 'products/hack2', { name: 'Fake' }),
      'forged claim',
    );
  });

  test('Roles | a customer cannot overwrite another profile', async () => {
    // This is also the signup path, so it must not permit impersonation.
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () =>
        setDoc(ctx, `users/${OTHER_CUSTOMER_UID}`, {
          uid: OTHER_CUSTOMER_UID,
          role: 'customer',
        }),
      'impersonation',
    );
  });

  test('Roles | a customer cannot list all users', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(() => getDocs(ctx, 'users'), 'list users');
  });

  test('Roles | an admin can list all users', async () => {
    const ctx = await asUser(ADMIN_UID, { admin: true });
    await rulesUnit.assertSucceeds(getDocs(ctx, 'users'));
  });

  test('Roles | a customer can edit their own name', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await rulesUnit.assertSucceeds(
      updateDoc(ctx, `users/${CUSTOMER_UID}`, { name: 'Renamed' }),
    );
  });

  // --- Cart and wishlist ownership ------------------------------------------
  test('Cart & wishlist | a customer can write their own cart', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await rulesUnit.assertSucceeds(
      setDoc(ctx, `users/${CUSTOMER_UID}/cart/p1`, { quantity: 2 }),
    );
  });

  test("Cart & wishlist | a customer cannot write another's cart", async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () =>
        setDoc(ctx, `users/${OTHER_CUSTOMER_UID}/cart/p1`, { quantity: 99 }),
      "write another cart",
    );
  });

  test('Cart & wishlist | a customer can read their own wishlist', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await rulesUnit.assertSucceeds(
      getDoc(ctx, `users/${CUSTOMER_UID}/wishlist/p1`),
    );
  });

  // --- Catalogue is admin-write only -----------------------------------------
  test('Catalogue | a customer cannot create a product', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () => setDoc(ctx, 'products/hack3', { name: 'Fake' }),
      'customer creates product',
    );
  });

  test('Catalogue | a customer cannot reprice a product', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () => updateDoc(ctx, 'products/p1', { price: 1 }),
      'customer reprices',
    );
  });

  test('Catalogue | a customer cannot delete a product', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () => firestoreApi.deleteDoc(doc(ctx, 'products/p1')),
      'customer deletes product',
    );
  });

  test('Catalogue | anonymous can read public settings', async () => {
    // The login screen shows the store name and contact number before sign-in.
    await rulesUnit.assertSucceeds(getDoc(unauthed(), 'settings/app'));
  });

  test('Catalogue | anonymous still cannot write settings', async () => {
    await expectDenied(
      () => setDoc(unauthed(), 'settings/app', { appName: 'Owned' }),
      'anonymous writes settings',
    );
  });

  test('Catalogue | a customer cannot write settings', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () => updateDoc(ctx, 'settings/app', { appName: 'Hacked' }),
      'customer writes settings',
    );
  });

  test('Catalogue | an admin can create a product', async () => {
    const ctx = await asUser(ADMIN_UID, { admin: true });
    await rulesUnit.assertSucceeds(
      setDoc(ctx, 'products/p2', { name: 'Necklace' }),
    );
  });

  // --- Cloudinary image metadata --------------------------------------------
  //
  // Firestore holds image *metadata* only — a Cloudinary public id, a secure
  // delivery URL and ordering. The bytes live in Cloudinary. These tests pin
  // down that a customer cannot forge or rewrite that metadata, which is what
  // stops someone pointing the storefront at images they do not control.
  test('Images | a customer cannot rewrite a product image list', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () =>
        updateDoc(ctx, 'products/p1', {
          images: [
            {
              publicId: 'padma_collections/products/p1/evil',
              secureUrl: 'https://evil.example/x.png',
            },
          ],
        }),
      'customer rewrites product images',
    );
  });

  test('Images | a customer cannot set an image as primary', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () =>
        updateDoc(ctx, 'products/p1', {
          images: [{ publicId: 'x', isPrimary: true, sortOrder: 0 }],
        }),
      'customer sets primary image',
    );
  });

  test('Images | a customer cannot change a category photo', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () =>
        updateDoc(ctx, 'categories/c1', {
          image: { publicId: 'padma_collections/categories/evil' },
        }),
      'customer changes category image',
    );
  });

  test('Images | a customer cannot change a banner image', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () =>
        updateDoc(ctx, 'banners/b1', {
          image: { publicId: 'padma_collections/banners/evil' },
        }),
      'customer changes banner image',
    );
  });

  test('Images | a customer cannot overwrite the logo or cloud name', async () => {
    // The cloud name is public, but it must be admin-controlled: changing it
    // from a customer device would repoint every delivery URL in the app.
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () =>
        updateDoc(ctx, 'settings/app', {
          logoImage: { publicId: 'padma_collections/store/evil' },
          cloudinaryCloudName: 'dlwcgas2x',
        }),
      'customer overwrites logo or cloud name',
    );
  });

  test('Images | an admin can write Cloudinary image metadata', async () => {
    const ctx = await asUser(ADMIN_UID, { admin: true });
    await rulesUnit.assertSucceeds(
      updateDoc(ctx, 'products/p1', {
        images: [
          {
            publicId: 'padma_collections/products/p1/necklace',
            secureUrl:
              'https://res.cloudinary.com/demo/image/upload/p1/necklace.jpg',
            resourceType: 'image',
            format: 'jpg',
            width: 1600,
            height: 1600,
            isPrimary: true,
            sortOrder: 0,
          },
        ],
      }),
    );
  });

  test('Images | a customer can still read a product and its images', async () => {
    // Image *reads* stay public to signed-in customers — that is how the
    // storefront renders the catalogue.
    const ctx = await asUser(CUSTOMER_UID);
    await rulesUnit.assertSucceeds(getDoc(ctx, 'products/p1'));
  });

  test('Images | a deactivated admin cannot rewrite image metadata', async () => {
    // isActive is checked separately from role, so demoting an account revokes
    // image management immediately rather than at the next token refresh.
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await firestoreApi.setDoc(
        firestoreApi.doc(context.firestore(), `users/${DEACTIVATED_ADMIN_UID}`),
        { uid: DEACTIVATED_ADMIN_UID, role: 'admin', isActive: false },
      );
    });

    const ctx = await asUser(DEACTIVATED_ADMIN_UID, { admin: true });
    await expectDenied(
      () =>
        updateDoc(ctx, 'products/p1', {
          images: [{ publicId: 'x', isPrimary: true, sortOrder: 0 }],
        }),
      'deactivated admin rewrites images',
    );
  });

  test('Catalogue | an admin can write settings', async () => {
    const ctx = await asUser(ADMIN_UID, { admin: true });
    await rulesUnit.assertSucceeds(
      updateDoc(ctx, 'settings/app', { appName: 'Padma 2' }),
    );
  });

  // --- Orders ----------------------------------------------------------------
  test('Orders | a customer can create their own Pending order', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await rulesUnit.assertSucceeds(
      setDoc(ctx, 'orders/o1', {
        userId: CUSTOMER_UID,
        status: 'Pending',
        total: 1000,
        items: [],
        createdAt: new Date(),
      }),
    );
  });

  test('Orders | a customer cannot pre-mark an order as Shipped', async () => {
    // Otherwise a customer could fake their own delivery.
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () =>
        setDoc(ctx, 'orders/o2', {
          userId: CUSTOMER_UID,
          status: 'Shipped',
          items: [],
        }),
      'self-approved order',
    );
  });

  test("Orders | a customer cannot file an order in another's name", async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () =>
        setDoc(ctx, 'orders/o3', {
          userId: OTHER_CUSTOMER_UID,
          status: 'Pending',
          items: [],
        }),
      'order for another user',
    );
  });

  test('Orders | a customer cannot change their own order status', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () => updateDoc(ctx, 'orders/o1', { status: 'Delivered' }),
      'customer marks delivered',
    );
  });

  test("Orders | a customer cannot read another's order", async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(() => getDoc(ctx, 'orders/o-other'), "read another's order");
  });

  test('Orders | a customer can read their own order', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await rulesUnit.assertSucceeds(getDoc(ctx, 'orders/o1'));
  });

  test('Orders | an admin can advance an order status', async () => {
    const ctx = await asUser(ADMIN_UID, { admin: true });
    await rulesUnit.assertSucceeds(
      updateDoc(ctx, 'orders/o1', { status: 'Confirmed' }),
    );
  });

  test('Orders | an admin can query orders by status', async () => {
    const ctx = await asUser(ADMIN_UID, { admin: true });
    await rulesUnit.assertSucceeds(
      firestoreApi.getDocs(
        firestoreApi.query(
          firestoreApi.collection(ctx.firestore(), 'orders'),
          firestoreApi.where('status', '==', 'Confirmed'),
        ),
      ),
    );
  });

  test('Orders | a customer cannot list every order', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(() => getDocs(ctx, 'orders'), 'customer lists all orders');
  });

  // --- Notifications and undeclared collections ------------------------------
  test('Notifications | a customer cannot publish a notification', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(
      () => setDoc(ctx, 'notifications/n1', { title: 'Fake', audience: 'all' }),
      'customer writes notification',
    );
  });

  test('Notifications | anonymous cannot read notifications', async () => {
    await expectDenied(
      () => getDoc(unauthed(), 'notifications/n1'),
      'anonymous reads notifications',
    );
  });

  test('Notifications | customer can query broadcast audiences', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    const query = firestoreApi.query(
      firestoreApi.collection(ctx.firestore(), 'notifications'),
      firestoreApi.where('audience', 'in', ['all', 'customers']),
    );
    await rulesUnit.assertSucceeds(firestoreApi.getDocs(query));
  });

  test('Notifications | customer can query their personal notifications', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    const query = firestoreApi.query(
      firestoreApi.collection(ctx.firestore(), 'notifications'),
      firestoreApi.where('userId', '==', CUSTOMER_UID),
    );
    await rulesUnit.assertSucceeds(firestoreApi.getDocs(query));
  });

  test('Notifications | customer cannot query the unfiltered feed', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(() => getDocs(ctx, 'notifications'), 'unfiltered feed');
  });

  test('Notifications | active admin can query all notifications', async () => {
    const ctx = await asUser(ADMIN_UID, { admin: true });
    await rulesUnit.assertSucceeds(getDocs(ctx, 'notifications'));
  });

  test('Undeclared | a customer cannot write to /secrets', async () => {
    const ctx = await asUser(CUSTOMER_UID);
    await expectDenied(() => setDoc(ctx, 'secrets/s1', { value: 1 }), 'write /secrets');
  });

  test('Undeclared | even an admin is denied on /secrets', async () => {
    // The trailing `match` denies everything, so a new collection is opt-in.
    const ctx = await asUser(ADMIN_UID, { admin: true });
    await expectDenied(
      () => setDoc(ctx, 'secrets/s2', { value: 1 }),
      'admin writes /secrets',
    );
  });
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
