import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/catalog.dart';
import '../models/customization_draft.dart';
import '../models/order.dart';
import '../data/order_status.dart';
import '../services/cloudinary_image_service.dart';
import '../services/order_service.dart';
import '../services/reference_image_service.dart';
import '../state/customize_controller.dart';
import '../state/session_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../utils/breakpoints.dart';
import '../utils/formatters.dart';
import '../utils/pricing.dart';
import '../utils/validators.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/cake_image.dart';
import '../widgets/form_section.dart';
import '../widgets/option_tiles.dart';
import '../widgets/page_container.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/responsive.dart';
import '../widgets/upload_area.dart';

/// `customize.html` — `initCustomizePage()` in `js/customize.js`.
class CustomizeScreen extends StatefulWidget {
  const CustomizeScreen({super.key});

  @override
  State<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends State<CustomizeScreen> {
  final CustomizeController _controller = CustomizeController();
  final TextEditingController _cakeMessage = TextEditingController();
  final TextEditingController _specialInstructions = TextEditingController();

  String? _formError;
  String? _dateError;
  String? _timeError;
  bool _submitting = false;

  /// The id reserved for the submission in progress. A retry after a failure
  /// reuses it, so a timeout, a slow network or a double tap cannot create a
  /// second order for the same submission.
  String? _pendingOrderId;

  /// The reference photo already uploaded during this submission, and the pick
  /// it belongs to. Cached so a retry after a failed order write does not
  /// upload the same photo again (which would orphan a Cloudinary asset).
  String? _uploadedImageUrl;
  String? _uploadedImageFor;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _cakeMessage.dispose();
    _specialInstructions.dispose();
    super.dispose();
  }

