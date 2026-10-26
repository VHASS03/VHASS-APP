/**
 * OTP Generation Utility
 * OTPs are stored in Redis, NOT in MongoDB
 */
import { randomInt } from 'crypto';

/**
 * Generate random 6-digit OTP (cryptographically secure)
 */
export const generateOTP = (length: number = 6): string => {
  const min = Math.pow(10, length - 1);
  const max = Math.pow(10, length);
  return randomInt(min, max).toString();
};

/**
 * Whether the OTP may be handed back to the client (API response / Socket.IO).
 * Exposing it lets anyone who knows a phone number log in as that user, so it
 * must be off in production once server-side SMS (Twilio) is configured.
 * EXPOSE_OTP_IN_RESPONSE=true|false overrides; otherwise on only outside production.
 */
export const shouldExposeOtp = (): boolean => {
  const flag = process.env.EXPOSE_OTP_IN_RESPONSE;
  if (flag !== undefined && flag !== '') return flag === 'true';
  return process.env.NODE_ENV !== 'production';
};

/**
 * Validate OTP format
 */
export const validateOTPFormat = (otp: string): boolean => {
  return /^\d{6}$/.test(otp);
};

