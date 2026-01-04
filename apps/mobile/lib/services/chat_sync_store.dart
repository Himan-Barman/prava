import 'dart:convert';

import '../core/storage/secure_store.dart';

class ChatSyncStore {
  ChatSyncStore({SecureStore? store}) : _store = store ?? SecureStore();

  final SecureStore _store;

  Future<Map<String, int>> getLastDeliveredMap() async {
    final raw = await _store.getChatSyncStateJson();
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      final result = <String, int>{};
      decoded.forEach((key, value) {
        final seq = value is int
            ? value
            : int.tryParse(value?.toString() ?? '');
        if (seq != null && seq > 0) {
          result[key] = seq;
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<int> getLastDeliveredSeq(String conversationId) async {
    if (conversationId.isEmpty) return 0;
    final state = await getLastDeliveredMap();
    return state[conversationId] ?? 0;
  }

  Future<void> updateLastDeliveredSeq(
    String conversationId,
    int seq,
  ) async {
    if (conversationId.isEmpty || seq <= 0) return;
    final state = await getLastDeliveredMap();
    final current = state[conversationId] ?? 0;
    if (seq <= current) return;
    state[conversationId] = seq;
    await _store.setChatSyncStateJson(jsonEncode(state));
  }
}
