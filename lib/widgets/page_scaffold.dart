import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/student_profile.dart';
import '../services/notification_service.dart';
import '../state/session_controller.dart';
import '../theme/app_colors.dart';
import 'app_navbar.dart';

/// The shared chrome for the student pages: the sticky nav bar plus a
/// scrollable body.
///
/// It also reproduces `requireStudent()` in `js/app.js`: a page opened without
/// a signed-in student bounces straight to the sign-in screen.
class StudentPageScaffold extends StatefulWidget {
  const StudentPageScaffold({
    required this.body,
    this.activeTab,
    super.key,
  });

  /// `customize` | `my-orders` | `notifications` — highlights the nav link.
  final String? activeTab;

  final Widget body;

  @override
  State<StudentPageScaffold> createState() => _StudentPageScaffoldState();
}

class _StudentPageScaffoldState extends State<StudentPageScaffold> {
  bool _redirected = false;

  void _redirectToLogin() {
    if (_redirected) return;
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/student-login', (Route<dynamic> _) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = context.watch<SessionController>();
    final StudentProfile? student = session.student;

    if (student == null) {
      if (!session.isRestoring) _redirectToLogin();
      return const SizedBox.shrink();
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            // The badge is rendered from a live unread-count stream so the
            // number matches `unreadNotificationCount(studentId)`.
            StreamBuilder<int>(
              stream:
                  NotificationService().watchUnreadCount(student.studentId),
              builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
                return AppNavBar(
                  brandLabel: 'Crumb & Cream',
                  onBrandTap: () =>
                      Navigator.of(context).pushReplacementNamed('/customize'),
                  entries: <NavEntry>[
                    NavEntry(
                      label: 'Customize',
                      active: widget.activeTab == 'customize',
                      onTap: () => _go('/customize'),
                    ),
                    NavEntry(
                      label: 'My Orders',
                      active: widget.activeTab == 'my-orders',
                      onTap: () => _go('/my-orders'),
                    ),
                    NavEntry(
                      label: 'Notifications',
                      active: widget.activeTab == 'notifications',
                      badgeCount: snapshot.data ?? 0,
                      onTap: () => _go('/notifications'),
                    ),
                    NavEntry(
                      label: 'Logout',
                      onTap: () async {
                        await context.read<SessionController>().logoutStudent();
                        if (!context.mounted) return;
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/student-login',
                          (Route<dynamic> _) => false,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            Expanded(child: widget.body),
          ],
        ),
      ),
    );
  }

  void _go(String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.of(context).pushNamed(route);
  }
}

/// The shared chrome for the bakery pages (`Bakery Portal` brand suffix and a
/// single Logout link), reproducing `requireOwner()`.
class OwnerPageScaffold extends StatefulWidget {
  const OwnerPageScaffold({required this.body, super.key});

  final Widget body;

  @override
  State<OwnerPageScaffold> createState() => _OwnerPageScaffoldState();
}

class _OwnerPageScaffoldState extends State<OwnerPageScaffold> {
  bool _redirected = false;

  void _redirectToLogin() {
    if (_redirected) return;
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/bakery-login', (Route<dynamic> _) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = context.watch<SessionController>();
    if (!session.isOwnerLoggedIn) {
      if (!session.isRestoring) _redirectToLogin();
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            AppNavBar(
              brandLabel: 'Crumb & Cream',
              brandSuffix: 'Bakery Portal',
              onBrandTap: () =>
                  Navigator.of(context).pushReplacementNamed('/owner-dashboard'),
              entries: <NavEntry>[
                NavEntry(
                  label: 'Logout',
                  onTap: () async {
                    await context.read<SessionController>().logoutOwner();
                    if (!context.mounted) return;
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/bakery-login',
                      (Route<dynamic> _) => false,
                    );
                  },
                ),
              ],
            ),
            Expanded(child: widget.body),
          ],
        ),
      ),
    );
  }
}
