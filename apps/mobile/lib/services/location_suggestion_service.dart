import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';

class LocationSuggestion {
  LocationSuggestion({
    required this.city,
    required this.state,
    required this.country,
    required this.label,
  });

  final String city;
  final String state;
  final String country;
  final String label;

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}

class LocationSuggestionService {
  LocationSuggestionService({SecureStore? store})
      : _client = ApiClient(store ?? SecureStore());

  final ApiClient _client;

  Future<List<LocationSuggestion>> search(String query) async {
    final data = await _client.get(
      '/users/location-suggestions',
      auth: true,
      query: {
        'query': query,
        'limit': '8',
      },
    );
    final results = data is Map<String, dynamic>
        ? data['results'] as List<dynamic>? ?? []
        : <dynamic>[];
    return results
        .whereType<Map<String, dynamic>>()
        .map(LocationSuggestion.fromJson)
        .where((item) => item.label.trim().isNotEmpty)
        .toList();
  }
}
