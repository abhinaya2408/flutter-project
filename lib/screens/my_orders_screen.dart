import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/order_status.dart';
import '../models/order.dart';
import '../models/student_profile.dart';
import '../services/order_service.dart';
import '../state/session_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';
import '../widgets/order_card.dart';
import '../widgets/page_container.dart';
import '../widgets/page_scaffold.dart';

/// `my-orders.html` — `initMyOrdersPage()` in `js/orders.js`.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  String _currentTab = 'all';

  static const List<Map<String, String>> _tabs = <Map<String, String>>[
    <String, String>{'value': 'all', 'label': 'All'},
    <String, String>{'value': 'active', 'label': 'Active'},
    <String, String>{'value': 'ready', 'label': 'Ready'},
    <String, String>{'value': 'completed', 'label': 'Completed'},
  ];

  @override
  Widget build(BuildContext context) {
    final StudentProfile? student = context.watch<SessionController>().student;

    return StudentPageScaffold(
      activeTab: 'my-orders',
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
                  Text('My Orders', style: AppText.dashboardHeader),
                  const SizedBox(height: 2),
                  Text(
                    "Track every cake you've ordered, from placed to collected.",
                    style: AppText.paragraph,
                  ),
                ],
              ),
            ),
            PageContainer(
              bottom: AppSpacing.sp8,
              child: student == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<List<Order>>(
                      stream:
                          OrderService().watchStudentOrders(student.studentId),
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<List<Order>> snapshot,
                      ) {
                        final List<Order> orders = (snapshot.data ?? <Order>[])
                            .where(
                              (Order order) =>
                                  OrderStatus.matchesTab(order.status, _currentTab),
                            )
                            .toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Wrap(
                              spacing: AppSpacing.sp2,
                              runSpacing: AppSpacing.sp2,
                              children: <Widget>[
                                for (final Map<String, String> tab in _tabs)
                                  _TabButton(
                                    label: tab['label']!,
                                    active: _currentTab == tab['value'],
                                    onTap: () => setState(
                                      () => _currentTab = tab['value']!,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sp5),
                            if (orders.isEmpty)
                              EmptyState(
                                emoji: '🎂',
                                title: 'No cake orders yet',
                                message:
                                    'Your customized cakes will appear here.',
                                actionLabel: 'Customize a Cake',
                                onAction: () => Navigator.of(context)
                                    .pushNamed('/customize'),
                              )
                            else
                              Column(
                                children: <Widget>[
                                  for (int i = 0; i < orders.length; i++) ...<
                                      Widget>[
                                    if (i > 0)
                                      const SizedBox(height: AppSpacing.sp3),
                                    OrderCard(
                                      order: orders[i],
                                      onTap: () => Navigator.of(context)
                                          .pushNamed(
                                        '/order-details',
                                        arguments: orders[i].orderId,
                                      ),
                                    ),
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

/// `.tab-btn` / `.tab-btn.active`
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.charcoal : AppColors.white,
          borderRadius: AppRadius.pill,
          border: Border.all(
            color: active ? AppColors.charcoal : AppColors.border,
            width: AppBorders.regular,
          ),
        ),
        child: Text(
          label,
          style: AppText.inter(
            size: 13.5,
            weight: FontWeight.w600,
            color: active ? AppColors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
