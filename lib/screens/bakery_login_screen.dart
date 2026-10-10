import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../state/session_controller.dart';
import '../utils/validators.dart';
import '../widgets/app_button.dart';
import '../widgets/app_navbar.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/auth_card.dart';
import '../widgets/demo_banner.dart';

/// `bakery-login.html` — `initOwnerLoginPage()` in `js/auth.js`.
class BakeryLoginScreen extends StatefulWidget {
  const BakeryLoginScreen({super.key});

  @override
  State<BakeryLoginScreen> createState() => _BakeryLoginScreenState();
}

class _BakeryLoginScreenState extends State<BakeryLoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  String? _emailError;
  String? _passwordError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final SessionController session = context.read<SessionController>();
      if (session.isOwnerLoggedIn && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/owner-dashboard',
          (Route<dynamic> _) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final String email = _email.text.trim().toLowerCase();
    final String password = _password.text;

    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    setState(() => _busy = true);
    try {
      await context.read<SessionController>().loginOwner(
            email: email,
            password: password,
          );
      if (!mounted) return;
      AppToast.show(
        context,
        'Welcome back to the bakery dashboard!',
        type: ToastType.success,
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/owner-dashboard',
        (Route<dynamic> _) => false,
      );
    } on AuthException {
      if (!mounted) return;
      // The original shows every failure on the password field.
      setState(() {
        _busy = false;
        _passwordError = Validators.incorrectCredentials;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            AppNavBar(
              brandLabel: 'Crumb & Cream',
              onBrandTap: () => Navigator.of(context)
                  .pushNamedAndRemoveUntil('/', (Route<dynamic> _) => false),
              entries: const <NavEntry>[],
            ),
            Expanded(
              child: AuthCard(
                backLabel: '← Back to home',
                onBack: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (Route<dynamic> _) => false),
                icon: '🧁',
                title: 'Bakery Member Portal',
                subtitle: 'Manage student cake orders and preparation.',
                footer: AuthFooterLink(
                  leadingText: 'Are you a student? ',
                  linkText: 'Go to student sign in',
                  onTap: () => Navigator.of(context)
                      .pushReplacementNamed('/student-login'),
                ),
                children: <Widget>[
                  const DemoBanner(
                    title: 'Demo Bakery Account',
                    details: 'owner@collegebakery.com · bakery123',
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    hint: 'owner@collegebakery.com',
                    error: _emailError,
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: 'Password',
                    controller: _password,
                    obscure: true,
                    hint: 'Enter password',
                    error: _passwordError,
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Sign In',
                    block: true,
                    onPressed: _busy ? null : _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
