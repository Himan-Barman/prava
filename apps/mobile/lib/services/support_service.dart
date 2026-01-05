import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';

class SupportService {
  SupportService({SecureStore? store})
      : _client = ApiClient(store ?? SecureStore());

  final ApiClient _client;

  Future<void> sendReport({
    required String category,
    required String message,
    required bool includeLogs,
  }) async {
    await _client.post(
      '/support',
      auth: true,
      body: {
        'type': 'report',
        'category': category,
        'message': message,
        'includeLogs': includeLogs,
      },
    );
  }

  Future<void> sendFeedback({
    required double score,
    required String message,
    required bool allowContact,
  }) async {
    await _client.post(
      '/support',
      auth: true,
      body: {
        'type': 'feedback',
        'message': message,
        'score': score,
        'allowContact': allowContact,
      },
    );
  }

  Future<void> sendHelp({
    required String message,
  }) async {
    await _client.post(
      '/support',
      auth: true,
      body: {
        'type': 'help',
        'message': message,
      },
    );
  }
}
