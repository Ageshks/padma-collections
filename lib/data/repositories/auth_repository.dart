import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/error_handler.dart';
import '../models/models.dart';
import 'base_repository.dart';

/// Authentication plus the `users/{userId}` profile document.
///
/// **Security note:** registration always writes `role: customer`. Promotion to
/// admin is only possible from another admin account, and is enforced again by
/// `firestore.rules` — never by the client alone.
class AuthRepository extends BaseRepository {
  AuthRepository({super.firestore, FirebaseAuth? auth}) : _injectedAuth = auth;

  final FirebaseAuth? _injectedAuth;

  /// Lazily resolved, for the same reason as [BaseRepository.firestore] —
  /// `FirebaseAuth.instance` throws before `Firebase.initializeApp` has run.
  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      firestore.collection(AppConstants.usersCollection);

  /// Currently signed-in Firebase user, if any.
  User? get currentUser => _auth.currentUser;

  String? get currentUid {
    return _auth.currentUser?.uid;
  }

  bool get isSignedIn => _auth.currentUser != null;

  /// Emits whenever the signed-in user changes (sign-in, sign-out, revoke).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---------------------------------------------------------------------------
  // Registration and sign-in
  // ---------------------------------------------------------------------------

  /// Creates a customer account and its Firestore profile.
  ///
  /// The role is hard-coded to [UserRole.customer]; there is deliberately no
  /// way for a caller to request an admin account.
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    try {
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );

      final UserModel user = UserModel(
        uid: credential.user!.uid,
        name: name.trim(),
        email: email.trim().toLowerCase(),
        phone: phone.trim(),
        role: UserRole.customer,
        createdAt: DateTime.now(),
      );

      await _users.doc(user.uid).set(user.toMap());
      return user;
    } catch (e) {
      throw AppErrorHandler.wrap(e);
    }
  }

  /// Signs in and returns the matching profile document.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return await _requireActive(await fetchProfile(credential.user!.uid));
    } catch (e) {
      throw AppErrorHandler.wrap(e);
    }
  }

  /// Signs in with a Google ID token.
  ///
  /// The token is exchanged with Firebase Auth. On success the matching
  /// `users/{uid}` document is created on first sign-in, or reused afterwards —
  /// so an existing customer's cart, wishlist and order history survive.
  ///
  /// The role is always [UserRole.customer] for a new account. An existing
  /// account keeps whatever role it already had, which means an admin signing
  /// in with Google lands in the admin app rather than the shop.
  Future<UserModel> loginWithGoogle({
    required String idToken,
    String? fallbackName,
    String? fallbackEmail,
    String? fallbackPhone,
    String? photoUrl,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );

      final User? authUser = credential.user;
      if (authUser == null) {
        throw const AppException(
          'We could not complete Google Sign-In. Please try again.',
          code: 'google-no-user',
        );
      }

      final String uid = authUser.uid;
      final DocumentSnapshot<Map<String, dynamic>> existing = await _users
          .doc(uid)
          .get();

      if (existing.exists) {
        // Already known — refresh the photo and display name, keep the role.
        final UserModel current = UserModel.fromMap(
          FirestoreMap.fromDocument(existing),
          uid: uid,
        );
        await _requireActive(current);
        await _users.doc(uid).update(<String, dynamic>{
          'profileImage': photoUrl ?? current.profileImage,
          'updatedAt': DateTime.now(),
        });
        return current;
      }

      final UserModel created = UserModel(
        uid: uid,
        name: _cleanName(fallbackName) ?? _nameFromEmail(authUser.email),
        email: (fallbackEmail ?? authUser.email ?? '').trim().toLowerCase(),
        phone: (fallbackPhone ?? authUser.phoneNumber ?? '').trim(),
        profileImage: photoUrl ?? authUser.photoURL ?? '',
        role: UserRole.customer,
        createdAt: DateTime.now(),
      );
      await _users.doc(uid).set(created.toMap());
      return created;
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppErrorHandler.wrap(e);
    }
  }

  Future<UserModel> _requireActive(UserModel user) async {
    if (user.isActive) return user;
    await _auth.signOut();
    throw const AppException(
      'This account has been disabled. Please contact Padma Collections support.',
      code: 'user-disabled',
    );
  }

  /// Prefers the name Google returned, then our own stored name, then an
  /// email-derived fallback so the field is never blank.
  String? _cleanName(String? name) {
    final String value = (name ?? '').trim();
    if (value.isEmpty) return null;
    return value;
  }

  String _nameFromEmail(String? email) {
    if (email == null || email.isEmpty) return 'Customer';
    final String local = email.split('@').first;
    if (local.isEmpty) return 'Customer';
    return local[0].toUpperCase() + local.substring(1);
  }

  /// Loads the profile document for a uid.
  ///
  /// If the document is missing (for example an account created through the
  /// Firebase console), a safe customer profile is created on the fly. Throws
  /// a friendly [AppException] when no profile can be produced at all.
  Future<UserModel> fetchProfile(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _users
        .doc(uid)
        .get();
    if (!doc.exists) {
      final User authUser = _auth.currentUser!;
      final UserModel created = UserModel(
        uid: uid,
        name: authUser.displayName ?? authUser.email!.split('@').first,
        email: authUser.email ?? '',
        phone: authUser.phoneNumber ?? '',
        role: UserRole.customer,
        createdAt: DateTime.now(),
      );
      await _users.doc(uid).set(created.toMap());
      return created;
    }
    return UserModel.fromMap(FirestoreMap.fromDocument(doc), uid: uid);
  }

  /// Streams a user's profile so the UI reacts to edits immediately.
  Stream<UserModel?> watchProfile(String uid) {
    return _users
        .doc(uid)
        .snapshots()
        .map(
          (DocumentSnapshot<Map<String, dynamic>> d) =>
              d.exists ? UserModel.fromMap(FirestoreMap.fromDocument(d)) : null,
        );
  }

  /// Sends a password reset email.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw AppErrorHandler.wrap(e);
    }
  }

  /// Changes the password of the signed-in account.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw const AppException(
          'Please sign in again to change your password.',
        );
      }
      // Re-authenticate first, as Firebase requires a recent login.
      await _auth.signInWithEmailAndPassword(
        email: user.email!,
        password: currentPassword,
      );
      await user.updatePassword(newPassword);
    } catch (e) {
      throw AppErrorHandler.wrap(e);
    }
  }

  /// Signs the user out and clears local state.
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Profile updates
  // ---------------------------------------------------------------------------

  /// Updates the signed-in user's own profile fields.
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? profileImage,
  }) async {
    final String uid = currentUid ?? '';
    if (uid.isEmpty) {
      throw const AppException('Please sign in to update your profile.');
    }
    final Map<String, dynamic> updates = <String, dynamic>{
      'updatedAt': DateTime.now(),
    };
    if (name != null) updates['name'] = name.trim();
    if (phone != null) updates['phone'] = phone.trim();
    if (profileImage != null) updates['profileImage'] = profileImage;

    try {
      await _users.doc(uid).update(updates);
      if (name != null) {
        await _auth.currentUser?.updateDisplayName(name.trim());
      }
    } catch (e) {
      throw AppErrorHandler.wrap(e);
    }
  }

  /// Stores the latest FCM token so the admin can target this device.
  Future<void> saveFcmToken(String uid, String token) async {
    await _users.doc(uid).update(<String, dynamic>{'fcmToken': token});
  }

  // ---------------------------------------------------------------------------
  // Demo-mode auth
  // ---------------------------------------------------------------------------
}

/// Shared demo authentication state.
