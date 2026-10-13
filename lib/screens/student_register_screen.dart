import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../state/session_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/validators.dart';
import '../widgets/app_button.dart';
import '../widgets/app_navbar.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/auth_card.dart';
import '../widgets/responsive.dart';

/// `student-register.html` — `initStudentRegisterPage()` in `js/auth.js`.
class StudentRegisterScreen extends StatefulWidget {
  const StudentRegisterScreen({super.key});

  @override
  State<StudentRegisterScreen> createState() => _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends State<StudentRegisterScreen> {
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _studentId = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  String? _fullNameError;
  String? _studentIdError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  bool _submitted = false;
  bool _busy = false;

  /// Set when Firebase Authentication created the account but the Firestore
  /// profile write failed. The next attempt then finishes the *profile* instead
  /// of trying to re-create the account (which would fail: the email is already
  /// in use).
  bool _needsProfileRetry = false;

  @override
  void dispose() {
    _fullName.dispose();
    _studentId.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;

    final String fullName = _fullName.text.trim();
    final String studentId = _studentId.text.trim();
    final String phone = _phone.text.trim();
    final String email = _email.text.trim().toLowerCase();
    final String password = _password.text;
    final String confirmPassword = _confirmPassword.text;

    // The original validates every field and reports them all at once.
    final String? fullNameError = Validators.fullName(fullName);
    final String? studentIdError = Validators.studentId(studentId);
    final String? phoneError = Validators.phone(phone);
    final String? emailError = Validators.collegeEmail(email);
    final String? passwordError = Validators.password(password);
    final String? confirmPasswordError =
        Validators.confirmPassword(confirmPassword, password);

    setState(() {
      _fullNameError = fullNameError;
      _studentIdError = studentIdError;
      _phoneError = phoneError;
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmPasswordError = confirmPasswordError;
      _submitted = true;
    });

    if (fullNameError != null ||
        studentIdError != null ||
        phoneError != null ||
        emailError != null ||
        passwordError != null ||
        confirmPasswordError != null) {
      return;
    }

    setState(() => _busy = true);
    try {
      final SessionController session = context.read<SessionController>();

      // A retry after a partial failure finishes the profile for the account
      // that already exists, rather than creating a second account.
      if (_needsProfileRetry) {
        await session.ensureStudentProfile(
          fullName: fullName,
          studentId: studentId,
          phone: phone,
          email: email,
        );
      } else {
        await session.registerStudent(
          fullName: fullName,
          studentId: studentId,
          phone: phone,
          email: email,
          password: password,
        );
      }

      if (!mounted) return;
      AppToast.show(
        context,
        'Account created! Welcome to Crumb & Cream 🎂',
        type: ToastType.success,
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/customize', (Route<dynamic> _) => false);
    } on ProfileWriteFailure catch (error) {
      // The Auth account exists; keep the session and let the user finish.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _needsProfileRetry = true;
        _emailError = error.message;
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // Duplicate email / duplicate Student ID are reported on their fields.
        if (error.message == Validators.studentIdAlreadyExists) {
          _studentIdError = error.message;
        } else {
          _emailError = error.message;
        }
      });
    } catch (error) {
      // Never leave the form disabled: an unexpected failure (a plugin or
      // network error) must still re-enable Create Account and say something.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _emailError = Validators.genericError;
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
                wide: true,
                backLabel: '← Back to sign in',
                onBack: () => Navigator.of(context)
                    .pushReplacementNamed('/student-login'),
                icon: '🎓',
                title: 'Create your account',
                footer: AuthFooterLink(
                  leadingText: 'Already have an account? ',
                  linkText: 'Sign in',
                  onTap: () => Navigator.of(context)
                      .pushReplacementNamed('/student-login'),
                ),
                children: <Widget>[
                  const _DomainHint(),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: 'Full Name',
                    controller: _fullName,
                    hint: 'e.g. Ananya Sharma',
                    error: _submitted ? _fullNameError : null,
                  ),
                  const SizedBox(height: 20),
                  FormRow(
                    first: AppTextField(
                      label: 'Student ID',
                      controller: _studentId,
                      hint: 'e.g. STU2024010',
                      error: _submitted ? _studentIdError : null,
                    ),
                    second: AppTextField(
                      label: 'Phone Number',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      hint: '10-digit number',
                      error: _submitted ? _phoneError : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: 'College Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    hint: 'yourname@yourcollege.edu',
                    error: _submitted ? _emailError : null,
                  ),
                  const SizedBox(height: 20),
                  FormRow(
                    first: AppTextField(
                      label: 'Password',
                      controller: _password,
                      obscure: true,
                      hint: 'Min. 6 characters',
                      error: _submitted ? _passwordError : null,
                    ),
                    second: AppTextField(
                      label: 'Confirm Password',
                      controller: _confirmPassword,
                      obscure: true,
                      hint: 'Re-enter password',
                      error: _submitted ? _confirmPasswordError : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: _needsProfileRetry
                        ? 'Finish Setting Up Profile'
                        : 'Create Account',
                    block: true,
                    onPressed: _busy ? null : _submit,
                  ),                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `Only students with a valid college email (<strong>@yourcollege.edu</strong>)
/// can register.`
class _DomainHint extends StatelessWidget {
  const _DomainHint();

  @override
  Widget build(BuildContext context) {
    final TextStyle base = AppText.subtitle.copyWith(fontSize: 16);
    return RichText(
      text: TextSpan(
        style: base,
        children: <InlineSpan>[
          const TextSpan(text: 'Only students with a valid college email ('),
          TextSpan(
            text: Validators.collegeEmailDomain,
            style: base.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
          const TextSpan(text: ') can register.'),
        ],
      ),
    );
  }
}
