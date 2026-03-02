const resolveApiBaseUrl = (): string => {
  const explicit = (
    import.meta.env.VITE_API_URL
    || import.meta.env.VITE_API_BASE_URL
  ) as string | undefined;

  if (explicit && explicit.trim().length > 0) {
    return explicit.trim();
  }

  if (import.meta.env.PROD) {
    console.warn('[apiClient] Missing VITE_API_URL. Falling back to same-origin /api.');
    return '/api';
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

  return response.json() as Promise<T>;
};
