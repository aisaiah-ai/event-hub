/**
 * Idempotency keys for check-in.
 * Deterministic checkin IDs: main_${uid}, session_${sessionId}_${uid}.
 */

export function mainCheckInId(uid: string): string {
  return `main_${uid}`;
}

export function sessionCheckInId(sessionId: string, uid: string): string {
  return `session_${sessionId}_${uid}`;
}
