/**
 * The two OTP use cases, as port-injected functions with no framework or
 * `firebase-admin` imports — so every branch below is unit tested directly.
 *
 * Flow
 * ----
 * `requestWhatsAppOtp`  normalise → rate limit (per phone, per IP) → ask the
 *                       provider to send over WhatsApp.
 * `verifyWhatsAppOtp`   normalise → rate limit → validate the code shape →
 *                       ask the provider whether the code is correct →
 *                       only then resolve the account and either mint a
 *                       Firebase custom token (`sign_in`) or attach the number
 *                       to the already-authenticated account (`link`).
 *
 * Security properties enforced here, not on the client:
 *   * the code is never generated, stored, returned or logged by this backend;
 *   * account existence is never revealed before the provider approves a code
 *     (no account enumeration);
 *   * `link` requires a Firebase-verified caller uid — never a client-supplied
 *     one — and refuses a number that already belongs to a different account;
 *   * a verified number can never create or upgrade a `bakery_members`
 *     document, so students cannot gain bakery privileges.
 */

import {OtpError} from './errors';
import {isValidCodeFormat, maskPhone, normalizeToE164} from './phone';
import type {AccountRole, CallerContext, HandlerDeps} from './ports';

export type OtpIntent = 'sign_in' | 'link';

export interface RequestOtpData {
  phoneNumber?: unknown;
  locale?: unknown;
}

export interface RequestOtpResult {
  status: 'sent';
  channel: 'whatsapp';
  phoneMasked: string;
  expiresInSeconds: number;
  resendAfterSeconds: number;
}

export interface VerifyOtpData {
  phoneNumber?: unknown;
  code?: unknown;
  intent?: unknown;
}

export interface VerifyOtpResult {
  status: 'signed_in' | 'linked';
  uid: string;
  role: AccountRole;
  phoneMasked: string;
  /** Only set for `sign_in`; a short-lived Firebase custom token. */
  customToken?: string;
}

const LOCALE_PATTERN = /^[a-z]{2}(-[A-Z]{2})?$/;
const MAX_LOCALE_LENGTH = 12;

function readLocale(value: unknown, fallback?: string): string | undefined {
  if (typeof value !== 'string') return fallback;
  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > MAX_LOCALE_LENGTH) return fallback;
  return LOCALE_PATTERN.test(trimmed) ? trimmed : fallback;
}

function readIntent(value: unknown): OtpIntent {
  if (value === undefined || value === null || value === '') return 'sign_in';
  if (value === 'sign_in' || value === 'link') return value;
  throw new OtpError('invalid-request', {field: 'intent'});
}

function requirePhone(data: {phoneNumber?: unknown}, deps: HandlerDeps): string {
  const phone = normalizeToE164(data.phoneNumber, deps.defaultCountryCode);
  if (phone === null) throw new OtpError('invalid-phone', {});
  return phone;
}

/**
 * Guarantee the handler's error contract around anything a provider throws.
 * An [OtpError] keeps its own reason (Twilio's "invalid number" and "bad
 * credentials" both arrive this way); any other throwable becomes a retryable
 * outage rather than escaping as an unhandled failure or reading as success.
 */
async function providerCall<T>(operation: () => Promise<T>): Promise<T> {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof OtpError) throw error;
    throw new OtpError('provider-unavailable', {});
  }
}

export async function requestWhatsAppOtp(
  deps: HandlerDeps,
  data: RequestOtpData,
  ctx: CallerContext,
): Promise<RequestOtpResult> {
  const phoneE164 = requirePhone(data, deps);
  const locale = readLocale(data.locale, deps.locale);
  const now = deps.clock.nowMs();

  // Per-phone limit first: it is the limit that matters most for abuse and it
  // is the one that produces the cooldown the OTP screen counts down.
  const phoneDecision = await deps.limiter.consume({
    scope: 'send-phone',
    identifier: phoneE164,
    limit: deps.send.perPhoneLimit,
    windowMs: deps.send.perPhoneWindowMs,
    cooldownMs: deps.send.perPhoneCooldownMs,
    now,
  });
  if (!phoneDecision.allowed) {
    throw new OtpError('rate-limited', {retryAfterSeconds: phoneDecision.retryAfterSeconds});
  }

  // Then the per-IP limit, so one client cannot walk the whole number space.
  if (ctx.ip) {
    const ipDecision = await deps.limiter.consume({
      scope: 'send-ip',
      identifier: ctx.ip,
      limit: deps.send.perIpLimit,
      windowMs: deps.send.perIpWindowMs,
      now,
    });
    if (!ipDecision.allowed) {
      throw new OtpError('rate-limited', {retryAfterSeconds: ipDecision.retryAfterSeconds});
    }
  }

  await providerCall(() => deps.provider.send(locale ? {phoneE164, locale} : {phoneE164}));

  return {
    status: 'sent',
    channel: 'whatsapp',
    // The full number is never echoed back to the client.
    phoneMasked: maskPhone(phoneE164),
    expiresInSeconds: deps.codeTtlSeconds,
    resendAfterSeconds: Math.ceil(deps.send.perPhoneCooldownMs / 1000),
  };
}

