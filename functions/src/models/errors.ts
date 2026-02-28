/**
 * Standard API error codes and response shape.
 * All endpoints return { ok: false, error: { code, message } } on failure.
 */

export const ErrorCodes = {
  UNAUTHENTICATED: "unauthenticated",
  FORBIDDEN: "forbidden",
  NOT_FOUND: "not_found",
  INVALID_ARGUMENT: "invalid_argument",
  CONFLICT: "conflict",
  CAPACITY_EXCEEDED: "capacity_exceeded",
  RATE_LIMITED: "rate_limited",
  INTERNAL: "internal",
} as const;

export type ErrorCode = (typeof ErrorCodes)[keyof typeof ErrorCodes];

export interface ApiErrorBody {
  code: string;
  message: string;
}

export class ApiError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly code: string,
    message: string
  ) {
    super(message);
    this.name = "ApiError";
  }

  toJson(): { ok: false; error: ApiErrorBody } {
    return {
      ok: false,
      error: { code: this.code, message: this.message },
    };
  }
}

export function unauthorized(message = "Authentication required"): ApiError {
  return new ApiError(401, ErrorCodes.UNAUTHENTICATED, message);
}

export function forbidden(message = "Forbidden"): ApiError {
  return new ApiError(403, ErrorCodes.FORBIDDEN, message);
}

export function notFound(message = "Resource not found"): ApiError {
  return new ApiError(404, ErrorCodes.NOT_FOUND, message);
}

export function invalidArgument(message: string): ApiError {
  return new ApiError(400, ErrorCodes.INVALID_ARGUMENT, message);
}

export function conflict(message: string): ApiError {
  return new ApiError(409, ErrorCodes.CONFLICT, message);
}

export function capacityExceeded(message: string): ApiError {
  return new ApiError(409, ErrorCodes.CAPACITY_EXCEEDED, message);
}

export function rateLimited(message = "Too many requests"): ApiError {
  return new ApiError(429, ErrorCodes.RATE_LIMITED, message);
}

export function internal(message = "Internal server error"): ApiError {
  return new ApiError(500, ErrorCodes.INTERNAL, message);
}
