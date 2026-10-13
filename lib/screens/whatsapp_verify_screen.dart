import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/country_codes.dart';
import '../models/otp_verification.dart';
import '../services/auth_service.dart';
import '../services/whatsapp_otp_service.dart';
import '../state/session_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../utils/phone_number.dart';
import '../utils/validators.dart';
import '../widgets/app_button.dart';
import '../widgets/app_navbar.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/auth_card.dart';
import '../widgets/responsive.dart';

/// The WhatsApp one-time-code screen.
///
/// One screen, two modes, chosen from the session rather than from a route
/// argument so it cannot be spoofed:
///
/// * **signed out** → sign in: a correct code returns a Firebase custom token,
///   which becomes a real session via `SessionController.loginWithWhatsAppOtp`;
/// * **signed in** → link: the code attaches the number to the caller's own
///   account (the uid is taken from the request's ID token on the server).
///
/// The app never sees, generates or stores a code, and there is no client-side
/// bypass: every outcome here comes from the trusted Cloud Function plus
/// Twilio's own verification result.
class WhatsAppVerifyScreen extends StatefulWidget {
  const WhatsAppVerifyScreen({super.key, this.service});

  /// Injectable so widget tests can run without Firebase.
  final WhatsAppOtpService? service;

  @override
  State<WhatsAppVerifyScreen> createState() => _WhatsAppVerifyScreenState();
}

enum _Step { phone, code }

class _WhatsAppVerifyScreenState extends State<WhatsAppVerifyScreen> {
  late final WhatsAppOtpService _service = widget.service ?? WhatsAppOtpService();
  late final TextEditingController _country =
      TextEditingController(text: _dialCode.label);

  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();

  CountryDialCode _dialCode = kDefaultCountry;
  _Step _step = _Step.phone;
  bool _linkMode = false;
  bool _busy = false;
  bool _noAccount = false;
  String? _phoneError;
  String? _codeError;
  OtpChallenge? _challenge;
  Timer? _countdown;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    final SessionController session = context.read<SessionController>();
    // Linking needs an existing session; otherwise this is a sign-in.
    _linkMode = session.student != null || session.owner != null;
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _country.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String? get _phoneE164 =>
      PhoneNumber.toE164(_phone.text, dialCode: _dialCode.dialCode);

  // ---------------- actions ----------------

