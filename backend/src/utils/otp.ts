/**
 * OTP Generation Utility
 * OTPs are stored in Redis, NOT in MongoDB
 */

/**
 * Generate random 6-digit OTP
 */
export const generateOTP = (length: number = 6): string => {
  const min = Math.pow(10, length - 1);
  const max = Math.pow(10, length) - 1;
  return Math.floor(Math.random() * (max - min + 1) + min).toString();
};

/**
 * Validate OTP format
 */
export const validateOTPFormat = (otp: string): boolean => {
  return /^\d{6}$/.test(otp);
};