  // ---------- Reference image (`wireImageUpload()`) ----------
  Future<void> _chooseImage() async {
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (picked == null) return;

      final String name = picked.name;
      final String extension =
          name.contains('.') ? name.split('.').last.toLowerCase() : '';
      final String? mime = picked.mimeType?.toLowerCase();
      final bool typeAllowed = mime != null && mime.isNotEmpty
          ? Validators.allowedImageMimeTypes.contains(mime)
          : Validators.allowedImageExtensions.contains(extension);
      if (!typeAllowed) {
        _controller.setImageError(Validators.imageTypeInvalid);
        return;
      }

      final int length = await picked.length();
      if (length > Validators.maxImageBytes) {
        _controller.setImageError(Validators.imageTooLarge);
        return;
      }

      final Uint8List bytes = await picked.readAsBytes();
      _controller.setReferenceImage(
        ReferenceImageFile(name: name, size: bytes.length, bytes: bytes),
      );
    } catch (_) {
      _controller.setImageError(Validators.imageReadFailed);
    }
  }

  // ---------- Pickup date & time (`wireDateTime()`) ----------
  Future<void> _pickDate() async {
    final DateTime today = DateTime.now();
    final DateTime initial = Formatters.parseDateOnly(
          _controller.draft.requiredDate ?? '',
        ) ??
        today;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: today,
      lastDate: DateTime(today.year + 2),
    );
    if (picked == null) return;
    _controller.setRequiredDate(Formatters.dateOnly(picked));
  }

  Future<void> _pickTime() async {
    final String? current = _controller.draft.requiredTime;
    TimeOfDay initial = TimeOfDay.now();
    if (current != null && current.contains(':')) {
      final List<String> parts = current.split(':');
      initial = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? initial.hour,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    _controller.setRequiredTime(
      Formatters.timeValue(picked.hour, picked.minute),
    );
  }

  // ---------- Place order (`placeOrder()`) ----------
  Future<void> _placeOrder() async {
    if (_submitting) return;

    final PlaceOrderValidation validation = _controller.validate();
    setState(() {
      _formError = validation.formError;
      _dateError = validation.dateError;
      _timeError = validation.timeError;
    });

    if (!validation.isValid) {
      AppToast.show(
        context,
        'Please fill in all required fields.',
        type: ToastType.error,
      );
      return;
    }

    // The session carries the profile, but only Firebase Authentication carries
    // the credential Firestore actually checks. Verify both: a stale in-memory
    // profile with a missing/expired Auth session is exactly the state that
    // produces `cloud_firestore/permission-denied` on the write below.
    final SessionController session = context.read<SessionController>();
    final student = session.student;
    final String? blockReason = OrderPlacementGuard.blockReason(
      studentUid: student?.uid,
      authUid: _signedInUid(),
    );

    // `student == null` is repeated here only so the compiler can promote the
    // type for the order fields below; the guard above already covers the case.
    if (blockReason != null || student == null) {
      // This used to be a silent `return`, which looked like a dead button.
      AppToast.show(
        context,
        blockReason ?? 'Please sign in before placing an order.',
        type: ToastType.error,
      );
      await session.logoutStudent();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/student-login',
        (Route<dynamic> _) => false,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final OrderService orderService = OrderService();

      // One id per submission, reused by every retry.
      final String orderId =
          _pendingOrderId ??= await orderService.generateOrderId();

      String referenceImage = '';
      final ReferenceImageFile? file = _controller.draft.referenceImage;

      if (file != null) {
        final String fileKey = '${file.name}:${file.size}';
        try {
          // Upload once per pick: a retry reuses the URL already obtained.
          if (_uploadedImageUrl == null || _uploadedImageFor != fileKey) {
            _uploadedImageUrl = await ReferenceImageService()
                .uploadReferenceImage(file: file, orderId: orderId);
            _uploadedImageFor = fileKey;
          }
          referenceImage = _uploadedImageUrl!;
        } on CloudinaryUploadException catch (error) {
          _reportUploadFailure(error.message);
          return;
        } on FirebaseException catch (error) {
          _reportUploadFailure('Photo upload failed (${error.code}).');
          return;
        }
      }
      final CustomizationDraft draft = _controller.draft;
      final PriceBreakdown price = _controller.price;

      final Order order = Order(
        orderId: orderId,
        studentId: student.studentId,
        studentName: student.fullName,
        studentEmail: student.email,
        studentPhone: student.phone,
        flavor: draft.flavor!,
        cakeType: draft.cakeType!,
        size: draft.size!,
        cream: draft.cream!,
        decorations: draft.decorations,
        cakeMessage: draft.cakeMessage.trim(),
        specialInstructions: draft.specialInstructions.trim(),
        referenceImage: referenceImage,
        requiredDate: draft.requiredDate!,
        requiredTime: draft.requiredTime!,
        estimatedPrice: price.total,
        status: OrderStatus.pending,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );

      // Success is reported only once Firestore has accepted the write.
      await orderService.createOrder(order);
      if (!mounted) return;
      AppToast.show(
        context,
        'Order placed successfully! 🎂',
        type: ToastType.success,
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.of(context).pushNamed(
        '/order-confirmation',
        arguments: orderId,
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.show(context, _orderWriteMessage(error), type: ToastType.error);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.show(
        context,
        'Could not place your order. Please try again. (${error.runtimeType})',
        type: ToastType.error,
      );
    }
  }

  /// The signed-in Firebase uid, or `null` when it cannot be established.
  ///
  /// Reading `FirebaseAuth.instance` throws when Firebase is not initialised;
  /// that is a "no usable session" condition, not a crash worth showing a
  /// student in the middle of checkout.
  String? _signedInUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Reports a failed photo upload without ever implying the order was saved.
  void _reportUploadFailure(String message) {
    if (!mounted) return;
    setState(() => _submitting = false);
    AppToast.show(
      context,
      '$message Your order was not placed — you can retry, or submit without '
      'a photo.',
      type: ToastType.error,
    );
  }

  /// Turns a Firestore failure into something a student can act on, instead of
  /// dumping a raw exception into a toast.
  String _orderWriteMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Firestore refused to save the order (permission-denied): the '
            'database security rules do not allow this write. See '
            'docs/ORDER_PLACEMENT.md.';
      case 'unauthenticated':
        return 'Your session expired. Please sign in again.';
      case 'unavailable':
        return Validators.networkUnavailable;
      case 'deadline-exceeded':
        return 'Saving the order timed out. Please try again.';
      default:
        return 'Could not save your order (${error.code}). Please try again.';
    }
  }

  /// The persistent checkout bar — price on the left, one primary action on the
  /// right, always reachable without scrolling back up.
  ///
  /// The action stays tappable while selections are incomplete on purpose: a
  /// disabled primary button that explains nothing is the "silently does
  /// nothing" failure mode. The hint under it always names what is still
  /// missing, and tapping surfaces the detailed field errors.
  Widget _checkoutBar() {
    final PlaceOrderValidation validation = _controller.validate();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.border, width: AppBorders.regular),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sp5,
            vertical: AppSpacing.sp3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Estimated Total',
                        style: AppText.inter(
                          size: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '₹${_controller.total}',
                        style: AppText.poppins(size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.sp4),
                  Expanded(
                    child: AppButton(
                      label:
                          _submitting ? 'Placing order…' : 'Place Cake Order',
                      block: true,
                      onPressed: _submitting ? null : _placeOrder,
                    ),
                  ),
                ],
              ),
              if (!validation.isValid)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sp2),
                  child: Text(
                    validation.formError ?? '',
                    style: AppText.inter(
                      size: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StudentPageScaffold(
      activeTab: 'customize',
      bottomBar: _checkoutBar(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            PageContainer(
              top: AppSpacing.sp6,
              bottom: AppSpacing.sp4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Customize Your Cake', style: AppText.pageHeader),
                  const SizedBox(height: AppSpacing.sp2),
                  Text(
                    "Choose every detail — we'll bake it exactly the way you imagine it.",
                    style: AppText.paragraph,
                  ),
                ],
              ),
            ),
            PageContainer(
              bottom: AppSpacing.sp8,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool stacked =
                      constraints.maxWidth <= Breakpoints.desktop;
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _previewColumn(),
                        const SizedBox(height: AppSpacing.sp4),
                        _formColumn(),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(flex: 13, child: _formColumn()),
                      const SizedBox(width: AppSpacing.sp6),
                      Expanded(
                        flex: 10,
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: _previewColumn(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Left column: the form ----------
  Widget _formColumn() {
    final CustomizationDraft draft = _controller.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FormSection(
          title: '🎂 Cake Flavor',
          isRequired: true,
          child: ResponsiveGrid(
            desktopColumns: 3,
            // `.flavor-grid` drops to 2 columns under 980px and keeps 2 on
            // phones.
            tabletColumns: 2,
            tabletBreakpoint: Breakpoints.desktop,
            mobileColumns: 2,
            gap: AppSpacing.sp3,
            children: <Widget>[
              for (final Flavor flavor in kFlavors)
                FlavorOptionCard(
                  title: flavor.id,
                  description: flavor.desc,
                  price: flavorStartingPrice(flavor),
                  selected: draft.flavor == flavor.id,
                  onTap: () => _controller.selectFlavor(flavor.id),
                  image: CakeImage(imageUrl: CakeImages.byKey(flavor.key)),
                ),
            ],
          ),
        ),
        FormSection(
          title: '🥚 Cake Type',
          isRequired: true,
          child: ResponsiveGrid(
            desktopColumns: 2,
            tabletColumns: 2,
            mobileColumns: 2,
            gap: AppSpacing.sp3,
            children: <Widget>[
              for (final CakeTypeOption option in kCakeTypes)
                PillOption(
                  icon: option.icon,
                  label: option.value,
                  sub: option.sub,
                  selected: draft.cakeType == option.value,
                  onTap: () => _controller.selectCakeType(option.value),
                ),
            ],
          ),
        ),
        FormSection(
          title: '⚖️ Cake Size',
          isRequired: true,
          child: ResponsiveGrid(
            desktopColumns: 4,
            tabletColumns: 2,
            tabletBreakpoint: Breakpoints.desktop,
            mobileColumns: 2,
            gap: AppSpacing.sp3,
            children: <Widget>[
              for (final MapEntry<String, int> size in kSizePrices.entries)
                PillOption(
                  icon: '🎂',
                  label: size.key,
                  sub: '₹${size.value}',
                  selected: draft.size == size.key,
                  onTap: () => _controller.selectSize(size.key),
                ),
            ],
          ),
        ),
        FormSection(
          title: '🍨 Cream',
          isRequired: true,
          child: ResponsiveGrid(
            desktopColumns: 4,
            tabletColumns: 2,
            tabletBreakpoint: Breakpoints.desktop,
            mobileColumns: 2,
            gap: AppSpacing.sp3,
            children: <Widget>[
              for (final MapEntry<String, String> cream in kCreamIcons.entries)
                PillOption(
                  icon: cream.value,
                  label: cream.key,
                  selected: draft.cream == cream.key,
                  onTap: () => _controller.selectCream(cream.key),
                ),
            ],
          ),
        ),
        FormSection(
          title: '✨ Decorations',
          subtitle: 'Optional — pick as many as you like.',
          child: ResponsiveGrid(
            desktopColumns: 3,
            tabletBreakpoint: Breakpoints.desktop,
            mobileColumns: 1,
            gap: AppSpacing.sp3,
            children: <Widget>[
              for (final MapEntry<String, int> decoration
                  in kDecorationPrices.entries)
                DecorationOption(
                  icon: kDecorationIcons[decoration.key] ?? '✨',
                  label: decoration.key,
                  price: decoration.value,
                  selected: draft.decorations.contains(decoration.key),
                  onTap: () => _controller.toggleDecoration(decoration.key),
                ),
            ],
          ),
        ),
        FormSection(
          title: '💬 Cake Message',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _cakeMessage,
                maxLength: Validators.cakeMessageMaxLength,
                onChanged: _controller.setCakeMessage,
                style: AppText.input,
                cursorColor: AppColors.coral,
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  hintText: 'e.g. Happy Birthday Priya!',
                  hintStyle:
                      AppText.input.copyWith(color: AppColors.textMuted),
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
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_cakeMessage.text.length} / '
                  '${Validators.cakeMessageMaxLength}',
                  style: AppText.meta,
                ),
              ),
            ],
          ),
        ),
        FormSection(
          title: '📝 Special Instructions',
          child: AppTextArea(
            controller: _specialInstructions,
            hint: 'e.g. Please use pink and white decoration.',
            onChanged: _controller.setSpecialInstructions,
          ),
        ),
        FormSection(
          title: '📷 Share Your Cake Inspiration',
          subtitle:
              "Have a cake design in mind? Upload a photo and we'll use it as your reference.",
          child: UploadArea(
            file: draft.referenceImage,
            error: _controller.imageError,
            onChoose: _chooseImage,
            onRemove: _controller.removeReferenceImage,
          ),
        ),
        FormSection(
          title: '📅 Pickup Date & Time',
          isRequired: true,
          child: FormRow(
            first: AppPickerField(
              label: 'Required Date',
              value: Formatters.formatDate(draft.requiredDate),
              placeholder: 'Select date',
              icon: Icons.calendar_today_outlined,
              error: _dateError,
              onTap: _pickDate,
            ),
            second: AppPickerField(
              label: 'Required Time',
              value: Formatters.formatTime(draft.requiredTime),
              placeholder: 'Select time',
              icon: Icons.access_time,
              error: _timeError,
              onTap: _pickTime,
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Right column: live preview + summary ----------
  Widget _previewColumn() {
    final CustomizationDraft draft = _controller.draft;
    Flavor? flavor;
    for (final Flavor item in kFlavors) {
      if (item.id == draft.flavor) flavor = item;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppRadius.lg,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.sm,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AspectRatio(
                  aspectRatio: AppLayout.cakeImageAspect,
                  child: CakeImage(
                    imageUrl: flavor == null
                        ? CakeImages.hero
                        : CakeImages.byKey(flavor.key),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sp4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _controller.previewTitle,
                        style: AppText.poppins(size: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(_controller.previewTags, style: AppText.meta),
                      if (_controller.previewMessage != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.sp3),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.sp3),
                          decoration: BoxDecoration(
                            color: AppColors.cream,
                            borderRadius: AppRadius.sm,
                          ),
                          child: Text(
                            _controller.previewMessage!,
                            style: AppText.inter(
                              size: 13.5,
                              color: AppColors.charcoal,
                              height: 1.45,
                            ).copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sp4),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sp5),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppRadius.lg,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Order Summary', style: AppText.detailCardTitle),
              const SizedBox(height: AppSpacing.sp2),
              _summaryRow('Cake (base + size)', '₹${_controller.basePrice}'),
              _summaryRow('Decorations', '₹${_controller.decorPrice}'),
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.sp2),
                padding: const EdgeInsets.only(top: AppSpacing.sp3),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.border,
                      width: AppBorders.regular,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Estimated Total',
                      style: AppText.poppins(size: 17),
                    ),
                    Text(
                      '₹${_controller.total}',
                      style: AppText.inter(
                        size: 17,
                        weight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
              // The action itself lives in the persistent bar, so there is
              // exactly one Place Order control on this screen.
              FieldErrorText(message: _formError),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sp2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: AppText.inter(size: 14, color: AppColors.text)),
          Text(
            value,
            style: AppText.inter(
              size: 14,
              weight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
