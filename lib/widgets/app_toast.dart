import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';

/// Toast kinds — `.toast`, `.toast-success`, `.toast-error` in `style.css`.
enum ToastType { info, success, error }

/// `showToast()` in `college-bakery/js/app.js`.
///
/// Same placement (`fixed; top: var(--sp-4); right: var(--sp-4)`), same colours,
/// same 300ms slide-in and same 3200ms visible time before the 300ms fade-out.
class AppToast {
  AppToast._();

  static final ValueNotifier<List<_ToastData>> _toasts =
      ValueNotifier<List<_ToastData>>(<_ToastData>[]);
  static OverlayEntry? _entry;

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
  }) {
    _ensureHost(context);
    final _ToastData toast = _ToastData(message: message, type: type);
    _toasts.value = <_ToastData>[..._toasts.value, toast];
  }

  static void _ensureHost(BuildContext context) {
    if (_entry != null) return;
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (BuildContext _) => _ToastHost(
        toasts: _toasts,
        onDismissed: (int index) {
          final List<_ToastData> items = List<_ToastData>.from(_toasts.value);
          if (index >= 0 && index < items.length) {
            items.removeAt(index);
            _toasts.value = items;
          }
        },
      ),
    );
    overlay.insert(_entry!);
  }
}

class _ToastData {
  const _ToastData({required this.message, required this.type});

  final String message;
  final ToastType type;
}

class _ToastHost extends StatefulWidget {
  const _ToastHost({required this.toasts, required this.onDismissed});

  final ValueNotifier<List<_ToastData>> toasts;
  final ValueChanged<int> onDismissed;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: AppSpacing.sp4,
      right: AppSpacing.sp4,
      child: IgnorePointer(
        ignoring: false,
        child: SafeArea(
          child: ValueListenableBuilder<List<_ToastData>>(
            valueListenable: widget.toasts,
            builder: (
              BuildContext context,
              List<_ToastData> toasts,
              Widget? _,
            ) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int i = 0; i < toasts.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sp2),
                      child: _ToastCard(
                        data: toasts[i],
                        onFinished: () => widget.onDismissed(i),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({required this.data, required this.onFinished});

  final _ToastData data;
  final VoidCallback onFinished;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // `requestAnimationFrame(() => toast.classList.add("show"))`
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    // `setTimeout(…, 3200)` then `setTimeout(remove, 300)`
    Future<void>.delayed(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      setState(() => _visible = false);
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (mounted) widget.onFinished();
      });
    });
  }

  Color get _background {
    switch (widget.data.type) {
      case ToastType.success:
        return AppColors.success;
      case ToastType.error:
        return AppColors.danger;
      case ToastType.info:
        return AppColors.charcoal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      offset: _visible ? Offset.zero : const Offset(0.12, 0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        opacity: _visible ? 1 : 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _background,
            borderRadius: AppRadius.sm,
            boxShadow: AppShadows.lg,
          ),
          child: Text(
            widget.data.message,
            style: AppText.toast,
          ),
        ),
      ),
    );
  }
}