export async function verifyWhatsAppOtp(
  deps: HandlerDeps,
  data: VerifyOtpData,
  ctx: CallerContext,
): Promise<VerifyOtpResult> {
  const intent = readIntent(data.intent);
  const phoneE164 = requirePhone(data, deps);

  if (intent === 'link' && (ctx.uid === undefined || ctx.uid === '')) {
    // Linking always happens for the caller's own account, never for a uid
    // that arrived in the request payload.
    throw new OtpError('unauthenticated', {});
  }

  const now = deps.clock.nowMs();

  const decision = await deps.limiter.consume({
    scope: 'verify-phone',
    identifier: phoneE164,
    limit: deps.verify.perPhoneLimit,
    windowMs: deps.verify.perPhoneWindowMs,
    now,
  });
  if (!decision.allowed) {
    // Report as "too many attempts" so a brute-force caller learns nothing new.
    throw new OtpError('too-many-attempts', {retryAfterSeconds: decision.retryAfterSeconds});
  }

  // Shape-check before spending a provider attempt on obvious junk.
  if (!isValidCodeFormat(data.code)) {
    throw new OtpError('invalid-code', {});
  }
  // Local binding: a type predicate on a property does not survive into the
  // closure below.
  const code = data.code;

  const status = await providerCall(() => deps.provider.check({phoneE164, code}));
  switch (status) {
    case 'approved':
      break;
    case 'pending':
      throw new OtpError('invalid-code', {});
    case 'canceled':
      throw new OtpError('code-expired', {});
    case 'max_attempts_reached':
      throw new OtpError('too-many-attempts', {});
    default:
      throw new OtpError('provider-unavailable', {});
  }

  const phoneMasked = maskPhone(phoneE164);
  // Looked up only now, after the caller proved control of the number.
  const existing = await deps.auth.findUserByPhone(phoneE164);

  if (intent === 'link') {
    const uid = ctx.uid as string;

    if (existing !== null && existing.uid !== uid) {
      throw new OtpError('phone-in-use', {});
    }

    const role = await deps.profiles.roleOf(uid);
    if (role === null) throw new OtpError('no-profile', {});

    if (existing === null) {
      await deps.auth.attachPhone({uid, phoneE164});
    }

    await deps.profiles.markPhoneVerified({uid, role, phoneE164, phoneMasked, method: 'link'});
    await deps.profiles.recordVerification({
      uid,
      role,
      phoneMasked,
      provider: deps.provider.name,
      channel: deps.provider.channel,
      method: 'link',
      atMs: now,
    });

    return {status: 'linked', uid, role, phoneMasked};
  }

  if (existing === null) {
    throw new OtpError('no-account', {});
  }

  const role = await deps.profiles.roleOf(existing.uid);
  if (role === null) {
    // The phone is verified but the account has no profile document: refuse to
    // hand out a token for an account that cannot use the app.
    throw new OtpError('no-profile', {});
  }

  const customToken = await deps.auth.createCustomToken(existing.uid);
  await deps.profiles.recordVerification({
    uid: existing.uid,
    role,
    phoneMasked,
    provider: deps.provider.name,
    channel: deps.provider.channel,
    method: 'sign_in',
    atMs: now,
  });

  return {
    status: 'signed_in',
    uid: existing.uid,
    role,
    phoneMasked,
    customToken,
  };
}
