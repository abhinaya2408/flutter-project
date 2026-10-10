import 'package:flutter/material.dart';

import '../data/order_status.dart';
import '../models/order.dart';
import '../services/notification_service.dart';
import '../services/order_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import '../widgets/app_button.dart';
import '../widgets/app_toast.dart';
import '../widgets/cake_image.dart';
import '../widgets/detail_row.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_container.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/status_tracker.dart';

/// `owner-order-details.html` — `initOwnerOrderDetailsPage()` in `js/owner.js`.
class OwnerOrderDetailsScreen extends StatelessWidget {
  const OwnerOrderDetailsScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return OwnerPageScaffold(
      body: SingleChildScrollView(
        child: PageContainer(
          maxWidth: AppLayout.ownerOrderDetails,
          top: AppSpacing.sp6,
          bottom: AppSpacing.sp8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              InkWell(
                onTap: () => Navigator.of(context)
                    .pushReplacementNamed('/owner-dashboard'),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sp4),
                  child: Text(
                    '← Back to Dashboard',
                    style: AppText.inter(
                      size: 13.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              StreamBuilder<Order?>(
                stream: OrderService().watchOrder(orderId),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<Order?> snapshot,
                ) {
                  final Order? order = snapshot.data;
                  if (order == null) {
                    return EmptyState(
                      emoji: '📭',
                      title: 'Order not found',
                      message: "This order ID doesn't exist.",
                      actionLabel: 'Back to Dashboard',
                      onAction: () => Navigator.of(context)
                          .pushReplacementNamed('/owner-dashboard'),
                    );
                  }
                  return _OwnerOrderBody(order: order);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerOrderBody extends StatelessWidget {
  const _OwnerOrderBody({required this.order});

  final Order order;

  /// `advanceOrderStatus()` — update the status, create the student
  /// notification and show the toast.
  Future<void> _advance(BuildContext context, String newStatus) async {
    await OrderService().updateOrderStatus(order.orderId, newStatus);
    await NotificationService().notifyStatusChange(
      studentId: order.studentId,
      orderId: order.orderId,
      status: newStatus,
    );
    if (!context.mounted) return;
    AppToast.show(
      context,
      OrderStatus.actionToast(newStatus),
      type: ToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sp3,
            bottom: AppSpacing.sp4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Order #${order.orderId}', style: AppText.dashboardHeader),
              const SizedBox(height: 2),
              Text(
                'Placed ${Formatters.timeAgo(order.createdAt)}',
                style: AppText.paragraph,
              ),
            ],
          ),
        ),
        StatusTracker(status: order.status),
        const SizedBox(height: AppSpacing.sp5),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool stacked = constraints.maxWidth <= 900;
            final Widget left = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Card(
                  title: 'Student',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      DetailRow(label: 'Name', value: order.studentName),
                      DetailRow(label: 'Student ID', value: order.studentId),
                      DetailRow(label: 'Email', value: order.studentEmail),
                      DetailRow(
                        label: 'Phone',
                        value: order.studentPhone,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                _Card(
                  title: 'Cake',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      DetailRow(label: 'Flavor', value: order.flavor),
                      DetailRow(label: 'Cake Type', value: order.cakeType),
                      DetailRow(label: 'Size', value: order.size),
                      DetailRow(label: 'Cream', value: order.cream),
                      DetailRow(
                        label: 'Decorations',
                        value: order.decorations.isEmpty
                            ? 'None'
                            : order.decorations.join(', '),
                      ),
                      DetailRow(
                        label: 'Required Date',
                        value: Formatters.formatDate(order.requiredDate),
                      ),
                      DetailRow(
                        label: 'Required Time',
                        value: Formatters.formatTime(order.requiredTime),
                      ),
                      DetailRow(
                        label: 'Price',
                        value: '₹${order.estimatedPrice}',
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                if (order.cakeMessage.isNotEmpty)
                  _Card(
                    title: 'Cake Message',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sp3),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: AppRadius.sm,
                      ),
                      child: Text(
                        '"${order.cakeMessage}"',
                        style: AppText.inter(
                          size: 14,
                          color: AppColors.text,
                          height: 1.45,
                        ).copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                if (order.specialInstructions.isNotEmpty)
                  _Card(
                    title: 'Special Instructions',
                    child: Text(
                      order.specialInstructions,
                      style: AppText.paragraph,
                    ),
                  ),
              ],
            );

            final Widget right = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Card(
                  title: 'Reference Image',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: AppRadius.md,
                        child: AspectRatio(
                          aspectRatio: AppLayout.cakeImageAspect,
                          child: CakeImage(
                            imageUrl: order.referenceImage,
                            flavor: order.flavor,
                          ),
                        ),
                      ),
                      if (order.referenceImage.isEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.sp2),
                        Text(
                          'Student did not upload a reference photo.',
                          style: AppText.meta,
                        ),
                      ],
                    ],
                  ),
                ),
                _Card(
                  title: 'Update Status',
                  child: _actions(context),
                ),
              ],
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  left,
                  right,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: left),
                const SizedBox(width: AppSpacing.sp6),
                Expanded(child: right),
              ],
            );
          },
        ),
      ],
    );
  }

  /// `renderOwnerActions()` — the buttons for the current status.
  Widget _actions(BuildContext context) {
    final List<Map<String, String>> actions =
        Order.actionsByStatus[order.status] ?? const <Map<String, String>>[];

    if (actions.isEmpty) {
      return Text(
        'No further actions available for this order.',
        style: AppText.meta.copyWith(fontSize: 13.5),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < actions.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.sp2),
          AppButton(
            label: actions[i]['label']!,
            block: true,
            variant: actions[i]['variant'] == 'danger'
                ? AppButtonVariant.danger
                : AppButtonVariant.primary,
            onPressed: () => _advance(context, actions[i]['status']!),
          ),
        ],
      ],
    );
  }
}

/// `.detail-card`
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sp4),
      padding: const EdgeInsets.all(AppSpacing.sp5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: AppText.detailCardTitle),
          const SizedBox(height: AppSpacing.sp3),
          child,
        ],
      ),
    );
  }
}
