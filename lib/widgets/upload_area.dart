import 'package:flutter/material.dart';

import '../models/customization_draft.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import 'app_button.dart';
import 'app_text_field.dart';

/// `.upload-area` + `.upload-preview` — the reference photo picker.
///
/// Same flow as `wireImageUpload()`: choosing a file validates it, the dashed
/// area is replaced by the preview row (thumbnail, file name, size and a
/// `Remove` button) and the error line sits underneath.
class UploadArea extends StatefulWidget {
  const UploadArea({
    required this.file,
    required this.error,
    required this.onChoose,
    required this.onRemove,
    super.key,
  });

  final ReferenceImageFile? file;
  final String? error;
  final VoidCallback onChoose;
  final VoidCallback onRemove;

  @override
  State<UploadArea> createState() => _UploadAreaState();
}

class _UploadAreaState extends State<UploadArea> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.file == null)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: widget.onChoose,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sp6),
                decoration: BoxDecoration(
                  color: _hovered ? AppColors.coralLight : AppColors.cream,
                  borderRadius: AppRadius.md,
                  border: Border.all(
                    color: _hovered ? AppColors.coral : AppColors.border,
                    width: AppBorders.dashed,
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    const Text('📷', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: AppSpacing.sp2),
                    Text(
                      'Upload a cake reference',
                      textAlign: TextAlign.center,
                      style: AppText.inter(
                        size: 16,
                        weight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'JPG, JPEG or PNG · Max 2 MB',
                      textAlign: TextAlign.center,
                      style: AppText.inter(
                        size: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sp3),
                    AppButton(
                      label: 'Choose Image',
                      variant: AppButtonVariant.secondary,
                      small: true,
                      onPressed: widget.onChoose,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sp3),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: AppRadius.md,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: AppRadius.sm,
                  child: Image.memory(
                    widget.file!.bytes,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) =>
                        Container(
                      width: 72,
                      height: 72,
                      color: AppColors.coralLight,
                      alignment: Alignment.center,
                      child: const Text('🖼️'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sp3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.file!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.inter(
                          size: 13.5,
                          weight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                      ),
                      Text(
                        Formatters.fileSize(widget.file!.size),
                        style: AppText.inter(
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sp2),
                AppButton(
                  label: 'Remove',
                  variant: AppButtonVariant.outline,
                  small: true,
                  onPressed: widget.onRemove,
                ),
              ],
            ),
          ),
        FieldErrorText(message: widget.error),
      ],
    );
  }
}
