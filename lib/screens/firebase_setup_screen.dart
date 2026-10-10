import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_navbar.dart';
import '../widgets/page_container.dart';

/// Shown only when `Firebase.initializeApp` fails — normally because
/// `lib/firebase_options.dart` still holds the placeholder values.
///
/// The original prototype had no backend at all; every screen here reads from
/// Firebase Authentication, Firestore and Storage, so the app needs a real
/// project before the landing page can be reached.
class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({required this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            AppNavBar(
              brandLabel: AppConfig.appTitle,
              onBrandTap: () {},
              entries: const <NavEntry>[],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: PageContainer(
                  maxWidth: 720,
                  top: AppSpacing.sp7,
                  bottom: AppSpacing.sp8,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sp6),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: AppRadius.lg,
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppShadows.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('🔧', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: AppSpacing.sp3),
                        Text('Connect your Firebase project',
                            style: AppText.h2),
                        const SizedBox(height: AppSpacing.sp3),
                        Text(
                          'The Flutter app uses Firebase Authentication for '
                          'sign-in, Cloud Firestore for accounts, orders and '
                          'notifications, and Firebase Storage for reference '
                          'photos.',
                          style: AppText.paragraph,
                        ),
                        const SizedBox(height: AppSpacing.sp5),
                        const _Step(
                          '1',
                          'Create a Firebase project (or pick an existing one) '
                              'and add an Android app plus an iOS app.',
                        ),
                        const _Step(
                          '2',
                          'Run `flutterfire configure` from the '
                              'college_bakery_flutter folder and choose that '
                              'project. It rewrites lib/firebase_options.dart '
                              'and adds google-services.json / '
                              'GoogleService-Info.plist.',
                        ),
                        const _Step(
                          '3',
                          'Publish the Firestore and Storage rules from '
                              'firestore.rules and storage.rules in the '
                              'project root.',
                        ),
                        const _Step(
                          '4',
                          'Enable Email/Password sign-in under '
                              'Authentication → Sign-in method.',
                        ),
                        const _Step(
                          '5',
                          'Relaunch the app. The demo students, orders and '
                              'notifications seed themselves on first run.',
                        ),
                        if (message != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.sp4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.sp3),
                            decoration: BoxDecoration(
                              color: AppColors.coralLight,
                              borderRadius: AppRadius.sm,
                            ),
                            child: Text(
                              message!,
                              style: AppText.inter(
                                size: 13,
                                color: AppColors.coralDark,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _Step extends StatelessWidget {
  const _Step(this.number, this.text);

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sp3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.coralLight,
              borderRadius: AppRadius.pill,
            ),
            child: Text(
              number,
              style: AppText.inter(
                size: 12,
                weight: FontWeight.w700,
                color: AppColors.coralDark,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sp2),
          Expanded(
            child: Text(
              text,
              style: AppText.inter(size: 14, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}
