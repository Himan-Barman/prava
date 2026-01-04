import { Worker } from 'bullmq';
import { connection } from '../bullmq.config';
import { config } from '@/app.config';
import {
  isEmailConfigured,
  sendResendEmail,
} from '@/email/resend.client';
import {
  renderOtpEmail,
  renderPasswordResetEmail,
  renderVerifyEmail,
} from '@/email/templates';

type EmailJob =
  | {
      type: 'verify-email';
      email: string;
      token: string;
    }
  | {
      type: 'password-reset';
      email: string;
      token?: string;
      code?: string;
      expiresInMinutes?: number;
    }
  | {
      type: 'email-otp';
      email: string;
      code: string;
      expiresInMinutes?: number;
    };

export const emailWorker = new Worker<EmailJob>(
  'email',
  async (job) => {
    if (!isEmailConfigured()) {
      if (config.NODE_ENV === 'production') {
        throw new Error(
          'Email service not configured. Set RESEND_API_KEY and EMAIL_FROM.',
        );
      }
      console.warn(
        'Email service not configured. Skipping email delivery.',
      );
      return;
    }

    const appName = config.APP_NAME ?? 'PRAVA';
    const supportEmail = config.EMAIL_SUPPORT ?? config.EMAIL_FROM;

    const withToken = (baseUrl: string | undefined, token: string) => {
      if (!baseUrl) return undefined;
      const delimiter = baseUrl.includes('?') ? '&' : '?';
      return `${baseUrl}${delimiter}token=${encodeURIComponent(token)}`;
    };

    switch (job.data.type) {
      case 'verify-email':
        {
          const template = renderVerifyEmail({
            appName,
            token: job.data.token,
            verifyUrl: withToken(
              config.EMAIL_VERIFY_URL,
              job.data.token,
            ),
            supportEmail,
          });

          await sendResendEmail({
            to: job.data.email,
            subject: template.subject,
            html: template.html,
            text: template.text,
          });
        }
        break;

      case 'password-reset':
        {
          if (job.data.code) {
            const template = renderOtpEmail({
              appName,
              code: job.data.code,
              expiresInMinutes: job.data.expiresInMinutes ?? 10,
              supportEmail,
              subject: `Your ${appName} password reset code`,
              title: 'Reset your password',
              message: `Use this code to reset your ${appName} password. This code expires in ${job.data.expiresInMinutes ?? 10} minutes.`,
              preheader: `Your ${appName} password reset code is ${job.data.code}`,
            });

            await sendResendEmail({
              to: job.data.email,
              subject: template.subject,
              html: template.html,
              text: template.text,
            });
          } else if (job.data.token) {
            const template = renderPasswordResetEmail({
              appName,
              token: job.data.token,
              resetUrl: withToken(
                config.PASSWORD_RESET_URL,
                job.data.token,
              ),
              supportEmail,
            });

            await sendResendEmail({
              to: job.data.email,
              subject: template.subject,
              html: template.html,
              text: template.text,
            });
          }
        }
        break;

      case 'email-otp':
        {
          const template = renderOtpEmail({
            appName,
            code: job.data.code,
            expiresInMinutes: job.data.expiresInMinutes ?? 10,
            supportEmail,
          });

          await sendResendEmail({
            to: job.data.email,
            subject: template.subject,
            html: template.html,
            text: template.text,
          });
        }
        break;
    }
  },
  {
    ...connection,
    concurrency: 5,
  },
);

emailWorker.on('failed', (job, err) => {
  console.error(
    `Email job failed (${job?.id})`,
    err.message,
  );
});
