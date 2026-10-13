/**
 * Cloud Functions entry point — the only file that ties the HTTP layer to the
 * handlers. It exports exactly two callables:
 *
 *   requestWhatsAppOtp  → ask Twilio to send a code over WhatsApp
 *   verifyWhatsAppOtp   → check the code, then link the number or mint a
 *                         Firebase custom token
 *
 * Configuration is validated lazily on first use so a missing environment
 * variable produces a clear `not-configured` failure for that request instead
 * of crashing the whole deployment.
 */

import {initializeApp} from 'firebase-admin/app';
import {HttpsError, onCall, type CallableRequest} from 'firebase-functions/v2/https';

import {AdminAuthPort, AdminProfilePort, AdminRateLimiter, SystemClock} from './admin_adapters';
import {loadConfig, runtimeOptions, type OtpConfig} from './config';
import {OtpError, toOtpError} from './errors';
import {
  requestWhatsAppOtp as requestOtpHandler,
  verifyWhatsAppOtp as verifyOtpHandler,
} from './handlers';
import type {CallerContext, HandlerDeps} from './ports';
import {createProvider} from './providers';

initializeApp();

const options = runtimeOptions();

let cachedDeps: HandlerDeps | null = null;

function buildDeps(config: OtpConfig): HandlerDeps {
  const deps: HandlerDeps = {
    provider: createProvider(config),
    limiter: new AdminRateLimiter(),
    auth: new AdminAuthPort(),
    profiles: new AdminProfilePort(),
    clock: new SystemClock(),
    defaultCountryCode: config.defaultCountryCode,
    codeTtlSeconds: config.codeTtlSeconds,
    send: config.send,
    verify: config.verify,
  };
  if (config.locale !== undefined) deps.locale = config.locale;
  return deps;
}

/**
 * Built on first use. A configuration problem is reported to the caller as
 * `not-configured` rather than leaking a stack trace, and is logged server-side
 * without any credential value.
 */
function getDeps(): HandlerDeps {
  if (cachedDeps !== null) return cachedDeps;
  try {
    cachedDeps = buildDeps(loadConfig());
  } catch (error) {
    console.error(
      'whatsapp-otp: backend configuration is incomplete —',
      error instanceof Error ? error.message : 'unknown error',
    );
    throw new OtpError('not-configured', {});
  }
  return cachedDeps;
}

/** The caller's verified uid plus a best-effort IP, from the runtime only. */
function callerContext(request: CallableRequest<unknown>): CallerContext {
  const ctx: CallerContext = {};
  const uid = request.auth?.uid;
  if (typeof uid === 'string' && uid !== '') ctx.uid = uid;
  const ip = request.rawRequest?.ip;
  if (typeof ip === 'string' && ip !== '') ctx.ip = ip;
  return ctx;
}

/** Translate an [OtpError] into the callable's error contract. */
function toHttpsError(error: unknown): HttpsError {
  const otpError = toOtpError(error);
  if (!(error instanceof OtpError)) {
    console.error('whatsapp-otp: unexpected failure', error instanceof Error ? error.name : typeof error);
  }
  return new HttpsError(otpError.code, otpError.message, {
    reason: otpError.reason,
    ...otpError.details,
  });
}

export const requestWhatsAppOtp = onCall(
  {
    region: options.region,
    enforceAppCheck: options.enforceAppCheck,
    timeoutSeconds: 30,
    maxInstances: 10,
  },
  async (request: CallableRequest<unknown>) => {
    try {
      const data = (request.data ?? {}) as Record<string, unknown>;
      return await requestOtpHandler(
        getDeps(),
        {phoneNumber: data['phoneNumber'], locale: data['locale']},
        callerContext(request),
      );
    } catch (error) {
      throw toHttpsError(error);
    }
  },
);

export const verifyWhatsAppOtp = onCall(
  {
    region: options.region,
    enforceAppCheck: options.enforceAppCheck,
    timeoutSeconds: 30,
    maxInstances: 10,
  },
  async (request: CallableRequest<unknown>) => {
    try {
      const data = (request.data ?? {}) as Record<string, unknown>;
      return await verifyOtpHandler(
        getDeps(),
        {
          phoneNumber: data['phoneNumber'],
          code: data['code'],
          intent: data['intent'],
        },
        callerContext(request),
      );
    } catch (error) {
      throw toHttpsError(error);
    }
  },
);
