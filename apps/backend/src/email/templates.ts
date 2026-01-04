type EmailTemplate = {
  subject: string;
  html: string;
  text: string;
};

type LayoutOptions = {
  appName: string;
  title: string;
  preheader: string;
  bodyHtml: string;
  cta?: {
    label: string;
    url: string;
  };
  supportEmail?: string;
  footerNote?: string;
};

const escapeHtml = (value: string) =>
  value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const renderLayout = (options: LayoutOptions) => {
  const appName = escapeHtml(options.appName);
  const title = escapeHtml(options.title);
  const preheader = escapeHtml(options.preheader);
  const supportEmail = options.supportEmail
    ? escapeHtml(options.supportEmail)
    : '';
  const supportLink = options.supportEmail
    ? escapeHtml(options.supportEmail)
    : '';
  const footerNote = options.footerNote
    ? escapeHtml(options.footerNote)
    : '';
  const ctaLabel = options.cta
    ? escapeHtml(options.cta.label)
    : '';
  const ctaUrl = options.cta ? escapeHtml(options.cta.url) : '';

  const ctaBlock = options.cta
    ? `
      <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center" style="margin: 24px auto 0;">
        <tr>
          <td align="center" bgcolor="#2563eb" style="border-radius: 999px;">
            <a href="${ctaUrl}" style="display: inline-block; padding: 12px 28px; font-family: 'Segoe UI', 'Helvetica Neue', Arial, sans-serif; font-size: 15px; color: #ffffff; text-decoration: none; font-weight: 600;">
              ${ctaLabel}
            </a>
          </td>
        </tr>
      </table>
      <div style="margin-top: 18px; font-size: 12px; color: #6b7280; text-align: center;">
        Or copy this link into your browser:<br />
        <a href="${ctaUrl}" style="color: #2563eb; text-decoration: none;">${ctaUrl}</a>
      </div>
    `
    : '';

  const supportBlock = options.supportEmail
    ? `
        <div style="margin-top: 22px; font-size: 13px; color: #6b7280; text-align: center;">
          Need help? Contact
          <a href="mailto:${supportLink}" style="color: #2563eb; text-decoration: none;">
            ${supportEmail}
          </a>.
        </div>
      `
    : '';

  const footerNoteBlock = options.footerNote
    ? `
        <div style="margin-top: 10px; font-size: 12px; color: #9ca3af; text-align: center;">
          ${footerNote}
        </div>
      `
    : '';

  return `<!doctype html>
<html>
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>${title}</title>
  </head>
  <body style="margin: 0; padding: 0; background-color: #f3f4f6;">
    <div style="display: none; max-height: 0; overflow: hidden; opacity: 0;">
      ${preheader}
    </div>
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background-color: #f3f4f6; padding: 24px 0;">
      <tr>
        <td align="center">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="600" style="max-width: 600px; width: 100%;">
            <tr>
              <td style="background: linear-gradient(135deg, #111827 0%, #2563eb 100%); border-radius: 16px 16px 0 0; padding: 28px;">
                <div style="font-family: 'Segoe UI', 'Helvetica Neue', Arial, sans-serif; font-size: 18px; letter-spacing: 2px; text-transform: uppercase; color: #e5e7eb;">
                  ${appName}
                </div>
                <div style="margin-top: 8px; font-family: 'Segoe UI', 'Helvetica Neue', Arial, sans-serif; font-size: 26px; color: #ffffff; font-weight: 700;">
                  ${title}
                </div>
              </td>
            </tr>
            <tr>
              <td style="background-color: #ffffff; padding: 28px 28px 32px; border-radius: 0 0 16px 16px; border: 1px solid #e5e7eb; border-top: none;">
                ${options.bodyHtml}
                ${ctaBlock}
                ${supportBlock}
                ${footerNoteBlock}
              </td>
            </tr>
          </table>
          <div style="margin-top: 18px; font-size: 11px; color: #9ca3af; font-family: 'Segoe UI', 'Helvetica Neue', Arial, sans-serif;">
            You are receiving this email because a request was made for your account.
          </div>
        </td>
      </tr>
    </table>
  </body>
</html>`;
};

