const rawBaseUrl =
  import.meta.env.VITE_API_BASE_URL ?? 'https://prava-humg.onrender.com/api';

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
