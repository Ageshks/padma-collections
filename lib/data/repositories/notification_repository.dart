import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/error_handler.dart';
import '../models/models.dart';
import 'base_repository.dart';

/// In-app notifications, stored at `notifications/{notificationId}`.
///
/// A notification is written once and matched against the reader's role, so a
/// broadcast is not duplicated per customer. `firestore.rules` guarantees a
/// customer can only ever read notifications addressed to them.
class NotificationRepository extends BaseRepository {
  NotificationRepository({super.firestore});

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(AppConstants.notificationsCollection);

  /// Notifications visible to [uid], newest first.
  Stream<List<NotificationModel>> watchForUser({
    required String uid,
    required bool isAdmin,
  }) {
    if (isAdmin) {
      return _collection
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map(_mapList);
    }
    if (uid.isEmpty) return Stream<List<NotificationModel>>.value(const []);

    return Stream<List<NotificationModel>>.multi((controller) {
      QuerySnapshot<Map<String, dynamic>>? broadcasts;
      QuerySnapshot<Map<String, dynamic>>? personal;

      void emitIfReady() {
        if (broadcasts == null || personal == null) return;
        final Map<String, NotificationModel> byId =
            <String, NotificationModel>{};
        for (final QuerySnapshot<Map<String, dynamic>> snapshot
            in <QuerySnapshot<Map<String, dynamic>>>[broadcasts!, personal!]) {
          for (final QueryDocumentSnapshot<Map<String, dynamic>> document
              in snapshot.docs) {
            byId[document.id] = NotificationModel.fromMap(
              FirestoreMap.fromDocument(document),
              notificationId: document.id,
            );
          }
        }
        final List<NotificationModel> visible =
            byId.values
                .where(
                  (NotificationModel item) =>
                      item.matches(uid: uid, isAdmin: false),
                )
                .toList()
              ..sort(
                (NotificationModel a, NotificationModel b) =>
                    b.createdAt.compareTo(a.createdAt),
              );
        controller.add(visible);
      }

      final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
      broadcastSub = _collection
          .where('audience', whereIn: const <String>['all', 'customers'])
          .snapshots()
          .listen((QuerySnapshot<Map<String, dynamic>> value) {
            broadcasts = value;
            emitIfReady();
          }, onError: controller.addError);
      final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
      personalSub = _collection
          .where('userId', isEqualTo: uid)
          .snapshots()
          .listen((QuerySnapshot<Map<String, dynamic>> value) {
            personal = value;
            emitIfReady();
          }, onError: controller.addError);

      controller.onCancel = () async {
        await broadcastSub.cancel();
        await personalSub.cancel();
      };
    });
  }

  /// Count of unread notifications, for the bell badge.
  Future<int> unreadCount({required String uid, required bool isAdmin}) async {
    if (!isAdmin && uid.isEmpty) return 0;
    final List<QuerySnapshot<Map<String, dynamic>>> snapshots;
    if (isAdmin) {
      snapshots = <QuerySnapshot<Map<String, dynamic>>>[
        await _collection.where('isRead', isEqualTo: false).limit(100).get(),
      ];
    } else {
      snapshots = <QuerySnapshot<Map<String, dynamic>>>[
        await _collection
            .where('audience', whereIn: const <String>['all', 'customers'])
            .get(),
        await _collection.where('userId', isEqualTo: uid).get(),
      ];
    }
    final Map<String, NotificationModel> unread = <String, NotificationModel>{};
    for (final QuerySnapshot<Map<String, dynamic>> snapshot in snapshots) {
      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in snapshot.docs) {
        final NotificationModel item = NotificationModel.fromMap(
          FirestoreMap.fromDocument(document),
          notificationId: document.id,
        );
        if (!item.isRead && item.matches(uid: uid, isAdmin: isAdmin)) {
          unread[document.id] = item;
        }
      }
    }
    return unread.length;
  }

  /// Sends a notification to one user, or to an audience when [userId] is
  /// empty (`all`, `customers` or `admins`).
  Future<String> send({
    required String title,
    required String message,
    NotificationType type = NotificationType.system,
    String userId = '',
    String audience = 'all',
    String imageUrl = '',
    String actionRoute = '',
    String actionValue = '',
  }) async {
    try {
      final NotificationModel notification = NotificationModel(
        notificationId: '',
        title: title.trim(),
        message: message.trim(),
        type: type,
        userId: userId,
        audience: userId.isNotEmpty ? 'specific' : audience,
        imageUrl: imageUrl,
        actionRoute: actionRoute,
        actionValue: actionValue,
        createdAt: DateTime.now(),
      );

      final DocumentReference<Map<String, dynamic>> ref = await _collection.add(
        notification.toMap(),
      );
      return ref.id;
    } catch (e) {
      throw AppErrorHandler.wrap(e);
    }
  }

  /// Marks one notification as read.
  Future<void> markRead(String notificationId) async {
    await _collection.doc(notificationId).update(<String, dynamic>{
      'isRead': true,
    });
  }

  /// Marks every notification visible to the user as read.
  Future<void> markAllRead({required String uid, required bool isAdmin}) async {
    if (!isAdmin && uid.isEmpty) return;
    final List<QuerySnapshot<Map<String, dynamic>>> snapshots;
    if (isAdmin) {
      snapshots = <QuerySnapshot<Map<String, dynamic>>>[
        await _collection.where('isRead', isEqualTo: false).limit(100).get(),
      ];
    } else {
      snapshots = <QuerySnapshot<Map<String, dynamic>>>[
        await _collection
            .where('audience', whereIn: const <String>['all', 'customers'])
            .get(),
        await _collection.where('userId', isEqualTo: uid).get(),
      ];
    }
    final WriteBatch batch = firestore.batch();
    final Set<String> updated = <String>{};
    for (final QuerySnapshot<Map<String, dynamic>> snapshot in snapshots) {
      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in snapshot.docs) {
        final NotificationModel item = NotificationModel.fromMap(
          FirestoreMap.fromDocument(document),
          notificationId: document.id,
        );
        if (!item.isRead &&
            item.matches(uid: uid, isAdmin: isAdmin) &&
            updated.add(document.id)) {
          batch.update(document.reference, <String, dynamic>{'isRead': true});
        }
      }
    }
    await batch.commit();
  }

  /// Removes a notification (admin only).
  Future<void> delete(String notificationId) async {
    await _collection.doc(notificationId).delete();
  }

  List<NotificationModel> _mapList(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) => snapshot.docs
      .map(
        (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
            NotificationModel.fromMap(
              FirestoreMap.fromDocument(document),
              notificationId: document.id,
            ),
      )
      .toList();
}
