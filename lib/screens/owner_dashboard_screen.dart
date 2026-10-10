import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/order_status.dart';
import '../models/order.dart';
import '../services/demo_seed_service.dart';
import '../services/order_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../utils/breakpoints.dart';
import '../utils/formatters.dart';
import '../widgets/app_button.dart';
import '../widgets/app_toast.dart';
import '../widgets/cake_image.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/status_pill.dart';

/// `owner-dashboard.html` — `initOwnerDashboardPage()` in `js/owner.js`.
class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final TextEditingController _search = TextEditingController();
  String _currentFilter = 'all';
  bool _sidebarOpen = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _count(List<Order> orders, List<String> statuses) =>
      orders.where((Order order) => statuses.contains(order.status)).length;

  @override
  Widget build(BuildContext context) {
    return OwnerPageScaffold(
      body: StreamBuilder<List<Order>>(
        stream: OrderService().watchAllOrders(),
        builder: (BuildContext context, AsyncSnapshot<List<Order>> snapshot) {
          final List<Order> orders = snapshot.data ?? <Order>[];

          final int pending = _count(orders, <String>[OrderStatus.pending]);
          final int preparing = _count(orders, <String>[OrderStatus.preparing]);
          final int ready = _count(orders, <String>[OrderStatus.ready]);
          final int completed = _count(orders, <String>[
            OrderStatus.completed,
            'COLLECTED',
          ]);

          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool collapsed =
                  constraints.maxWidth <= Breakpoints.desktop;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (!collapsed)
                    _sidebar(
                      pending: pending,
                      preparing: preparing,
                      ready: ready,
                      completed: completed,
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: collapsed ? AppSpacing.sp4 : AppSpacing.sp5,
                          right: collapsed ? AppSpacing.sp4 : AppSpacing.sp5,
                          top: AppSpacing.sp4,
                          bottom: AppSpacing.sp8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (collapsed) ...<Widget>[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: AppButton(
                                  label: '☰ Menu',
                                  variant: AppButtonVariant.secondary,
                                  small: true,
                                  onPressed: () => setState(
                                    () => _sidebarOpen = !_sidebarOpen,
                                  ),
                                ),
                              ),
                              if (_sidebarOpen) ...<Widget>[
                                const SizedBox(height: AppSpacing.sp3),
                                _sidebar(
                                  pending: pending,
                                  preparing: preparing,
                                  ready: ready,
                                  completed: completed,
                                  compact: true,
                                ),
                              ],
                              const SizedBox(height: AppSpacing.sp3),
                            ],
                            Text('Bakery Dashboard',
                                style: AppText.ownerTopbar),
                            const SizedBox(height: AppSpacing.sp5),
                            _stats(
                              pending: pending,
                              preparing: preparing,
                              ready: ready,
                              completed: completed,
                            ),
                            const SizedBox(height: AppSpacing.sp6),
                            _toolbar(),
                            const SizedBox(height: AppSpacing.sp4),
                            _ordersTable(orders),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ---------- Sidebar ----------
  Widget _sidebar({
    required int pending,
    required int preparing,
    required int ready,
    required int completed,
    bool compact = false,
  }) {
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _sideLabel('Overview', first: true),
        _sideLink(
          icon: '📊',
          label: 'Dashboard',
          active: true,
          onTap: () {
            setState(() {
              _currentFilter = 'all';
              _sidebarOpen = false;
            });
          },
        ),
        _sideLabel('Orders'),
        _sideLink(
          icon: '📦',
          label: 'All Orders',
          active: _currentFilter == 'all',
          onTap: () => _applyFilter('all'),
        ),
        _sideLink(
          icon: '🕓',
          label: 'Pending',
          count: pending,
          active: _currentFilter == OrderStatus.pending,
          onTap: () => _applyFilter(OrderStatus.pending),
        ),
        _sideLink(
          icon: '👩‍🍳',
          label: 'Preparing',
          count: preparing,
          active: _currentFilter == OrderStatus.preparing,
          onTap: () => _applyFilter(OrderStatus.preparing),
        ),
        _sideLink(
          icon: '✅',
          label: 'Ready',
          count: ready,
          active: _currentFilter == OrderStatus.ready,
          onTap: () => _applyFilter(OrderStatus.ready),
        ),
        _sideLink(
          icon: '🎉',
          label: 'Completed',
          count: completed,
          active: _currentFilter == OrderStatus.completed,
          onTap: () => _applyFilter(OrderStatus.completed),
        ),
        _sideLabel('Other'),
        _sideLink(
          icon: '🗑️',
          label: 'Clear Demo Data',
          onTap: _confirmClearDemoData,
        ),
      ],
    );

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sp3,
          vertical: AppSpacing.sp4,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: AppRadius.md,
          border: Border.all(color: AppColors.border),
        ),
        child: content,
      );
    }

    return Container(
      width: AppLayout.ownerSidebar,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sp3,
        vertical: AppSpacing.sp5,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          right: BorderSide(color: AppColors.border),
        ),
      ),
      child: SingleChildScrollView(child: content),
    );
  }

  Widget _sideLabel(String text, {bool first = false}) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.sp3,
        top: first ? 0 : AppSpacing.sp4,
        bottom: AppSpacing.sp1,
      ),
      child: Text(
        text.toUpperCase(),
        style: AppText.inter(
          size: 11,
          color: AppColors.textMuted,
          height: 1.4,
        ).copyWith(letterSpacing: 0.6),
      ),
    );
  }

  Widget _sideLink({
    required String icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    int? count,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.sm,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sp3,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.coralLight : null,
          borderRadius: AppRadius.sm,
        ),
        child: Row(
          children: <Widget>[
            Text(icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: AppSpacing.sp2),
            Expanded(
              child: Text(
                label,
                style: AppText.inter(
                  size: 14,
                  weight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppColors.coralDark : AppColors.text,
                  height: 1.35,
                ),
              ),
            ),
            if (count != null)
              Text(
                '$count',
                style: AppText.inter(
                  size: 12,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- Stats ----------
  Widget _stats({
    required int pending,
    required int preparing,
    required int ready,
    required int completed,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool narrow = constraints.maxWidth <= Breakpoints.desktop;
        final List<Widget> cards = <Widget>[
          _statCard(pending, 'New Orders', accent: true),
          _statCard(preparing, 'Preparing'),
          _statCard(ready, 'Ready'),
          _statCard(completed, 'Completed'),
        ];
        if (narrow) {
          return Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: cards[0]),
                  const SizedBox(width: AppSpacing.sp3),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: AppSpacing.sp3),
              Row(
                children: <Widget>[
                  Expanded(child: cards[2]),
                  const SizedBox(width: AppSpacing.sp3),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }
        return Row(
          children: <Widget>[
            for (int i = 0; i < cards.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: AppSpacing.sp3),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _statCard(int value, String label, {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$value',
            style: AppText.poppins(
              size: 30,
              color: accent ? AppColors.coralDark : AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppText.inter(
              size: 13,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Toolbar ----------
  Widget _toolbar() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stacked = constraints.maxWidth <= Breakpoints.desktop;
        final Widget searchBox = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: AppText.input,
            cursorColor: AppColors.coral,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search by student name or order ID',
              hintStyle: AppText.input.copyWith(color: AppColors.textMuted),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 14, right: 4),
                child: Text('🔍'),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
              filled: true,
              fillColor: AppColors.cream,
              enabledBorder: const OutlineInputBorder(
                borderRadius: AppRadius.sm,
                borderSide: BorderSide(
                  color: AppColors.border,
                  width: AppBorders.regular,
                ),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: AppRadius.sm,
                borderSide: BorderSide(
                  color: AppColors.coral,
                  width: AppBorders.regular,
                ),
              ),
            ),
          ),
        );

        final Widget pills = Wrap(
          spacing: AppSpacing.sp1,
          runSpacing: AppSpacing.sp1,
          children: <Widget>[
            for (final Map<String, String> filter
                in OrderStatus.dashboardFilters)
              _FilterPill(
                label: filter['label']!,
                active: _currentFilter == filter['value'],
                onTap: () => setState(() => _currentFilter = filter['value']!),
              ),
          ],
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              searchBox,
              const SizedBox(height: AppSpacing.sp3),
              pills,
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: Align(alignment: Alignment.centerLeft, child: searchBox)),
            const SizedBox(width: AppSpacing.sp3),
            Flexible(child: pills),
          ],
        );
      },
    );
  }

  // ---------- Orders table ----------
  Widget _ordersTable(List<Order> orders) {
    final String searchTerm = _search.text.trim().toLowerCase();
    final List<Order> filtered = orders
        .where((Order order) =>
            _currentFilter == 'all' || order.status == _currentFilter)
        .where((Order order) {
      if (searchTerm.isEmpty) return true;
      return order.studentName.toLowerCase().contains(searchTerm) ||
          order.orderId.toLowerCase().contains(searchTerm);
    }).toList();

    if (filtered.isEmpty) {
      return const EmptyState(
        emoji: '📭',
        title: 'No matching orders',
        message: 'Try a different filter or search term.',
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width =
            math.max(constraints.maxWidth, AppLayout.ordersTable);
        return Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _tableHeader(),
                  for (final Order order in filtered) _tableRow(order),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sp3,
        vertical: AppSpacing.sp3,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          // The original table has an `Order` column header above the
          // thumbnail column.
          SizedBox(
            width: 40 + AppSpacing.sp3,
            child: Text(
              'ORDER',
              style: AppText.inter(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.textMuted,
                height: 1.4,
              ).copyWith(letterSpacing: 0.3),
            ),
          ),
          _headerCell('Order ID', 2),
          _headerCell('Student', 3),
          _headerCell('Cake', 3),
          _headerCell('Required', 3),
          _headerCell('Price', 2),
          _headerCell('Status', 2),
          const Expanded(flex: 2, child: SizedBox()),
        ],
      ),
    );
  }

  Widget _headerCell(String label, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: AppText.inter(
          size: 12,
          weight: FontWeight.w600,
          color: AppColors.textMuted,
          height: 1.4,
        ).copyWith(letterSpacing: 0.3),
      ),
    );
  }

  Widget _tableRow(Order order) {
    return _TableRow(
      order: order,
      onView: () => Navigator.of(context).pushNamed(
        '/owner-order-details',
        arguments: order.orderId,
      ),
    );
  }

  // ---------- Clear Demo Data ----------
  Future<void> _confirmClearDemoData() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.white,
        title: Text('Clear Demo Data', style: AppText.h3),
        content: Text(
          'This will reset all demo students, orders and notifications. Continue?',
          style: AppText.paragraph,
        ),
        actions: <Widget>[
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.secondary,
            small: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButton(
            label: 'Continue',
            small: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await DemoSeedService().clearAndReseed();
    if (!mounted) return;
    AppToast.show(context, 'Demo data has been reset.', type: ToastType.success);
  }

  void _applyFilter(String filter) {
    setState(() {
      _currentFilter = filter;
      _sidebarOpen = false;
    });
  }
}

/// `.filter-pill` / `.filter-pill.active`
class _FilterPill extends StatelessWidget {
  const _FilterPill({
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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
            size: 13,
            weight: FontWeight.w600,
            color: active ? AppColors.white : AppColors.textMuted,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

/// A single `table.orders-table tr` with the hover background from `owner.css`.
class _TableRow extends StatefulWidget {
  const _TableRow({required this.order, required this.onView});

  final Order order;
  final VoidCallback onView;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Order order = widget.order;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sp3,
          vertical: AppSpacing.sp3,
        ),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.cream : AppColors.white,
          border: const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 40,
                height: 40,
                child: CakeImage(
                  imageUrl: order.referenceImage,
                  flavor: order.flavor,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sp3),
            Expanded(
              flex: 2,
              child: Text(
                '#${order.orderId}',
                style: AppText.detailValue,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(order.studentName, style: AppText.detail),
            ),
            Expanded(
              flex: 3,
              child: Text(
                '${order.flavor} · ${order.size}',
                style: AppText.detail,
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    Formatters.formatDate(order.requiredDate),
                    style: AppText.detail,
                  ),
                  Text(
                    Formatters.formatTime(order.requiredTime),
                    style: AppText.inter(
                      size: 12,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '₹${order.estimatedPrice}',
                style: AppText.detail,
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(status: order.status),
              ),
            ),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: widget.onView,
                child: Text(
                  'View →',
                  style: AppText.inter(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: AppColors.coralDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
