/**
 * `firebase-admin` backed implementations of the handler ports.
 *
 * Everything here runs with the Admin SDK, which bypasses Firestore security
 * rules. That is exactly why these writes are deliberately narrow:
 *
 *   * `ProfilePort.markPhoneVerified` only ever updates fields on a profile
 *     document that already exists and never writes a `role` field, so a
 *     student cannot be promoted to a bakery member by verifying a number;
 *   * `ProfilePort.roleOf` is the only place the account role is read, and it
 *     reads it from Firestore (`students/{uid}` then `bakery_members/{uid}`),
 *     never from client input.
 */

import {getAuth} from 'firebase-admin/auth';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';

import {OtpError} from './errors';
import type {AccountRole, AuthPort, Clock, OtpUser, ProfilePort} from './ports';
import {evaluateWindow, rateLimitKey, type RateLimiter, type RateLimitRequest, type RateLimitDecision} from './rate_limiter';

const STUDENTS = 'students';
const BAKERY_MEMBERS = 'bakery_members';
/** Server-only collection: clients are denied all access by the rules. */
const RATE_LIMITS = 'otp_rate_limits';
const VERIFICATIONS = 'otp_verifications';

export class AdminAuthPort implements AuthPort {
  async findUserByPhone(phoneE164: string): Promise<OtpUser | null> {
    try {
      const user = await getAuth().getUserByPhoneNumber(phoneE164);
      return {uid: user.uid, ...(user.phoneNumber ? {phoneNumber: user.phoneNumber} : {})};
    } catch (error) {
      const code = (error as {code?: string}).code;
      if (code === 'auth/user-not-found') return null;
      // Anything else is a real failure: never treat it as "no account".
      throw error;
    }
  }

  async createCustomToken(uid: string): Promise<string> {
    return getAuth().createCustomToken(uid);
  }

  async attachPhone(input: {uid: string; phoneE164: string}): Promise<void> {
    try {
      await getAuth().updateUser(input.uid, {phoneNumber: input.phoneE164});
    } catch (error) {
      const code = (error as {code?: string}).code;
      if (code === 'auth/phone-number-already-exists') {
        throw new OtpError('phone-in-use', {});
      }
      throw error;
    }
  }
}

export class AdminProfilePort implements ProfilePort {
  async roleOf(uid: string): Promise<AccountRole | null> {
    const firestore = getFirestore();
    const student = await firestore.collection(STUDENTS).doc(uid).get();
    if (student.exists) return 'student';
    const member = await firestore.collection(BAKERY_MEMBERS).doc(uid).get();
    if (member.exists) return 'bakery_member';
    return null;
  }

  async markPhoneVerified(input: {
    uid: string;
    role: AccountRole;
    phoneE164: string;
    phoneMasked: string;
    method: 'sign_in' | 'link';
  }): Promise<void> {
    const collection = input.role === 'student' ? STUDENTS : BAKERY_MEMBERS;
    const doc = getFirestore().collection(collection).doc(input.uid);
    const exists = (await doc.get()).exists;
    if (!exists) {
      // Refuse to create a profile document: verification must never mint a
      // role. The role was already read from an existing document above.
      throw new OtpError('no-profile', {});
    }

    // `phone` (the existing 10-digit national field used by orders) is left
    // untouched; the E.164 value and the verified flag are added alongside it.
    // No `role` field is written.
    await doc.update({
      phoneE164: input.phoneE164,
      phoneMasked: input.phoneMasked,
      phoneVerified: true,
      phoneVerifiedAt: FieldValue.serverTimestamp(),
      phoneVerifiedMethod: input.method,
      updatedAt: FieldValue.serverTimestamp(),
    });
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
    // Audit trail keyed by hashed phone so the collection holds no raw number.
    const id = rateLimitKey('verified-phone', input.phoneMasked + ':' + input.uid);
    await getFirestore().collection(VERIFICATIONS).doc(id).set({
      uid: input.uid,
      role: input.role,
      phoneMasked: input.phoneMasked,
      provider: input.provider,
      channel: input.channel,
      method: input.method,
      verifiedAtMs: input.atMs,
      verifiedAt: FieldValue.serverTimestamp(),
    });
  }
}

/**
 * Firestore-backed rate limiter. Each bucket is one document holding the
 * timestamps of recent events; the read-modify-write happens inside a
 * transaction so two concurrent requests cannot both slip past the limit.
 */
export class AdminRateLimiter implements RateLimiter {
  async consume(request: RateLimitRequest): Promise<RateLimitDecision> {
    const firestore = getFirestore();
    const ref = firestore.collection(RATE_LIMITS).doc(rateLimitKey(request.scope, request.identifier));

    return firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const stored = snapshot.get('events');
      const previous = Array.isArray(stored)
        ? stored.filter((value): value is number => typeof value === 'number')
        : [];

      const {decision, events} = evaluateWindow(previous, request);
      if (decision.allowed) {
        transaction.set(
          ref,
          {
            events,
            scope: request.scope,
            // Let a Firestore TTL policy clean these up.
            expiresAt: new Date(request.now + request.windowMs + 24 * 60 * 60 * 1000),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }
      return decision;
    });
  }
}

export class SystemClock implements Clock {
  nowMs(): number {
    return Date.now();
  }
}
