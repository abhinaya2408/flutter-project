/**
 * Machine-readable failure reasons for the OTP flow.
 *
 * The client switches on `reason`, never on the human-readable message, so
 * copy can change without breaking the app. Messages intentionally avoid
 * revealing whether an account exists until the caller has *proved* control of
 * the phone number (the `no-account` reason is only produced after a successful
 * provider check).
 */

export type OtpReason =
  | 'invalid-request'
  | 'invalid-phone'
  | 'invalid-code'
  | 'code-expired'
  | 'rate-limited'
  | 'too-many-attempts'
  | 'no-account'
  | 'no-profile'
  | 'phone-in-use'
  | 'provider-unavailable'
  | 'not-configured'
  | 'unauthenticated';

/** The HttpsError code each reason is reported as. */
export type OtpErrorCode =
  | 'invalid-argument'
  | 'failed-precondition'
  | 'resource-exhausted'
  | 'not-found'
  | 'already-exists'
  | 'unavailable'
  | 'unauthenticated';

const ERROR_CODES: Record<OtpReason, OtpErrorCode> = {
  'invalid-request': 'invalid-argument',
  'invalid-phone': 'invalid-argument',
  'invalid-code': 'invalid-argument',
  'code-expired': 'failed-precondition',
  'rate-limited': 'resource-exhausted',
  'too-many-attempts': 'resource-exhausted',
  'no-account': 'not-found',
  'no-profile': 'failed-precondition',
  'phone-in-use': 'already-exists',
  'provider-unavailable': 'unavailable',
  'not-configured': 'failed-precondition',
  unauthenticated: 'unauthenticated',
};

const DEFAULT_MESSAGES: Record<OtpReason, string> = {
  'invalid-request': 'That request could not be understood. Please try again.',
  'invalid-phone': 'Enter a valid phone number, including the country code.',
  'invalid-code': 'That code is not correct. Check the message on WhatsApp and try again.',
  'code-expired': 'That code has expired. Request a new one.',
  'rate-limited': 'Too many code requests. Please wait before requesting another one.',
  'too-many-attempts': 'Too many incorrect attempts. Request a new code.',
  'no-account': 'No Crumb & Cream account uses this WhatsApp number yet.',
  'no-profile': 'Your account is missing its student or bakery profile.',
  'phone-in-use': 'This WhatsApp number is already linked to a different account.',
  'provider-unavailable':
    'We could not reach WhatsApp right now. Please try again in a moment.',
  'not-configured': 'WhatsApp verification is not configured on the server yet.',
  unauthenticated: 'Sign in before linking a WhatsApp number.',
};

/**
 * A failure that is safe to report to the client. Provider credentials and raw
 * provider responses must never travel in [details].
 */
export class OtpError extends Error {
  readonly reason: OtpReason;
  readonly code: OtpErrorCode;
  readonly details: Record<string, unknown>;

  constructor(reason: OtpReason, details: Record<string, unknown> = {}) {
    super(DEFAULT_MESSAGES[reason]);
    this.name = 'OtpError';
    this.reason = reason;
    this.code = ERROR_CODES[reason];
    this.details = details;
  }
}

/** Never let an unknown throwable leak internals to the caller. */
export function toOtpError(error: unknown): OtpError {
  if (error instanceof OtpError) return error;
  return new OtpError('provider-unavailable');
}
