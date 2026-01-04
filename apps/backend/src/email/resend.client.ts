import { config } from '@/app.config';

type EmailPayload = {
  to: string;
  subject: string;
  html: string;
  text: string;
};

const RESEND_ENDPOINT = 'https://api.resend.com/emails';

const buildFromAddress = () => {
  if (!config.EMAIL_FROM) return '';
  if (!config.EMAIL_FROM_NAME) return config.EMAIL_FROM;
  return `${config.EMAIL_FROM_NAME} <${config.EMAIL_FROM}>`;
};

export const isEmailConfigured = () =>
  Boolean(config.RESEND_API_KEY && config.EMAIL_FROM);

export async function sendResendEmail(payload: EmailPayload) {
  if (!config.RESEND_API_KEY || !config.EMAIL_FROM) {
    throw new Error(
      'Resend email is not configured. Set RESEND_API_KEY and EMAIL_FROM.',
    );
  }

  const response = await fetch(RESEND_ENDPOINT, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: buildFromAddress(),
      to: [payload.to],
      subject: payload.subject,
      html: payload.html,
      text: payload.text,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(
      `Resend API error (${response.status}): ${body}`,
    );
  }
}
