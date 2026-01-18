import { apiClient } from '../adapters/api-client';

export interface AccountInfo {
  id: string;
  email: string;
  username: string;
  displayName: string;
  firstName: string;
  lastName: string;
  phoneCountryCode: string;
  phoneNumber: string;
  bio: string;
  location: string;
  website: string;
  isVerified: boolean;
  emailVerifiedAt?: string | null;
  createdAt?: string | null;
  updatedAt?: string | null;
}

interface AccountResponse {
  account?: AccountInfo;
}

class AccountService {
  async fetchAccountInfo(): Promise<AccountInfo> {
    const data = await apiClient.get<AccountResponse>('/users/me/account', { auth: true });
    return data.account ?? {
      id: '',
      email: '',
      username: '',
      displayName: '',
      firstName: '',
      lastName: '',
      phoneCountryCode: '',
      phoneNumber: '',
      bio: '',
      location: '',
      website: '',
      isVerified: false,
      emailVerifiedAt: null,
      createdAt: null,
      updatedAt: null,
    };
  }

  async updateEmail(email: string) {
    return apiClient.put<{ email: string; isVerified: boolean; emailVerifiedAt?: string | null }>(
      '/users/me/email',
      {
        auth: true,
        body: { email },
      }
    );
  }

  async updateDetails(details: {
    firstName: string;
    lastName: string;
    phoneCountryCode: string;
    phoneNumber: string;
  }) {
    await apiClient.put('/users/me/details', {
      auth: true,
      body: details,
    });
    return this.fetchAccountInfo();
  }

  async updateHandle(input: {
    username?: string;
    displayName?: string;
    bio?: string;
    location?: string;
    website?: string;
  }) {
    const data = await apiClient.put<{ profile?: AccountInfo }>(
      '/users/me/handle',
      {
        auth: true,
        body: input,
      }
    );
    return data.profile ?? null;
  }

  async deleteAccount() {
    await apiClient.delete('/users/me', { auth: true });
  }
}

export const accountService = new AccountService();
