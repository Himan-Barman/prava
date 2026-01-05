import { BadRequestException, Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';

import { db } from '@/db';
import { supportTickets } from '@/db/schema/support_tickets.schema';
import { users } from '@/db/schema/users.schema';
import {
  isEmailConfigured,
  sendResendEmail,
} from '@/email/resend.client';
import { config } from '@/app.config';

@Injectable()
export class SupportService {
  async createTicket(input: {
    userId: string;
    type: 'help' | 'report' | 'feedback';
    category?: string;
    message: string;
    includeLogs?: boolean;
    allowContact?: boolean;
    score?: number;
  }) {
    const message = input.message.trim();
    if (!message) {
      throw new BadRequestException('Message is required');
    }

    const [user] = await db
      .select({
        id: users.id,
        email: users.email,
        username: users.username,
        displayName: users.displayName,
      })
      .from(users)
      .where(eq(users.id, input.userId))
      .limit(1);

    const metadata = {
      includeLogs: input.includeLogs ?? false,
      allowContact: input.allowContact ?? false,
      score: input.score ?? null,
    };

    const [row] = await db
      .insert(supportTickets)
      .values({
        userId: input.userId,
        type: input.type,
        category: input.category?.trim() || null,
        message,
        metadata,
      })
      .returning({
        id: supportTickets.id,
        createdAt: supportTickets.createdAt,
      });

    if (row && isEmailConfigured()) {
      const supportEmail =
        config.EMAIL_SUPPORT ?? config.EMAIL_FROM ?? '';
      if (supportEmail) {
        const title = input.category?.trim() || 'Support request';
        const subject = `[${input.type.toUpperCase()}] ${title} (${row.id})`;
        const identity = user
          ? `${user.displayName ?? user.username} <${user.email}>`
          : 'Unknown user';
        const text = [
          `Ticket: ${row.id}`,
          `Type: ${input.type}`,
          `Category: ${title}`,
          `User: ${identity}`,
          `Allow contact: ${metadata.allowContact ? 'yes' : 'no'}`,
          `Include logs: ${metadata.includeLogs ? 'yes' : 'no'}`,
          metadata.score ? `Score: ${metadata.score}` : null,
          '',
          message,
        ]
          .filter(Boolean)
          .join('\n');

        const html = `
          <h2>${title}</h2>
          <p><strong>Ticket:</strong> ${row.id}</p>
          <p><strong>Type:</strong> ${input.type}</p>
          <p><strong>User:</strong> ${identity}</p>
          <p><strong>Allow contact:</strong> ${
            metadata.allowContact ? 'yes' : 'no'
          }</p>
          <p><strong>Include logs:</strong> ${
            metadata.includeLogs ? 'yes' : 'no'
          }</p>
          ${
            metadata.score
              ? `<p><strong>Score:</strong> ${metadata.score}</p>`
              : ''
          }
          <hr />
          <p>${message.replace(/\n/g, '<br />')}</p>
        `;

        try {
          await sendResendEmail({
            to: supportEmail,
            subject,
            html,
            text,
          });
        } catch {
          // Email delivery is best-effort.
        }
      }
    }

    return {
      ticketId: row?.id ?? '',
      createdAt: row?.createdAt ?? new Date(),
    };
  }
}