  Future<void> _pickCountry() async {
    final CountryDialCode? picked = await showModalBottomSheet<CountryDialCode>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: ListView.builder(
            itemCount: kCountryDialCodes.length,
            itemBuilder: (BuildContext _, int index) {
              final CountryDialCode country = kCountryDialCodes[index];
              return ListTile(
                title: Text(country.name, style: AppText.paragraph),
                trailing: Text(
                  country.dialCode,
                  style: AppText.inter(size: 14, color: AppColors.textMuted),
                ),
                onTap: () => Navigator.of(sheetContext).pop(country),
              );
            },
          ),
        ),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      _dialCode = picked;
      _country.text = picked.label;
      _phoneError = null;
    });
  }

  Future<void> _requestCode({required bool isResend}) async {
    if (_busy) return;

    final String? phoneError =
        Validators.otpPhoneNumber(_phone.text, dialCode: _dialCode.dialCode);
    final String? e164 = _phoneE164;

    if (phoneError != null || e164 == null) {
      setState(() {
        _phoneError = phoneError ?? Validators.otpPhoneInvalid;
        if (!isResend) _step = _Step.phone;
      });
      return;
    }

    setState(() {
      _busy = true;
      _phoneError = null;
      _codeError = null;
      _noAccount = false;
    });

    try {
      final OtpChallenge challenge = await _service.requestCode(phoneE164: e164);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _challenge = challenge;
        _step = _Step.code;
        _code.clear();
      });
      _startCountdown(challenge.resendAfterSeconds);
      AppToast.show(
        context,
        'Code sent on WhatsApp to ${challenge.phoneMasked}',
        type: ToastType.info,
      );
    } on OtpException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (error.failure == OtpFailure.rateLimited &&
            error.retryAfterSeconds != null) {
          // The server owns the limit; mirror it in the countdown.
          _startCountdown(error.retryAfterSeconds!);
          _step = _Step.code;
          _codeError = error.message;
        } else if (isResend) {
          _codeError = error.message;
        } else {
          _phoneError = error.message;
          _step = _Step.phone;
        }
      });
    } catch (error) {
      // Never leave the form stuck: an unexpected plugin/network failure must
      // re-enable the button and say something.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _phoneError = Validators.genericError;
        if (!isResend) _step = _Step.phone;
      });
    }
  }

  Future<void> _verify() async {
    if (_busy) return;

    // Captured before any await so no BuildContext is used across an async gap.
    final SessionController session = context.read<SessionController>();
    final String? codeError = Validators.otpCode(_code.text);
    final String? e164 = _phoneE164;

    if (codeError != null || e164 == null) {
      setState(() => _codeError = codeError ?? Validators.otpPhoneInvalid);
      return;
    }

    setState(() {
      _busy = true;
      _codeError = null;
      _noAccount = false;
    });

    try {
      if (_linkMode) {
        await _service.linkNumber(phoneE164: e164, code: _code.text.trim());
        if (!mounted) return;
        await session.reloadStudentProfile();
        if (!mounted) return;
        AppToast.show(
          context,
          'WhatsApp number verified ✅',
          type: ToastType.success,
        );
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        Navigator.of(context).maybePop();
        return;
      }

      final WhatsAppVerification verification = await _service.verifyCode(
        phoneE164: e164,
        code: _code.text.trim(),
      );
      final String? customToken = verification.customToken;
      if (customToken == null) {
        // The model rejects this shape, so treat it as a failed sign-in rather
        // than ever navigating as though it worked.
        throw OtpException(OtpFailure.unknown);
      }

      final SessionSignIn result =
          await session.loginWithWhatsAppOtp(customToken: customToken);
      if (!mounted) return;

      AppToast.show(
        context,
        result.isOwner
            ? 'Welcome back to the bakery dashboard!'
            : 'Signed in with WhatsApp 🎂',
        type: ToastType.success,
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        result.isOwner ? '/owner-dashboard' : '/customize',
        (Route<dynamic> _) => false,
      );
    } on OtpException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        switch (error.failure) {
          case OtpFailure.invalidPhone:
            _step = _Step.phone;
            _phoneError = error.message;
          case OtpFailure.noAccount:
            // Only ever reported after the provider approved the code.
            _noAccount = true;
          case OtpFailure.rateLimited || OtpFailure.tooManyAttempts:
            _codeError = error.message;
            if (error.retryAfterSeconds != null) {
              _startCountdown(error.retryAfterSeconds!);
            }
          default:
            _codeError = error.message;
        }
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _codeError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _codeError = Validators.genericError;
      });
    }
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    setState(() => _secondsLeft = seconds);
    if (seconds <= 0) return;
    _countdown = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft -= 1;
        if (_secondsLeft <= 0) {
          _secondsLeft = 0;
          timer.cancel();
        }
      });
    });
  }

  void _changeNumber() {
    _countdown?.cancel();
    setState(() {
      _step = _Step.phone;
      _challenge = null;
      _codeError = null;
      _noAccount = false;
      _secondsLeft = 0;
      _code.clear();
    });
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/', (Route<dynamic> _) => false);
    }
  }

  // ---------------- build ----------------

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
                backLabel: _linkMode ? '← Back' : '← Back to sign in',
                onBack: _goBack,
                icon: '💬',
                title: _linkMode
                    ? 'Verify your WhatsApp number'
                    : 'Sign in with WhatsApp',
                subtitle: _linkMode
                    ? 'Confirm this number belongs to you and we will add it to your account.'
                    : 'We will send a one-time code on WhatsApp to confirm your number.',
                footer: _linkMode
                    ? null
                    : AuthFooterLink(
                        leadingText: 'Prefer your college email? ',
                        linkText: 'Sign in with email',
                        onTap: () => Navigator.of(context)
                            .pushReplacementNamed('/student-login'),
                      ),
                children: _step == _Step.phone ? _phoneStep() : _codeStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _phoneStep() {
    return <Widget>[
      FormRow(
        first: AppTextField(
          label: 'Country',
          controller: _country,
          readOnly: true,
          onTap: _pickCountry,
          trailingIcon: const Icon(
            Icons.arrow_drop_down,
            color: AppColors.textMuted,
          ),
        ),
        second: AppTextField(
          label: 'WhatsApp Number',
          controller: _phone,
          keyboardType: TextInputType.phone,
          hint: '9876543210',
          error: _phoneError,
          maxLength: 15,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(15),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.sp3),
      Text(
        'By continuing you agree to receive a one-time verification code on '
        'WhatsApp. Standard message rates may apply.',
        style: AppText.inter(size: 13, color: AppColors.textMuted, height: 1.4),
      ),
      const SizedBox(height: AppSpacing.sp5),
      AppButton(
        label: _linkMode ? 'Send code to verify' : 'Send code on WhatsApp',
        block: true,
        onPressed: _busy ? null : () => _requestCode(isResend: false),
      ),
      ..._noAccountBlock(),
    ];
  }

  /// Shown on both steps once the backend has reported `no-account` — which it
  /// only does after WhatsApp confirmed the code, so this never reveals whether
  /// a number is registered before the user proves they own it.
  List<Widget> _noAccountBlock() {
    if (!_noAccount) return const <Widget>[];
    return <Widget>[
      const SizedBox(height: AppSpacing.sp4),
      const _Notice(
        title: 'No account found for this number',
        body: 'Create your student account with your college email first, '
            'then verify this WhatsApp number from your profile.',
      ),
      const SizedBox(height: AppSpacing.sp3),
      AppButton(
        label: 'Create an account',
        variant: AppButtonVariant.secondary,
        block: true,
        onPressed: () => Navigator.of(context).pushNamed('/student-register'),
      ),
    ];
  }

  List<Widget> _codeStep() {
    final String masked = _challenge?.phoneMasked ?? PhoneNumber.mask(
      _phoneE164 ?? '',
    );

    return <Widget>[
      _Notice(
        title: 'Enter the 6-digit code',
        body: 'We sent a code on WhatsApp to $masked. It expires shortly, so '
            'enter it as soon as it arrives.',
      ),
      const SizedBox(height: AppSpacing.sp5),
      AppTextField(
        label: 'Verification code',
        controller: _code,
        keyboardType: TextInputType.number,
        hint: '6-digit code',
        error: _codeError,
        maxLength: 6,
        autofillHints: const <String>[AutofillHints.oneTimeCode],
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
      ),
      const SizedBox(height: AppSpacing.sp5),
      AppButton(
        label: 'Verify code',
        block: true,
        onPressed: _busy ? null : _verify,
      ),
      const SizedBox(height: AppSpacing.sp3),
      Center(
        child: _secondsLeft > 0
            ? Text(
                'Resend code in ${_formatSeconds(_secondsLeft)}',
                style:
                    AppText.inter(size: 14, color: AppColors.textMuted),
              )
            : InkWell(
                onTap: _busy ? null : () => _requestCode(isResend: true),
                child: Text(
                  'Resend code',
                  style: AppText.inter(
                    size: 14,
                    weight: FontWeight.w600,
                    color: AppColors.coralDark,
                  ),
                ),
              ),
      ),
      const SizedBox(height: AppSpacing.sp2),
      Center(
        child: InkWell(
          onTap: _busy ? null : _changeNumber,
          child: Text(
            'Use a different number',
            style: AppText.inter(size: 13.5, color: AppColors.textMuted),
          ),
        ),
      ),
      ..._noAccountBlock(),
    ];
  }

  static String _formatSeconds(int seconds) {
    final int minutes = seconds ~/ 60;
    final int rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }
}

/// A small inline information box used for the code prompt and the
/// "no account found" state.
class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: AppRadius.sm,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppText.cardTitle),
          const SizedBox(height: 4),
          Text(
            body,
            style: AppText.inter(size: 13.5, color: AppColors.textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
