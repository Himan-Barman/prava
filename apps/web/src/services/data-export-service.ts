import { apiClient } from '../adapters/api-client';

export interface DataExport {
  id: string;
  status: string;
  format: string;
  payload: Record<string, unknown>;
  createdAt?: string | null;
  completedAt?: string | null;
}

class DataExportService {
  async fetchLatest(): Promise<DataExport | null> {
    const data = await apiClient.get<{ export?: DataExport | null }>(
      '/users/me/data-export',
      { auth: true }
    );
    return data.export ?? null;
  }

  async requestExport(): Promise<DataExport | null> {
    const data = await apiClient.post<{ export?: DataExport | null }>(
      '/users/me/data-export',
      { auth: true }
    );
    return data.export ?? null;
  }
}

export const dataExportService = new DataExportService();
