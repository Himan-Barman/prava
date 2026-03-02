import { secureStore } from '../adapters/secure-store';

const STORAGE_KEY_PREFIX = 'prava_chat_sync_';

function getStorageKey(userId: string) {
  return `${STORAGE_KEY_PREFIX}${userId}`;
}

function safeParse(value: string | null): Record<string, number> {
  if (!value) {
    return {};
  }

  try {
    const parsed = JSON.parse(value);
    if (!parsed || typeof parsed !== 'object') {
      return {};
    }
    const result: Record<string, number> = {};
    for (const [conversationId, seq] of Object.entries(parsed)) {
      const numeric = typeof seq === 'number' ? seq : Number.parseInt(String(seq), 10);
      if (!Number.isNaN(numeric) && numeric > 0) {
        result[conversationId] = numeric;
      }
    }
    return result;
  } catch {
    return {};
  }
}

class ChatSyncStore {
  private getKey(): string | null {
    const userId = secureStore.getUserId();
    if (!userId || !userId.trim()) {
      return null;
    }
    return getStorageKey(userId.trim());
  }

  getLastDeliveredMap(): Record<string, number> {
    const key = this.getKey();
    if (!key) {
      return {};
    }
    return safeParse(localStorage.getItem(key));
  }

  getLastDeliveredSeq(conversationId: string): number {
    if (!conversationId) {
      return 0;
    }
    return this.getLastDeliveredMap()[conversationId] ?? 0;
  }

  updateLastDeliveredSeq(conversationId: string, seq: number): void {
    if (!conversationId || seq <= 0) {
      return;
    }

    const key = this.getKey();
    if (!key) {
      return;
    }

    const current = this.getLastDeliveredMap();
    if ((current[conversationId] ?? 0) >= seq) {
      return;
    }

    current[conversationId] = seq;
    localStorage.setItem(key, JSON.stringify(current));
  }
}

export const chatSyncStore = new ChatSyncStore();