export const renderOtpEmail = (input: {
  appName: string;
  code: string;
  expiresInMinutes: number;
  supportEmail?: string;
  subject?: string;
  title?: string;
  message?: string;
  preheader?: string;
}): EmailTemplate => {
  const code = escapeHtml(input.code);
  const appName = escapeHtml(input.appName);
  const title = input.title ?? 'Verification code';
  const subject =
    input.subject ?? `Your ${input.appName} verification code`;
  const message =
    input.message ??
    `Use this verification code to finish setting up your ${input.appName} account. This code expires in ${input.expiresInMinutes} minutes.`;
  const preheader =
    input.preheader ??
    `Your ${input.appName} verification code is ${input.code}`;

  const bodyHtml = `
    <div style="font-family: 'Segoe UI', 'Helvetica Neue', Arial, sans-serif; font-size: 16px; color: #111827; line-height: 1.6;">
      ${escapeHtml(message)}
    </div>
    <div style="margin: 28px 0 16px; text-align: center;">
      <div style="display: inline-block; padding: 14px 24px; border-radius: 12px; background-color: #111827; color: #ffffff; font-family: 'Courier New', Courier, monospace; font-size: 28px; letter-spacing: 8px; font-weight: 700;">
        ${code}
      </div>
    </div>
    <div style="font-family: 'Segoe UI', 'Helvetica Neue', Arial, sans-serif; font-size: 14px; color: #6b7280; text-align: center;">
      If you did not request this code, you can safely ignore this email.
    </div>
  `;

  return {
    subject,
    html: renderLayout({
      appName: input.appName,
      title,
      preheader,
      bodyHtml,
      supportEmail: input.supportEmail,
      footerNote: `Code expires in ${input.expiresInMinutes} minutes.`,
    }),
    text: `${subject}\n\n${message}\n\nCode: ${input.code}\n\nThis code expires in ${input.expiresInMinutes} minutes.\n\nIf you did not request this code, you can ignore this message.`,
  };
};

export const renderVerifyEmail = (input: {
  appName: string;
  token: string;
  verifyUrl?: string;
  supportEmail?: string;
}): EmailTemplate => {
  const token = escapeHtml(input.token);
  const appName = escapeHtml(input.appName);

  const bodyHtml = `
    <div style="font-family: 'Segoe UI', 'Helvetica Neue', Arial, sans-serif; font-size: 16px; color: #111827; line-height: 1.6;">
      Confirm your email address to activate your ${appName} account.
    </div>
    ${
      input.verifyUrl
        ? ''
        : `<div style="margin-top: 18px; font-family: 'Courier New', Courier, monospace; font-size: 14px; background-color: #f9fafb; padding: 12px; border-radius: 10px; color: #111827; word-break: break-all;">
            Verification token: ${token}
          </div>`
    }
  `;

  return {
    subject: `Verify your ${input.appName} email`,
    html: renderLayout({
      appName: input.appName,
      title: 'Verify your email',
      preheader: `Verify your ${input.appName} email address.`,
      bodyHtml,
      cta: input.verifyUrl
        ? { label: 'Verify email', url: input.verifyUrl }
        : undefined,
      supportEmail: input.supportEmail,
    }),
    text: input.verifyUrl
      ? `Verify your ${input.appName} email address:\n${input.verifyUrl}\n\nIf you did not request this email, you can ignore it.`
      : `Verify your ${input.appName} email address using this token:\n${input.token}\n\nIf you did not request this email, you can ignore it.`,
  };
};

export const renderPasswordResetEmail = (input: {
  appName: string;
  token: string;
  resetUrl?: string;
  supportEmail?: string;
}): EmailTemplate => {
  const token = escapeHtml(input.token);
  const appName = escapeHtml(input.appName);

  const bodyHtml = `
    <div style="font-family: 'Segoe UI', 'Helvetica Neue', Arial, sans-serif; font-size: 16px; color: #111827; line-height: 1.6;">
      We received a request to reset your ${appName} password.
      If you did not request this, you can ignore this email.
    </div>
    ${
      input.resetUrl
        ? ''
        : `<div style="margin-top: 18px; font-family: 'Courier New', Courier, monospace; font-size: 14px; background-color: #f9fafb; padding: 12px; border-radius: 10px; color: #111827; word-break: break-all;">
            Reset token: ${token}
          </div>`
    }
  `;

  return {
    subject: `Reset your ${input.appName} password`,
    html: renderLayout({
      appName: input.appName,
      title: 'Reset your password',
      preheader: `Reset your ${input.appName} password.`,
      bodyHtml,
      cta: input.resetUrl
        ? { label: 'Reset password', url: input.resetUrl }
        : undefined,
      supportEmail: input.supportEmail,
    }),
    text: input.resetUrl
      ? `Reset your ${input.appName} password:\n${input.resetUrl}\n\nIf you did not request this email, you can ignore it.`
      : `Reset your ${input.appName} password using this token:\n${input.token}\n\nIf you did not request this email, you can ignore it.`,
  };
};
