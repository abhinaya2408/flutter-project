import {describe, expect, it} from 'vitest';

import {evaluateWindow, rateLimitKey} from '../src/rate_limiter';

const T0 = 1_700_000_000_000;

describe('evaluateWindow', () => {
  it('allows events up to the limit and blocks the next one', () => {
    let events: number[] = [];

    for (let i = 0; i < 3; i += 1) {
      const result = evaluateWindow(events, {limit: 3, windowMs: 900_000, now: T0 + i * 1000});
      expect(result.decision.allowed).toBe(true);
      events = result.events;
    }

    const blocked = evaluateWindow(events, {limit: 3, windowMs: 900_000, now: T0 + 4000});
    expect(blocked.decision.allowed).toBe(false);
    expect(blocked.decision.retryAfterSeconds).toBeGreaterThan(0);
    expect(blocked.decision.remaining).toBe(0);
    // A blocked event is never recorded.
    expect(blocked.events).toEqual(events);
  });

  it('frees capacity once the oldest event leaves the window', () => {
    const events = [T0, T0 + 1000, T0 + 2000];
    const blocked = evaluateWindow(events, {limit: 3, windowMs: 60_000, now: T0 + 3000});
    expect(blocked.decision.allowed).toBe(false);

    const allowed = evaluateWindow(events, {limit: 3, windowMs: 60_000, now: T0 + 60_001});
    expect(allowed.decision.allowed).toBe(true);
    expect(allowed.events).toEqual([T0 + 1000, T0 + 2000, T0 + 60_001]);
  });

  it('enforces the cooldown even when the limit is not reached', () => {
    const events = [T0];
    const blocked = evaluateWindow(events, {
      limit: 3,
      windowMs: 900_000,
      cooldownMs: 60_000,
      now: T0 + 30_000,
    });
    expect(blocked.decision.allowed).toBe(false);
    expect(blocked.decision.retryAfterSeconds).toBe(30);

    const allowed = evaluateWindow(events, {
      limit: 3,
      windowMs: 900_000,
      cooldownMs: 60_000,
      now: T0 + 60_000,
    });
    expect(allowed.decision.allowed).toBe(true);
  });

  it('ignores stale and future timestamps', () => {
    const events = [T0 - 3_600_000, T0 + 600_000, NaN];
    const result = evaluateWindow(events, {limit: 2, windowMs: 900_000, now: T0});
    expect(result.decision.allowed).toBe(true);
    expect(result.events).toEqual([T0]);
  });

  it('reports remaining capacity', () => {
    const first = evaluateWindow([], {limit: 3, windowMs: 900_000, now: T0});
    expect(first.decision.remaining).toBe(2);
  });

  it('never returns a retry window shorter than one second', () => {
    const events = [T0];
    const blocked = evaluateWindow(events, {limit: 1, windowMs: 900_000, now: T0});
    expect(blocked.decision.retryAfterSeconds).toBeGreaterThanOrEqual(1);
  });
});

describe('rateLimitKey', () => {
  it('is stable and hex encoded', () => {
    const key = rateLimitKey('send-phone', '+919876543210');
    expect(key).toBe(rateLimitKey('send-phone', '+919876543210'));
    expect(key).toMatch(/^[0-9a-f]{64}$/);
  });

  it('separates scopes and identifiers', () => {
    expect(rateLimitKey('send-phone', '+919876543210')).not.toBe(
      rateLimitKey('verify-phone', '+919876543210'),
    );
    expect(rateLimitKey('send-phone', '+919876543210')).not.toBe(
      rateLimitKey('send-phone', '+919876543211'),
    );
  });

  it('never contains the raw identifier', () => {
    expect(rateLimitKey('send-phone', '+919876543210')).not.toContain('9876543210');
  });
});
