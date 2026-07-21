export type SmsProvider = 'twilio' | 'none';

export interface SmsSendResult {
  sent: boolean;
  provider: SmsProvider;
  error?: string;
}

/**
 * Send SMS using Twilio if configured.
 * Returns a status object without throwing (safe for non-critical flows).
 */
export async function sendSms(
  phoneNumber: string,
  message: string,
): Promise<SmsSendResult> {
  const formattedPhone = formatPhoneNumber(phoneNumber);

  const twilioAccountSid = process.env.TWILIO_ACCOUNT_SID;
  const twilioAuthToken = process.env.TWILIO_AUTH_TOKEN;
  const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER;

  if (!twilioAccountSid || !twilioAuthToken || !twilioPhoneNumber) {
    return { sent: false, provider: 'none' };
  }

  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const twilio = require('twilio');
    const client = twilio(twilioAccountSid, twilioAuthToken);

    await client.messages.create({
      body: message,
      from: twilioPhoneNumber,
      to: formattedPhone,
    });

    return { sent: true, provider: 'twilio' };
  } catch (error: any) {
    return {
      sent: false,
      provider: 'twilio',
      error: error?.message ?? 'Twilio send failed',
    };
  }
}

/**
 * Format phone number to international format.
 * Defaults to India country code (+91) for 10-digit numbers.
 */
function formatPhoneNumber(phone: string): string {
  const digits = phone.replace(/\D/g, '');

  if (digits.length === 12 && digits.startsWith('1')) {
    return `+${digits}`;
  }

  if (digits.length === 10) {
    return `+91${digits}`;
  }

  if (digits.length > 10) {
    const lastTen = digits.slice(-10);
    return `+91${lastTen}`;
  }

  return `+${digits}`;
}
