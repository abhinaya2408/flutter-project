/// Phone-number helpers for the WhatsApp verification flow.
///
/// This mirrors `functions/src/phone.ts` exactly, so the client can validate
/// and preview a number before sending it and the backend can still be the
/// authority: whatever reaches the Function is re-normalised there. Keep the
/// two implementations in step — the Dart copy exists for instant feedback, not
/// for security.
///
/// Nothing here is a secret and nothing here talks to a provider.
class PhoneNumber {
  PhoneNumber._();

  static final RegExp _e164 = RegExp(r'^\+[1-9]\d{6,14}$');

  /// Normalise user input to E.164, or return `null` when it cannot be valid.
  ///
  /// Accepted forms, in order of precedence:
  /// * `+919876543210` — already international
  /// * `00919876543210` — international with a `00` prefix
  /// * `09876543210` — national with a `0` trunk prefix
  /// * `9876543210` — national, [dialCode] prepended
  static String? toE164(String raw, {String dialCode = '+91'}) {
    final String cleaned = raw.trim().replaceAll(RegExp(r'[\s().\-\u2010-\u2015]'), '');
    if (cleaned.isEmpty) return null;
    if (!RegExp(r'^\+?\d+$').hasMatch(cleaned)) return null;

    final String candidate;
    if (cleaned.startsWith('+')) {
      candidate = cleaned;
    } else if (cleaned.startsWith('00')) {
      candidate = '+${cleaned.substring(2)}';
    } else if (cleaned.startsWith('0')) {
      candidate = '$dialCode${cleaned.replaceFirst(RegExp(r'^0+'), '')}';
    } else if (cleaned.length <= 10) {
      candidate = '$dialCode$cleaned';
    } else {
      // Longer than a national number but with no `+`: treat as international.
      candidate = '+$cleaned';
    }

    return _e164.hasMatch(candidate) ? candidate : null;
  }

  /// `+919876543210` -> `+91 ••••••3210`. Safe to show on screen.
  static String mask(String e164) {
    final String digits = e164.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return '•' * digits.length;
    final String tail = digits.substring(digits.length - 4);
    final int countryDigits = digits.length > 10 ? digits.length - 10 : 0;
    final String country =
        countryDigits > 0 ? '+${digits.substring(0, countryDigits)} ' : '';
    final int hidden = digits.length - countryDigits - 4;
    return '$country${'•' * hidden}$tail';
  }
}
