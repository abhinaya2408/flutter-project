import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../models/student_profile.dart';
import '../services/notification_service.dart';
import '../state/session_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import '../widgets/app_button.dart';
import '../widgets/app_toast.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_container.dart';
import '../widgets/page_scaffold.dart';

/// `notifications.html` — `initNotificationsPage()` in `js/notifications.js`.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final StudentProfile? student = context.watch<SessionController>().student;

    return StudentPageScaffold(
      activeTab: 'notifications',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            PageContainer(
              top: AppSpacing.sp6,
              bottom: AppSpacing.sp2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Notifications', style: AppText.dashboardHeader),
                  const SizedBox(height: 2),
                  Text(
                    'Updates about your cake orders, all in one place.',
                    style: AppText.paragraph,
                  ),
                ],
              ),
            ),
            PageContainer(
              maxWidth: 720,
              bottom: AppSpacing.sp8,
              child: student == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<List<AppNotification>>(
                      stream: NotificationService()
                          .watchForStudent(student.studentId),
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<List<AppNotification>> snapshot,
                      ) {
                        final List<AppNotification> items =
                            snapshot.data ?? <AppNotification>[];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                AppButton(
                                  label: 'Mark all as read',
                                  variant: AppButtonVariant.outline,
                                  small: true,
                                  onPressed: () async {
                                    await NotificationService()
                                        .markAllRead(student.studentId);
                                    if (!context.mounted) return;
                                    AppToast.show(
                                      context,
                                      'All notifications marked as read.',
                                      type: ToastType.success,
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sp4),
                            if (items.isEmpty)
                              const EmptyState(
                                emoji: '🔔',
                                title: 'No notifications yet',
                                message:
                                    "We'll let you know as soon as there's an update on your order.",
                              )
                            else
                              Column(
                                children: <Widget>[
                                  for (int i = 0; i < items.length; i++) ...<
                                      Widget>[
                                    if (i > 0)
                                      const SizedBox(height: AppSpacing.sp2),
                                    _NotificationItem(item: items[i]),
                                  ],
                                ],
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.notif-item` (+ `.unread`) — tapping marks it read and opens the order.
class _NotificationItem extends StatelessWidget {
  const _NotificationItem({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (!item.read) {
          await NotificationService().markRead(item.id);
        }
        if (!context.mounted) return;
        // `markNotificationRead()` then navigate to the order.
        Navigator.of(context).pushNamed(
          '/order-details',
          arguments: item.orderId,
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sp4),
          decoration: BoxDecoration(
            color: item.read ? AppColors.white : AppColors.coralLight,
            borderRadius: AppRadius.md,
            border: Border.all(
              color: item.read ? AppColors.border : AppColors.notifUnreadBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('🔔', style: TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.message,
                      style: AppText.inter(
                        size: 14,
                        weight: FontWeight.w500,
                        color: AppColors.charcoal,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.timeAgo(item.createdAt)} · '
                      'Order #${item.orderId}',
                      style: AppText.inter(
                        size: 12,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (!item.read) ...<Widget>[
                const SizedBox(width: AppSpacing.sp2),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.coral,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
