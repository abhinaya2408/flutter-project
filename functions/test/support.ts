/**
 * In-memory test doubles.
 *
 * These live under `test/`, not `src/`, so no fake verification path can ever
 * be imported by a deployed Function.
 */

import {OtpError} from '../src/errors';
import type {
  AccountRole,
  AuthPort,
  Clock,
  HandlerDeps,
  OtpUser,
  ProfilePort,
  ProviderCheckStatus,
  VerificationProvider,
} from '../src/ports';
import {
  evaluateWindow,
  type RateLimiter,
  type RateLimitDecision,
  type RateLimitRequest,
} from '../src/rate_limiter';

export class FixedClock implements Clock {
  private current: number;

  constructor(start = 1_700_000_000_000) {
    this.current = start;
  }

  nowMs(): number {
    return this.current;
  }

  advance(ms: number): void {
    this.current += ms;
  }
}

export class InMemoryRateLimiter implements RateLimiter {
  private readonly buckets = new Map<string, number[]>();

  async consume(request: RateLimitRequest): Promise<RateLimitDecision> {
    const key = `${request.scope}:${request.identifier}`;
    const {decision, events} = evaluateWindow(this.buckets.get(key) ?? [], request);
    if (decision.allowed) this.buckets.set(key, events);
    return decision;
  }
}

export class FakeProvider implements VerificationProvider {
  readonly name = 'fake-twilio';
  readonly channel = 'whatsapp';

  readonly sends: {phoneE164: string; locale?: string}[] = [];
  readonly checks: {phoneE164: string; code: string}[] = [];

  /** What `check` will report next. */
  status: ProviderCheckStatus = 'approved';
  /** When set, `send` fails with this error. */
  sendError: Error | null = null;

  async send(input: {phoneE164: string; locale?: string}): Promise<void> {
    if (this.sendError) throw this.sendError;
    this.sends.push(input);
  }

  async check(input: {phoneE164: string; code: string}): Promise<ProviderCheckStatus> {
    this.checks.push(input);
    return this.status;
  }
}

export class FakeAuthPort implements AuthPort {
  readonly users = new Map<string, OtpUser>();
  readonly phoneToUid = new Map<string, string>();
  readonly attached: {uid: string; phoneE164: string}[] = [];
  readonly tokens: {uid: string; token: string}[] = [];

  addUser(uid: string, phoneNumber?: string): void {
    this.users.set(uid, phoneNumber ? {uid, phoneNumber} : {uid});
    if (phoneNumber) this.phoneToUid.set(phoneNumber, uid);
  }

  async findUserByPhone(phoneE164: string): Promise<OtpUser | null> {
    const uid = this.phoneToUid.get(phoneE164);
    if (uid === undefined) return null;
    return this.users.get(uid) ?? null;
  }

  async createCustomToken(uid: string): Promise<string> {
    const token = `custom-token-for-${uid}`;
    this.tokens.push({uid, token});
    return token;
  }

  async attachPhone(input: {uid: string; phoneE164: string}): Promise<void> {
    const owner = this.phoneToUid.get(input.phoneE164);
    if (owner !== undefined && owner !== input.uid) {
      throw new OtpError('phone-in-use', {});
    }
    this.phoneToUid.set(input.phoneE164, input.uid);
    this.attached.push(input);
    const existing = this.users.get(input.uid);
    if (existing) this.users.set(input.uid, {...existing, phoneNumber: input.phoneE164});
  }
}

export class FakeProfilePort implements ProfilePort {
  readonly roles = new Map<string, AccountRole>();
  readonly marks: {
    uid: string;
    role: AccountRole;
    phoneE164: string;
    phoneMasked: string;
    method: 'sign_in' | 'link';
  }[] = [];
  readonly verifications: {
    uid: string;
    role: AccountRole;
    phoneMasked: string;
    provider: string;
    channel: string;
    method: 'sign_in' | 'link';
    atMs: number;
  }[] = [];

  async roleOf(uid: string): Promise<AccountRole | null> {
    return this.roles.get(uid) ?? null;
  }

  async markPhoneVerified(input: {
    uid: string;
    role: AccountRole;
    phoneE164: string;
    phoneMasked: string;
    method: 'sign_in' | 'link';
  }): Promise<void> {
    const actual = this.roles.get(input.uid);
    if (actual === undefined) throw new OtpError('no-profile', {});
    if (actual !== input.role) throw new Error('role mismatch: verification must not change a role');
    this.marks.push(input);
  }

  async recordVerification(input: {
    uid: string;
    role: AccountRole;
    phoneMasked: string;
    provider: string;
    channel: string;
    method: 'sign_in' | 'link';
    atMs: number;
  }): Promise<void> {
    this.verifications.push(input);
  }
}

export interface TestHarness {
  deps: HandlerDeps;
  provider: FakeProvider;
  auth: FakeAuthPort;
  profiles: FakeProfilePort;
  limiter: InMemoryRateLimiter;
  clock: FixedClock;
}

export function makeHarness(overrides: Partial<HandlerDeps> = {}): TestHarness {
  const provider = new FakeProvider();
  const auth = new FakeAuthPort();
  const profiles = new FakeProfilePort();
  const limiter = new InMemoryRateLimiter();
  const clock = new FixedClock();

  const deps: HandlerDeps = {
    provider,
    auth,
    profiles,
    limiter,
    clock,
    defaultCountryCode: '+91',
    codeTtlSeconds: 600,
    send: {
      perPhoneLimit: 3,
      perPhoneWindowMs: 900_000,
      perPhoneCooldownMs: 60_000,
      perIpLimit: 10,
      perIpWindowMs: 3_600_000,
    },
    verify: {perPhoneLimit: 5, perPhoneWindowMs: 600_000},
    ...overrides,
  };

  return {deps, provider, auth, profiles, limiter, clock};
}
