import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';

class DataExport {
  DataExport({
    required this.id,
    required this.status,
    required this.format,
    required this.payload,
    required this.createdAt,
    required this.completedAt,
  });

  final String id;
  final String status;
  final String format;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;
  final DateTime? completedAt;

  factory DataExport.fromJson(Map<String, dynamic> json) {
    return DataExport(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      format: json['format']?.toString() ?? '',
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : <String, dynamic>{},
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      completedAt:
          DateTime.tryParse(json['completedAt']?.toString() ?? ''),
    );
  }
}

class DataExportService {
  DataExportService({SecureStore? store})
      : _client = ApiClient(store ?? SecureStore());

  final ApiClient _client;

  Future<DataExport?> fetchLatest() async {
    final data = await _client.get('/users/me/data-export', auth: true);
    if (data is! Map<String, dynamic>) return null;
    final export = data['export'];
    if (export is! Map<String, dynamic>) return null;
    return DataExport.fromJson(export);
  }

  Future<DataExport?> requestExport() async {
    final data = await _client.post('/users/me/data-export', auth: true);
    if (data is! Map<String, dynamic>) return null;
    final export = data['export'];
    if (export is! Map<String, dynamic>) return null;
    return DataExport.fromJson(export);
  }
}
