'use strict';

const { HttpsError } = require('firebase-functions/v2/https');
const { getFirestore } = require('firebase-admin/firestore');

/** Where the admin's role and activation flag live. */
const USERS_COLLECTION = 'users';

/** Cached handle; `initializeApp()` has already run by the time this is used. */
function db() {
  return getFirestore();
}

/**
 * Asserts the caller is a signed-in, active Padma Collections admin.
 *
 * This is the security boundary for every image-management function, so it is
 * deliberately strict and deliberately *not* mirrored in the UI:
 *
 *   1. `request.auth` must exist — no anonymous callers, ever.
 *   2. `users/{uid}.role` must be `admin` — a custom claim is NOT trusted here.
 *      Claims are minted by the same project but a stale or forged claim would
 *      otherwise grant image deletion to a demoted admin.
 *   3. `users/{uid}.isActive` must be true — deactivating an account must revoke
 *      image management immediately, not at the next token refresh.
 *
 * The Flutter app's own role check is cosmetic by comparison: it only decides
 * which UI to draw. Reverse-engineering the APK, or calling the function
 * directly, gets you exactly as far as these three checks allow — which is
 * nowhere.
 *
 * @param {import('firebase-functions/v2/https').CallableRequest} request
 * @throws {import('firebase-functions/v2/https').HttpsError} `unauthenticated`
 *   when signed out, `permission-denied` when not an active admin.
 */
async function assertActiveAdmin(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
      'unauthenticated',
      'You must be signed in as a Padma Collections administrator.',
    );
  }

  const uid = request.auth.uid;
  const snapshot = await db().collection(USERS_COLLECTION).doc(uid).get();
  const user = snapshot.exists ? snapshot.data() : null;

  if (!user || user.role !== 'admin') {
    throw new HttpsError(
      'permission-denied',
      'This action is restricted to a Padma Collections administrator.',
    );
  }

  if (user.isActive !== true) {
    throw new HttpsError(
      'permission-denied',
      'This administrator account has been deactivated.',
    );
  }

  return uid;
}

/**
 * Reads a required string field from callable data.
 *
 * @param {Record<string, unknown>} data
 * @param {string} field
 */
function requireString(data, field) {
  const value = data ? data[field] : undefined;
  if (typeof value !== 'string' || value.trim() === '') {
    throw new HttpsError('invalid-argument', `\`${field}\` is required.`);
  }
  return value.trim();
}

module.exports = { assertActiveAdmin, requireString, USERS_COLLECTION };
