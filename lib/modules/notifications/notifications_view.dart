import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_formatter.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';
import '../../data/repositories/notification_repository.dart';
import '../common/controllers/app_controller.dart';

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController app = Get.find<AppController>();
    final NotificationRepository notifications =
        Get.find<NotificationRepository>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          TextButton(
            onPressed: () => notifications.markAllRead(
              uid: app.currentUid,
              isAdmin: app.isAdmin,
            ),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: notifications.watchForUser(
          uid: app.currentUid,
          isAdmin: app.isAdmin,
        ),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<NotificationModel>> snap,
            ) {
              if (snap.hasError) {
                return const EmptyState(
                  title: 'Notifications unavailable.',
                  message: 'Please check your connection and try again.',
                  icon: Icons.notifications_off_outlined,
                );
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final List<NotificationModel> list =
                  snap.data ?? const <NotificationModel>[];
              if (list.isEmpty) {
                return const EmptyState(
                  title: 'You are all caught up.',
                  message: 'Store and order updates will appear here.',
                  icon: Icons.notifications_none_rounded,
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (BuildContext context, int index) {
                  final NotificationModel notification = list[index];
                  return _NotificationTile(
                    notification: notification,
                    onTap: notification.isRead
                        ? null
                        : () => notifications.markRead(
                            notification.notificationId,
                          ),
                  );
                },
              );
            },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationModel notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      leading: Icon(
        notification.isRead
            ? Icons.notifications_none_rounded
            : Icons.notifications_active_rounded,
        color: notification.isRead ? AppColors.textHint : AppColors.burgundy,
      ),
      title: Text(
        notification.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(notification.message),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppFormatter.relative(notification.createdAt),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
