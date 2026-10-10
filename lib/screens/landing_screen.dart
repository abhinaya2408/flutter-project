import 'package:flutter/material.dart';

import '../data/catalog.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../utils/breakpoints.dart';
import '../widgets/app_button.dart';
import '../widgets/app_footer.dart';
import '../widgets/app_navbar.dart';
import '../widgets/cake_image.dart';
import '../widgets/page_container.dart';
import '../widgets/responsive.dart';
import '../widgets/section_head.dart';

/// The landing page — a port of `college-bakery/index.html`.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final GlobalKey _popularKey = GlobalKey();
  final GlobalKey _howItWorksKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openStudentLogin() => Navigator.of(context).pushNamed('/student-login');

  void _openBakeryLogin() => Navigator.of(context).pushNamed('/bakery-login');

  void _scrollTo(GlobalKey key) {
    final BuildContext? target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
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
              onBrandTap: _scrollToTop,
              entries: <NavEntry>[
                NavEntry(
                  label: 'Popular Cakes',
                  onTap: () => _scrollTo(_popularKey),
                ),
                NavEntry(
                  label: 'How It Works',
                  onTap: () => _scrollTo(_howItWorksKey),
                ),
                NavEntry(label: 'Student Login', onTap: _openStudentLogin),
                NavEntry(label: 'Bakery Member', onTap: _openBakeryLogin),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _hero(),
                    _getStarted(),
                    _popularCakes(),
                    _howItWorks(),
                    _whyOrderWithUs(),
                    _inspirationBanner(),
                    _testimonials(),
                    AppFooter(
                      onSignIn: _openStudentLogin,
                      onCreateAccount: () =>
                          Navigator.of(context).pushNamed('/student-register'),
                      onPopularCakes: () => _scrollTo(_popularKey),
                      onBakeryLogin: _openBakeryLogin,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // ---------- `.hero` ----------
  Widget _hero() {
    return Container(
      padding: const EdgeInsets.only(
        top: AppSpacing.sp8,
        bottom: AppSpacing.sp7,
      ),
      child: PageContainer(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool stacked = constraints.maxWidth <= Breakpoints.wide;
            final Widget copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.coralLight,
                    borderRadius: AppRadius.pill,
                  ),
                  child: Text(
                    '🎂 College Bakery Ordering',
                    style: AppText.inter(
                      size: 13,
                      weight: FontWeight.w600,
                      color: AppColors.coralDark,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sp3),
                Text(
                  'Your Cake, Your Way.',
                  style: stacked
                      ? AppText.heroTitleMobile
                      : AppText.heroTitle,
                ),
                const SizedBox(height: AppSpacing.sp3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Text(
                    'Create a cake that feels personal. Choose your flavors, design, message and share your inspiration with our college bakery.',
                    style: AppText.heroLead,
                  ),
                ),
                const SizedBox(height: AppSpacing.sp5),
                _heroCtas(stacked),
              ],
            );

            final Widget visual = ClipRRect(
              borderRadius: AppRadius.lg,
              child: AspectRatio(
                aspectRatio: AppLayout.heroAspect,
                child: CakeImage(imageUrl: CakeImages.hero),
              ),
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  visual,
                  const SizedBox(height: AppSpacing.sp7),
                  copy,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(child: copy),
                const SizedBox(width: AppSpacing.sp7),
                Expanded(child: visual),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _heroCtas(bool stacked) {
    final List<Widget> buttons = <Widget>[
      AppButton(
        label: 'Customize Your Cake',
        onPressed: _openStudentLogin,
        block: stacked,
      ),
      AppButton(
        label: 'Explore Cakes',
        variant: AppButtonVariant.secondary,
        onPressed: () => _scrollTo(_popularKey),
        block: stacked,
      ),
    ];

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          buttons[0],
          const SizedBox(height: AppSpacing.sp3),
          buttons[1],
        ],
      );
    }
    return Wrap(
      spacing: AppSpacing.sp3,
      runSpacing: AppSpacing.sp3,
      children: buttons,
    );
  }

  // ---------- "Get Started" ----------
  Widget _getStarted() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sp7),
      child: PageContainer(
        child: Column(
          children: <Widget>[
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sp6),
                child: _H2('Get Started', center: true),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ResponsiveGrid(
                  desktopColumns: 2,
                  tabletColumns: 1,
                  mobileColumns: 1,
                  gap: AppSpacing.sp5,
                  children: <Widget>[
                    _RoleCard(
                      icon: '🎓',
                      title: 'Continue as Student',
                      description:
                          'Customize and order your cake, then track it until pickup.',
                      onTap: _openStudentLogin,
                    ),
                    _RoleCard(
                      icon: '🧁',
                      title: 'Bakery Owner',
                      description:
                          'Manage incoming orders and update preparation status.',
                      onTap: _openBakeryLogin,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- "Popular Cakes" ----------
  Widget _popularCakes() {
    return Padding(
      key: _popularKey,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sp7),
      child: PageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sp5),
              child: SectionHead(
                title: 'Popular Cakes',
                subtitle:
                    'Student favorites, freshly baked every day on campus.',
                trailing: AppButton(
                  label: 'Customize a Cake',
                  variant: AppButtonVariant.outline,
                  onPressed: _openStudentLogin,
                ),
              ),
            ),
            ResponsiveGrid(
              desktopColumns: 3,
              tabletColumns: 2,
              mobileColumns: 1,
              gap: AppSpacing.sp5,
              children: <Widget>[
                for (final Flavor flavor in kFlavors.take(6))
                  _PopularCakeCard(
                    flavor: flavor,
                    onTap: _openStudentLogin,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- "How It Works" (white section) ----------
  Widget _howItWorks() {
    return Container(
      key: _howItWorksKey,
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sp7),
      child: PageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sp5),
              child: SectionHead(
                title: 'How It Works',
                subtitle: 'From flavor to pickup in three simple steps.',
              ),
            ),
            ResponsiveGrid(
              desktopColumns: 3,
              tabletColumns: 2,
              mobileColumns: 1,
              gap: AppSpacing.sp5,
              children: const <Widget>[
                _StepCard(
                  number: '01',
                  title: 'Customize',
                  description: 'Choose flavor, size, cream and decorations.',
                ),
                _StepCard(
                  number: '02',
                  title: 'Share Your Idea',
                  description:
                      'Upload a reference photo and add special instructions.',
                ),
                _StepCard(
                  number: '03',
                  title: 'Collect',
                  description:
                      'Track your order and get notified when your cake is ready.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- "Why Order With Us?" ----------
  Widget _whyOrderWithUs() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sp7),
      child: PageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sp5),
              child: SectionHead(
                title: 'Why Order With Us?',
                subtitle: 'Built by students, for students — made simple.',
              ),
            ),
            ResponsiveGrid(
              desktopColumns: 4,
              tabletColumns: 2,
              mobileColumns: 1,
              gap: AppSpacing.sp4,
              children: const <Widget>[
                _FeatureCard(
                  icon: '📸',
                  title: 'Share Inspiration',
                  description:
                      'Upload a reference photo so we get your vision right.',
                ),
                _FeatureCard(
                  icon: '🔔',
                  title: 'Live Updates',
                  description:
                      'Get notified the moment your order status changes.',
                ),
                _FeatureCard(
                  icon: '💸',
                  title: 'Transparent Pricing',
                  description:
                      'See your exact price update as you customize.',
                ),
                _FeatureCard(
                  icon: '🎂',
                  title: 'Made On Campus',
                  description: 'Freshly baked and ready for easy pickup.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- "Custom Cake Inspiration" banner ----------
  Widget _inspirationBanner() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sp7),
      child: PageContainer(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool stacked = constraints.maxWidth <= Breakpoints.wide;
            final Widget copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Custom Cake Inspiration',
                  style: AppText.h2.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: AppSpacing.sp3),
                Text(
                  'Got a design in mind? Upload a photo when you customize and our bakers will use it as a reference for your cake.',
                  style: AppText.paragraph.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: AppSpacing.sp3),
                AppButton(
                  label: 'Start Customizing',
                  variant: AppButtonVariant.secondary,
                  onPressed: _openStudentLogin,
                ),
              ],
            );

            final Widget image = ClipRRect(
              borderRadius: AppRadius.md,
              child: AspectRatio(
                aspectRatio: AppLayout.cakeImageAspect,
                child: CakeImage(imageUrl: CakeImages.custom),
              ),
            );

            return Container(
              padding: EdgeInsets.all(stacked ? AppSpacing.sp5 : AppSpacing.sp7),
              decoration: BoxDecoration(
                color: AppColors.coral,
                borderRadius: AppRadius.lg,
              ),
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        copy,
                        const SizedBox(height: AppSpacing.sp6),
                        image,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(flex: 12, child: copy),
                        const SizedBox(width: AppSpacing.sp6),
                        Expanded(flex: 10, child: image),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  // ---------- "What Students Say" ----------
  Widget _testimonials() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sp7),
      child: PageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sp5),
              child: SectionHead(
                title: 'What Students Say',
                subtitle: 'Demo reviews from our college community.',
              ),
            ),
            ResponsiveGrid(
              desktopColumns: 3,
              tabletColumns: 2,
              mobileColumns: 1,
              gap: AppSpacing.sp5,
              children: const <Widget>[
                _TestimonialCard(
                  quote:
                      '"Ordered a birthday cake for my roommate and uploaded a reference photo — it came out almost identical!"',
                  initial: 'A',
                  name: 'Ananya S.',
                  detail: '3rd Year, CSE',
                ),
                _TestimonialCard(
                  quote:
                      '"Loved how easy the customization page was. Picked flavor, size, and decorations in under two minutes."',
                  initial: 'P',
                  name: 'Priya V.',
                  detail: '2nd Year, ECE',
                ),
                _TestimonialCard(
                  quote:
                      '"Got notified the second my cake was ready for pickup. No more waiting around outside the bakery."',
                  initial: 'R',
                  name: 'Rahul N.',
                  detail: 'Final Year, ME',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _H2 extends StatelessWidget {
  const _H2(this.text, {this.center = false});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: AppText.h2,
    );
  }
}

/// `.role-card` — the two "Get Started" cards.
class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
          padding: const EdgeInsets.all(AppSpacing.sp6),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppRadius.lg,
            border: Border.all(
              color: _hovered ? AppColors.coral : AppColors.border,
              width: AppBorders.regular,
            ),
            boxShadow: _hovered ? AppShadows.md : null,
          ),
          child: Column(
            children: <Widget>[
              Text(widget.icon, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: AppSpacing.sp3),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: AppText.h3,
              ),
              const SizedBox(height: AppSpacing.sp2),
              Text(
                widget.description,
                textAlign: TextAlign.center,
                style: AppText.paragraph,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.cake-card` — a popular cake tile.
class _PopularCakeCard extends StatefulWidget {
  const _PopularCakeCard({required this.flavor, required this.onTap});

  final Flavor flavor;
  final VoidCallback onTap;

  @override
  State<_PopularCakeCard> createState() => _PopularCakeCardState();
}

class _PopularCakeCardState extends State<_PopularCakeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Flavor flavor = widget.flavor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.border),
            boxShadow: _hovered ? AppShadows.md : AppShadows.sm,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // `Flexible` because the card's height comes from the grid's
                // `IntrinsicHeight` row: at some phone widths the text below is
                // a few pixels taller than the row the intrinsic pass
                // estimated, and the photo has to give up those pixels instead
                // of overflowing.
                Flexible(
                  child: AspectRatio(
                    aspectRatio: AppLayout.cakeImageAspect,
                    child: CakeImage(imageUrl: CakeImages.byKey(flavor.key)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sp4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('${flavor.id} Cake', style: AppText.cardTitle),
                      const SizedBox(height: 4),
                      Text(
                        flavor.desc,
                        style: AppText.meta.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: AppSpacing.sp2),
                      Text(
                        'From ₹${flavorStartingPrice(flavor)}',
                        style: AppText.inter(
                          size: 16,
                          weight: FontWeight.w700,
                          color: AppColors.coralDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.step-card`
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sp5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            number,
            style: AppText.poppins(size: 28, color: AppColors.coral),
          ),
          const SizedBox(height: AppSpacing.sp2),
          Text(title, style: AppText.h3),
          const SizedBox(height: AppSpacing.sp2),
          Text(description, style: AppText.paragraph),
        ],
      ),
    );
  }
}

/// `.feature-card`
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final String icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(bottom: AppSpacing.sp3),
          decoration: BoxDecoration(
            color: AppColors.coralLight,
            borderRadius: AppRadius.sm,
          ),
          child: Text(icon, style: const TextStyle(fontSize: 22)),
        ),
        Text(title, style: AppText.h3),
        const SizedBox(height: AppSpacing.sp2),
        Text(description, style: AppText.paragraph),
      ],
    );
  }
}

/// `.testimonial-card`
class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({
    required this.quote,
    required this.initial,
    required this.name,
    required this.detail,
  });

  final String quote;
  final String initial;
  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sp5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '★★★★★',
            style: AppText.inter(
              size: 14,
              color: AppColors.coral,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sp2),
          Text(quote, style: AppText.paragraph),
          const SizedBox(height: AppSpacing.sp3),
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.coralLight,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: AppText.inter(
                    size: 16,
                    weight: FontWeight.w700,
                    color: AppColors.coralDark,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sp2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    style: AppText.inter(
                      size: 16,
                      weight: FontWeight.w700,
                      color: AppColors.text,
                      height: 1.3,
                    ),
                  ),
                  Text(
                    detail,
                    style: AppText.inter(
                      size: 12,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
