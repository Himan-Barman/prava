const DEFAULT_BACKEND_API_URL = 'https://prava-1.onrender.com/api';

const resolveApiBaseUrl = (): string => {
  const explicit = (
    import.meta.env.VITE_API_URL
    || import.meta.env.VITE_API_BASE_URL
  ) as string | undefined;

  if (explicit && explicit.trim().length > 0) {
    return explicit.trim();
  }

  if (import.meta.env.PROD) {
    console.warn(`[apiClient] Missing VITE_API_URL. Falling back to ${DEFAULT_BACKEND_API_URL}.`);
    return DEFAULT_BACKEND_API_URL;
  }

  return 'http://localhost:3000/api';
};

const rawBaseUrl = resolveApiBaseUrl();

export const apiBaseUrl = rawBaseUrl.replace(/\/$/, '');

export const buildApiUrl = (path: string) => {
  if (!path) return apiBaseUrl;
  if (path.startsWith('http')) return path;
  if (path.startsWith('/')) return `${apiBaseUrl}${path}`;
  return `${apiBaseUrl}/${path}`;
};

export const jsonFetch = async <T>(
  path: string,
  init: RequestInit = {},
): Promise<T> => {
  const response = await fetch(buildApiUrl(path), {
    headers: {
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
    ...init,
  });

  if (!response.ok) {
    const message = await response.text();
    throw new Error(message || `Request failed: ${response.status}`);
  }

  const payload = await response.json();
  if (
    payload
    && typeof payload === 'object'
    && 'success' in payload
    && 'data' in payload
    && 'meta' in payload
  ) {
    return (payload as { data: T }).data;
  }
  return payload as T;
};
