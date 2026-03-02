import { env } from "../config/env.js";

type OtpEmailType = "verification" | "password-reset";

interface OtpEmailPayload {
  to: string;
  code: string;
  type: OtpEmailType;
}

interface SendEmailPayload {
  to: string;
  subject: string;
  html: string;
  text: string;
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function buildOtpSubject(type: OtpEmailType): string {
  if (type === "password-reset") {
    return `${env.APP_NAME} password reset code`;
  }
  return `${env.APP_NAME} email verification code`;
}

function buildOtpIntro(type: OtpEmailType): string {
  if (type === "password-reset") {
    return "Use this one-time code to reset your password.";
  }
  return "Use this one-time code to verify your email address.";
}

function buildOtpCta(type: OtpEmailType): string {
  if (type === "password-reset") {
    return "Reset your password securely";
  }
  return "Verify your email securely";
}

function buildOtpEmail({ code, type }: { code: string; type: OtpEmailType }): { html: string; text: string } {
  const escapedCode = escapeHtml(code);
  const escapedAppName = escapeHtml(env.APP_NAME);
  const intro = escapeHtml(buildOtpIntro(type));
  const cta = escapeHtml(buildOtpCta(type));
  const expiresIn = env.OTP_EXPIRES_MINUTES;
  const publicUrl = env.APP_PUBLIC_URL;
  const webUrl = publicUrl ? publicUrl.replace(/\/+$/, "") : "";
  const supportLine = env.EMAIL_REPLY_TO
    ? `Need help? Reply to ${escapeHtml(env.EMAIL_REPLY_TO)}.`
    : "If you did not request this, you can ignore this email.";

  const text = [
    `${env.APP_NAME} Security`,
    "",
    buildOtpIntro(type),
    `Code: ${code}`,
    `Expires in ${expiresIn} minutes.`,
    "",
    webUrl ? `Open ${webUrl}` : "",
    supportLine.replace(/<[^>]+>/g, ""),
  ].filter(Boolean).join("\n");

  const html = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>${escapedAppName} Security Code</title>
  </head>
  <body style="margin:0;padding:0;background:#06080f;color:#e7edf9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Inter,Arial,sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#06080f;padding:28px 14px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:620px;background:linear-gradient(160deg,#0d1223 0%,#0b0f1d 100%);border:1px solid #1d2948;border-radius:20px;overflow:hidden;">
            <tr>
              <td style="padding:32px 28px 12px 28px;">
                <div style="font-size:12px;letter-spacing:1.7px;text-transform:uppercase;color:#84a4ff;font-weight:700;">${escapedAppName} Security</div>
                <h1 style="margin:12px 0 10px 0;font-size:28px;line-height:1.15;color:#f5f8ff;">${cta}</h1>
                <p style="margin:0;color:#a8b6d8;font-size:15px;line-height:1.6;">${intro}</p>
              </td>
            </tr>
            <tr>
              <td style="padding:18px 28px 6px 28px;">
                <div style="background:radial-gradient(120% 160% at 10% 0%,#5b8cff 0%,#4f6cd8 45%,#314cb7 100%);border-radius:16px;padding:18px 20px;border:1px solid rgba(255,255,255,0.18);">
                  <div style="font-size:11px;letter-spacing:1.5px;text-transform:uppercase;color:#dce6ff;opacity:0.95;font-weight:700;">One-time code</div>
                  <div style="margin-top:8px;font-size:36px;line-height:1.15;font-weight:800;letter-spacing:10px;color:#ffffff;font-variant-numeric:tabular-nums;">${escapedCode}</div>
                </div>
              </td>
            </tr>
            <tr>
              <td style="padding:14px 28px 12px 28px;">
                <p style="margin:0;color:#9cb0df;font-size:14px;line-height:1.7;">
                  This code expires in <strong style="color:#dbe6ff;">${expiresIn} minutes</strong> and can be used only once.
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:6px 28px 28px 28px;">
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#0a1020;border:1px solid #1c2a4e;border-radius:14px;">
                  <tr>
                    <td style="padding:14px 16px;color:#8fa4d4;font-size:13px;line-height:1.6;">
                      ${supportLine}
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr>
              <td style="padding:0 28px 24px 28px;color:#6f81a9;font-size:12px;line-height:1.7;">
                Sent by ${escapedAppName}${webUrl ? ` • <a href="${escapeHtml(webUrl)}" style="color:#87a7ff;text-decoration:none;">${escapeHtml(webUrl)}</a>` : ""}
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;

  return { html, text };
}

async function sendWithResend({ to, subject, html, text }: SendEmailPayload): Promise<void> {
  if (!env.RESEND_API_KEY || !env.EMAIL_FROM) {
    if (env.NODE_ENV === "production") {
      throw new Error("Email provider is not configured (RESEND_API_KEY / EMAIL_FROM)");
    }
    return;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 12_000);

  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: env.EMAIL_FROM,
        to: [to],
        subject,
        html,
        text,
        ...(env.EMAIL_REPLY_TO ? { reply_to: env.EMAIL_REPLY_TO } : {}),
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      const bodyText = await response.text();
      throw new Error(`Resend API failed (${response.status}): ${bodyText}`);
    }
  } finally {
    clearTimeout(timeout);
  }
}

export async function sendOtpEmail(payload: OtpEmailPayload): Promise<void> {
  const { html, text } = buildOtpEmail({
    code: payload.code,
    type: payload.type,
  });

  await sendWithResend({
    to: payload.to,
    subject: buildOtpSubject(payload.type),
    html,
    text,
  });
}
