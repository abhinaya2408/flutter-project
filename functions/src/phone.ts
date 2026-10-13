/**
 * Server-side phone number handling.
 *
 * The Flutter app has always stored a bare 10-digit national number
 * (`Validators.phone`). Providers such as Twilio require E.164, so every
 * number that reaches the backend is normalised here. This module is the
 * authority: whatever the client sends is re-normalised and re-validated, so a
 * malformed or hostile value cannot reach the provider.
 */

const E164 = /^\+[1-9]\d{6,14}$/;

/**
 * Normalise user input to E.164.
 *
 * Accepts, in order of precedence:
 *   `+919876543210`      already international
 *   `00919876543210`     international with a `00` trunk prefix
 *   `09876543210`        national with a `0` trunk prefix (India-style)
 *   `9876543210`         national, `defaultCountryCode` is prepended
 *
 * Returns `null` when the value cannot be a valid number, so the caller can
 * answer with `invalid-phone` instead of guessing.
 */
export function normalizeToE164(raw: unknown, defaultCountryCode: string): string | null {
  if (typeof raw !== 'string') return null;

  // Keep digits and a single leading `+`; drop spaces, dashes, dots, brackets.
  const cleaned = raw.trim().replace(/[\s().\-\u2010-\u2015]/g, '');
  if (cleaned === '') return null;
  if (!/^\+?\d+$/.test(cleaned)) return null;

  let candidate: string;

  if (cleaned.startsWith('+')) {
    candidate = cleaned;
  } else if (cleaned.startsWith('00')) {
    candidate = `+${cleaned.slice(2)}`;
  } else if (cleaned.startsWith('0')) {
    candidate = `${defaultCountryCode}${cleaned.replace(/^0+/, '')}`;
  } else if (cleaned.length <= 10) {
    candidate = `${defaultCountryCode}${cleaned}`;
  } else {
    // Longer than a national number but without a `+`: treat as international.
    candidate = `+${cleaned}`;
  }

  return E164.test(candidate) ? candidate : null;
}

/** `+919876543210` -> `+91••••••3210` (safe to show on the OTP screen). */
export function maskPhone(e164: string): string {
  const digits = e164.replace(/\D/g, '');
  if (digits.length <= 4) return '•'.repeat(digits.length);
  const tail = digits.slice(-4);
  // Country code is everything beyond a 10-digit national number.
  const countryDigits = digits.length > 10 ? digits.length - 10 : 0;
  const country = countryDigits > 0 ? `+${digits.slice(0, countryDigits)} ` : '';
  const hidden = digits.length - countryDigits - 4;
  return `${country}${'•'.repeat(hidden)}${tail}`;
}

/** A verification code is exactly 6 digits — anything else never reaches Twilio. */
export function isValidCodeFormat(raw: unknown): raw is string {
  return typeof raw === 'string' && /^\d{6}$/.test(raw);
}
