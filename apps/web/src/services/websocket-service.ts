import { secureStore } from '../adapters/secure-store';
import { getOrCreateDeviceId } from '../adapters/device-id';

const resolveWsBase = () => {
  const explicit = import.meta.env.VITE_WS_URL as string | undefined;
  if (explicit && explicit.trim().length > 0) {
    return explicit.replace(/\/+$/, '').replace(/^http/, 'ws');
  }

  const apiBase = (
    (import.meta.env.VITE_API_URL && import.meta.env.VITE_API_URL.trim().length > 0)
      ? import.meta.env.VITE_API_URL
      : (import.meta.env.PROD ? 'https://prava-humg.onrender.com/api' : 'http://localhost:3100/api')
  ).replace(/\/+$/, '');
  const trimmed = apiBase.replace(/\/api$/i, '');
  return trimmed.replace(/^http/, 'ws');
};

const WS_BASE_URL = resolveWsBase();

type WebSocketCallback = (data: any) => void;

class WebSocketService {
  private socket: WebSocket | null = null;
  private subscribers: Map<string, Set<WebSocketCallback>> = new Map();
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectTimeout: ReturnType<typeof setTimeout> | null = null;
  private isConnecting = false;

  connect() {
    if (this.socket?.readyState === WebSocket.OPEN || this.isConnecting) return;

    this.isConnecting = true;
    const token = secureStore.getAccessToken();
    const deviceId = getOrCreateDeviceId();
    const url = `${WS_BASE_URL}?token=${token}&deviceId=${deviceId}`;

    this.socket = new WebSocket(url);

    this.socket.onopen = () => {
      console.log('WebSocket connected');
      this.isConnecting = false;
      this.reconnectAttempts = 0;
      this.notify('connection', { status: 'connected' });
    };

    this.socket.onmessage = (event) => {
      try {
        const message = JSON.parse(event.data);
        if (message.type) {
          this.notify(message.type, message.payload);
        }
      } catch (error) {
        console.error('Failed to parse WebSocket message:', error);
      }
    };

    this.socket.onclose = () => {
      console.log('WebSocket disconnected');
      this.isConnecting = false;
      this.notify('connection', { status: 'disconnected' });
      this.attemptReconnect();
    };

    this.socket.onerror = (error) => {
      console.error('WebSocket error:', error);
      this.isConnecting = false;
    };
  }

  disconnect() {
    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout);
      this.reconnectTimeout = null;
    }

    if (this.socket) {
      this.socket.close();
      this.socket = null;
    }
  }

  subscribe(event: string, callback: WebSocketCallback) {
    if (!this.subscribers.has(event)) {
      this.subscribers.set(event, new Set());
    }
    this.subscribers.get(event)?.add(callback);

    // Return unsubscribe function
    return () => {
      const callbacks = this.subscribers.get(event);
      if (callbacks) {
        callbacks.delete(callback);
        if (callbacks.size === 0) {
          this.subscribers.delete(event);
        }
      }
    };
  }

  send(type: string, payload: any) {
    if (this.socket?.readyState === WebSocket.OPEN) {
      this.socket.send(JSON.stringify({ type, payload }));
    } else {
      console.warn('WebSocket not connected, cannot send message:', type);
    }
  }

  private notify(event: string, data: any) {
    const callbacks = this.subscribers.get(event);
    if (callbacks) {
      callbacks.forEach((callback) => callback(data));
    }
  }

  private attemptReconnect() {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 10000);
      this.reconnectAttempts++;

      console.log(`Attempting reconnection in ${delay}ms...`);
      this.reconnectTimeout = setTimeout(() => {
        this.connect();
      }, delay);
    } else {
      console.error('Max reconnection attempts reached');
    }
  }
}

export const webSocketService = new WebSocketService();
