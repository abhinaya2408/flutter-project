/**
 * Rate limiting for the OTP endpoints.
 *
 * The window logic is a pure function so it can be unit tested without a
 * database; the Firestore implementation is a thin transactional wrapper
 * around it (see `admin_rate_limiter.ts`).
 *
 * Keys are SHA-256 hashes of the identifier, so the limiter never stores a raw
 * phone number or IP address.
 */

import {createHash} from 'node:crypto';

export interface RateLimitRequest {
  /** Logical bucket, e.g. `send-phone` or `verify-phone`. */
  scope: string;
  /** The phone number (already E.164) or IP address being limited. */
  identifier: string;
  /** Max events allowed inside the window. */
  limit: number;
  windowMs: number;
  /** Minimum gap between two events (0 disables the cooldown). */
  cooldownMs?: number;
  /** Current time in epoch milliseconds. Injected so tests are deterministic. */
  now: number;
}

export interface RateLimitDecision {
  allowed: boolean;
  /** How long the caller must wait before retrying, in seconds. */
  retryAfterSeconds: number;
  remaining: number;
}

export interface RateLimiter {
  consume(request: RateLimitRequest): Promise<RateLimitDecision>;
}

/** `sha256(scope:identifier)` — the only form of the identifier ever stored. */
export function rateLimitKey(scope: string, identifier: string): string {
  return createHash('sha256').update(`${scope}:${identifier}`).digest('hex');
}

/**
 * Decide whether an event may happen, given the timestamps of previous events
 * in the same bucket. Returns the pruned event list to persist.
 */
export function evaluateWindow(
  previousEvents: readonly number[],
  request: Pick<RateLimitRequest, 'limit' | 'windowMs' | 'now' | 'cooldownMs'>,
): {decision: RateLimitDecision; events: number[]} {
  const {limit, windowMs, now} = request;
  const cooldownMs = request.cooldownMs ?? 0;

  const events = previousEvents
    .filter((at) => Number.isFinite(at) && at <= now && now - at < windowMs)
    .sort((a, b) => a - b);

  const last = events.length > 0 ? events[events.length - 1]! : undefined;

  if (cooldownMs > 0 && last !== undefined) {
    const waitMs = cooldownMs - (now - last);
    if (waitMs > 0) {
      return {
        decision: {
          allowed: false,
          retryAfterSeconds: Math.ceil(waitMs / 1000),
          remaining: Math.max(0, limit - events.length),
        },
        events,
      };
    }
  }

  if (events.length >= limit) {
    const oldest = events[events.length - limit]!;
    const waitMs = windowMs - (now - oldest);
    return {
      decision: {
        allowed: false,
        retryAfterSeconds: Math.max(1, Math.ceil(waitMs / 1000)),
        remaining: 0,
      },
      events,
    };
  }

  events.push(now);
  return {
    decision: {allowed: true, retryAfterSeconds: 0, remaining: Math.max(0, limit - events.length)},
    events,
  };
}
