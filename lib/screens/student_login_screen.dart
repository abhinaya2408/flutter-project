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

/// `student-login.html` — `initStudentLoginPage()` in `js/auth.js`.
class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  String? _emailError;
  String? _passwordError;
  bool _submitted = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // "If already logged in, skip straight to dashboard"
      final SessionController session = context.read<SessionController>();
      if (session.student != null && mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/customize', (Route<dynamic> _) => false);
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

    final String? emailError = Validators.loginEmail(email);
    final String? passwordError = Validators.loginPassword(password);

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _submitted = true;
    });
    if (emailError != null || passwordError != null) return;

    setState(() => _busy = true);
    try {
      final student = await context.read<SessionController>().loginStudent(
            email: email,
            password: password,
          );
      if (!mounted) return;
      final String firstName = student.fullName.split(' ').first;
      AppToast.show(
        context,
        'Welcome back, $firstName! 🎂',
        type: ToastType.success,
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/customize', (Route<dynamic> _) => false);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _passwordError = error.message;
      });
    } catch (error) {
      // Never leave the form disabled: an unexpected failure (a plugin or
      // network error) must still re-enable Sign In and say something.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _passwordError = Validators.genericError;
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
                icon: '🎓',
                title: 'Welcome back',
                subtitle:
                    'Sign in with your college account to order your cake.',
                footer: AuthFooterLink(
                  leadingText: 'New to the bakery? ',
                  linkText: 'Create an account',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/student-register'),
                ),
                children: <Widget>[
                  AppTextField(
                    label: 'College Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    hint: 'yourname@yourcollege.edu',
                    error: _submitted ? _emailError : null,
                    autofillHints: const <String>[AutofillHints.email],
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: 'Password',
                    controller: _password,
                    obscure: true,
                    hint: 'Enter your password',
                    error: _submitted ? _passwordError : null,
                    autofillHints: const <String>[AutofillHints.password],
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Sign In',
                    block: true,
                    onPressed: _busy ? null : _submit,
                  ),
                  const SizedBox(height: 24),
                  const DemoBanner(
                    title: 'Demo student account',
                    details: 'ananya.sharma@yourcollege.edu · demo1234',
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
