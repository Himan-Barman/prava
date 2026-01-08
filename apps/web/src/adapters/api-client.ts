/**
 * API Client for backend communication
 * Matches mobile's ApiClient with token refresh logic
 */

import axios, { AxiosError, AxiosInstance, AxiosRequestConfig } from 'axios';
import { secureStore } from './secure-store';
import { getOrCreateDeviceId } from './device-id';

// Get API URL from environment or default
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3100';

export class ApiException extends Error {
  constructor(
    public message: string,
    public statusCode?: number,
    public code?: string
  ) {
    super(message);
    this.name = 'ApiException';
  }
}

class ApiClient {
  private client: AxiosInstance;
  private isRefreshing = false;
  private refreshSubscribers: ((token: string) => void)[] = [];

  constructor() {
    this.client = axios.create({
      baseURL: API_BASE_URL,
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: 30000,
    });

    this.setupInterceptors();
  }

  private setupInterceptors() {
    // Response interceptor for error handling and token refresh
    this.client.interceptors.response.use(
      (response) => response,
      async (error: AxiosError) => {
        const originalRequest = error.config as AxiosRequestConfig & { _retry?: boolean };

        // Handle 401 and attempt token refresh
        if (error.response?.status === 401 && !originalRequest._retry) {
          if (this.isRefreshing) {
            return new Promise((resolve) => {
              this.refreshSubscribers.push((token: string) => {
                originalRequest.headers = originalRequest.headers || {};
                originalRequest.headers.Authorization = `Bearer ${token}`;
                resolve(this.client(originalRequest));
              });
            });
          }

          originalRequest._retry = true;
          this.isRefreshing = true;

          try {
            const refreshToken = secureStore.getRefreshToken();
            const deviceId = getOrCreateDeviceId();

            if (!refreshToken) {
              throw new Error('No refresh token');
            }

            const response = await this.client.post('/auth/refresh', {
              refreshToken,
              deviceId,
            });

            const { accessToken, refreshToken: newRefreshToken } = response.data;
            secureStore.setAccessToken(accessToken);
            if (newRefreshToken) {
              secureStore.setRefreshToken(newRefreshToken);
            }

            this.isRefreshing = false;
            this.refreshSubscribers.forEach((cb) => cb(accessToken));
            this.refreshSubscribers = [];

            originalRequest.headers = originalRequest.headers || {};
            originalRequest.headers.Authorization = `Bearer ${accessToken}`;
            return this.client(originalRequest);
          } catch (refreshError) {
            this.isRefreshing = false;
            this.refreshSubscribers = [];
            secureStore.clearSession();
            window.location.href = '/login';
            throw refreshError;
          }
        }

        // Transform error to ApiException
        const errorData = error.response?.data as { message?: string; error?: string } | undefined;
        const message = errorData?.message || errorData?.error || error.message || 'Network error';
        throw new ApiException(message, error.response?.status);
      }
    );
  }

  private getAuthHeaders(): Record<string, string> {
    const token = secureStore.getAccessToken();
    return token ? { Authorization: `Bearer ${token}` } : {};
  }

  async get<T>(endpoint: string, options?: { query?: Record<string, string>; auth?: boolean }): Promise<T> {
    const config: AxiosRequestConfig = {
      params: options?.query,
      headers: options?.auth ? this.getAuthHeaders() : {},
    };
    const response = await this.client.get<T>(endpoint, config);
    return response.data;
  }

  async post<T>(endpoint: string, options?: { body?: unknown; auth?: boolean }): Promise<T> {
    const config: AxiosRequestConfig = {
      headers: options?.auth ? this.getAuthHeaders() : {},
    };
    const response = await this.client.post<T>(endpoint, options?.body, config);
    return response.data;
  }

  async put<T>(endpoint: string, options?: { body?: unknown; auth?: boolean }): Promise<T> {
    const config: AxiosRequestConfig = {
      headers: options?.auth ? this.getAuthHeaders() : {},
    };
    const response = await this.client.put<T>(endpoint, options?.body, config);
    return response.data;
  }

  async delete<T>(endpoint: string, options?: { auth?: boolean }): Promise<T> {
    const config: AxiosRequestConfig = {
      headers: options?.auth ? this.getAuthHeaders() : {},
    };
    const response = await this.client.delete<T>(endpoint, config);
    return response.data;
  }
}

export const apiClient = new ApiClient();
