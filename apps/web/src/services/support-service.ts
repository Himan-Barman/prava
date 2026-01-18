import { apiClient } from '../adapters/api-client';

class SupportService {
  async sendReport(input: {
    category: string;
    message: string;
    includeLogs: boolean;
  }) {
    await apiClient.post('/support', {
      auth: true,
      body: {
        type: 'report',
        category: input.category,
        message: input.message,
        includeLogs: input.includeLogs,
      },
    });
  }

  async sendFeedback(input: {
    score: number;
    message: string;
    allowContact: boolean;
  }) {
    await apiClient.post('/support', {
      auth: true,
      body: {
        type: 'feedback',
        score: input.score,
        message: input.message,
        allowContact: input.allowContact,
      },
    });
  }

  async sendHelp(input: { message: string }) {
    await apiClient.post('/support', {
      auth: true,
      body: {
        type: 'help',
        message: input.message,
      },
    });
  }
}

export const supportService = new SupportService();
