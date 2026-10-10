import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'screens/bakery_login_screen.dart';
import 'screens/customize_screen.dart';
import 'screens/firebase_setup_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/my_orders_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/order_confirmation_screen.dart';
import 'screens/order_details_screen.dart';
import 'screens/owner_dashboard_screen.dart';
import 'screens/owner_order_details_screen.dart';
import 'screens/student_login_screen.dart';
import 'screens/student_register_screen.dart';
import 'services/firebase_bootstrap.dart';
import 'state/session_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SessionController session = SessionController();

  // Firebase.initializeApp + `seedDemoData()` + session restore, exactly the
  // order the web prototype runs its startup work in (app.js seeds first, then
  // each page calls requireStudent()/requireOwner()).
  final BootstrapResult bootstrap = await FirebaseBootstrap.run(session);

  runApp(CrumbAndCreamApp(bootstrap: bootstrap, session: session));
}

/// The root widget.
class CrumbAndCreamApp extends StatelessWidget {
  const CrumbAndCreamApp({
    required this.bootstrap,
    required this.session,
    super.key,
  });

  final BootstrapResult bootstrap;
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SessionController>.value(
      value: session,
      child: MaterialApp(
        title: AppConfig.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: bootstrap.ready ? '/' : '/setup',
        onGenerateRoute: (RouteSettings settings) {
          switch (settings.name) {
            case '/setup':
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (BuildContext context) => FirebaseSetupScreen(
                  message: bootstrap.errorMessage,
                ),
              );
            case '/':
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (BuildContext context) => const LandingScreen(),
              );
            case '/student-login':
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (BuildContext context) => const StudentLoginScreen(),
              );
            case '/student-register':
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (BuildContext context) =>
                    const StudentRegisterScreen(),
              );
            case '/bakery-login':
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (BuildContext context) => const BakeryLoginScreen(),
              );
            case '/customize':
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (BuildContext context) => const CustomizeScreen(),
              );
            case '/order-confirmation':
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (BuildContext context) => OrderConfirmationScreen(
                  orderId: settings.arguments as String,
                ),
              );
            case '/my-orders':
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (BuildContext context) => const MyOrdersScreen(),
              );
            case '/order-details':
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (BuildContext context) => OrderDetailsScreen(
                  orderId: settings.arguments as String,
                ),
              );
            case '/notifications':
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (BuildContext context) => const NotificationsScreen(),
              );
            case '/owner-dashboard':
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (BuildContext context) => const OwnerDashboardScreen(),
              );
            case '/owner-order-details':
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (BuildContext context) => OwnerOrderDetailsScreen(
                  orderId: settings.arguments as String,
                ),
              );
            default:
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (BuildContext context) => const LandingScreen(),
              );
          }
        },
      ),
    );
  }
}
