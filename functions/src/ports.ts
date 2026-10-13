/**
 * Ports (interfaces) the OTP handlers depend on.
 *
 * Handlers talk only to these interfaces, never to `firebase-admin` directly,
 * which is what makes the whole flow unit-testable without the emulator and
 * without any Firebase credentials.
 */

import type {RateLimiter} from './rate_limiter';

/** `student` and `bakery_member` mirror the two Firestore collections. */
export type AccountRole = 'student' | 'bakery_member';

/** A Firebase Authentication user, reduced to what the flow needs. */
export interface OtpUser {
  uid: string;
  phoneNumber?: string;
}

/** Result of asking the provider whether a code is correct. */
export type ProviderCheckStatus =
  | 'approved'
  | 'pending'
  | 'canceled'
  | 'max_attempts_reached';

export interface VerificationProvider {
  /** `twilio` in production, `mock` in the emulator only. */
  readonly name: string;
  /** Always `whatsapp` — this app never falls back to SMS. */
  readonly channel: string;
  send(input: {phoneE164: string; locale?: string}): Promise<void>;
  check(input: {phoneE164: string; code: string}): Promise<ProviderCheckStatus>;
}

export interface AuthPort {
  /**
   * Resolve the Firebase user that owns a verified phone number.
   * Returns `null` when no account has that number — never creates one.
   */
  findUserByPhone(phoneE164: string): Promise<OtpUser | null>;
  /** Mint a Firebase custom token for an existing uid. */
  createCustomToken(uid: string): Promise<string>;
  /** Attach a verified number to an existing uid. */
  attachPhone(input: {uid: string; phoneE164: string}): Promise<void>;
}

export interface ProfilePort {
  /** Which profile document exists for this uid, if any. */
  roleOf(uid: string): Promise<AccountRole | null>;
  /**
   * Mark the number verified on the profile document that already exists.
   * Must not create a profile document and must never write a role field.
   */
  markPhoneVerified(input: {
    uid: string;
    role: AccountRole;
    phoneE164: string;
    phoneMasked: string;
    method: 'sign_in' | 'link';
  }): Promise<void>;
  /** Append-only audit record of a completed verification. */
  recordVerification(input: {
    uid: string;
    role: AccountRole;
    phoneMasked: string;
    provider: string;
    channel: string;
    method: 'sign_in' | 'link';
    atMs: number;
  }): Promise<void>;
}

export interface Clock {
  nowMs(): number;
}

export interface HandlerDeps {
  provider: VerificationProvider;
  limiter: RateLimiter;
  auth: AuthPort;
  profiles: ProfilePort;
  clock: Clock;
  defaultCountryCode: string;
  locale?: string;
  codeTtlSeconds: number;
  send: {
    perPhoneLimit: number;
    perPhoneWindowMs: number;
    perPhoneCooldownMs: number;
    perIpLimit: number;
    perIpWindowMs: number;
  };
  verify: {perPhoneLimit: number; perPhoneWindowMs: number};
}

/** Identity of the caller, derived from the callable request context only. */
export interface CallerContext {
  /** Verified from the Firebase ID token by the Functions runtime. */
  uid?: string;
  /** Best-effort client IP, used only for the per-IP send limit. */
  ip?: string;
}
