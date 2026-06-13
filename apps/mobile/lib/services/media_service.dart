import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';

class MediaAsset {
  MediaAsset({
    required this.assetId,
    required this.secureUrl,
    required this.width,
    required this.height,
  });

  final String assetId;
  final String secureUrl;
  final int? width;
  final int? height;

  factory MediaAsset.fromJson(Map<String, dynamic> json) {
    return MediaAsset(
      assetId: json['assetId']?.toString() ?? '',
      secureUrl: json['secureUrl']?.toString() ?? json['url']?.toString() ?? '',
      width: json['width'] is int
          ? json['width'] as int
          : int.tryParse(json['width']?.toString() ?? ''),
      height: json['height'] is int
          ? json['height'] as int
          : int.tryParse(json['height']?.toString() ?? ''),
    );
  }
}

class MediaService {
  MediaService({SecureStore? store})
    : _client = ApiClient(store ?? SecureStore());

  final ApiClient _client;

  Future<MediaAsset> uploadProfileImage({
    required String dataUri,
    String context = 'profile_avatar',
  }) async {
    final data = await _client.post(
      '/media/upload',
      auth: true,
      body: {
        'dataUri': dataUri,
        'resourceType': 'image',
        'folder': 'prava/profile',
        'context': context,
      },
    );
    final payload = data is Map<String, dynamic>
        ? data['asset'] as Map<String, dynamic>? ?? {}
        : <String, dynamic>{};
    return MediaAsset.fromJson(payload);
  }

  Future<MediaAsset> uploadChatMedia({
    required String dataUri,
    required String resourceType,
    String context = 'chat_attachment',
  }) async {
    final data = await _client.post(
      '/media/upload',
      auth: true,
      body: {
        'dataUri': dataUri,
        'resourceType': resourceType,
        'folder': 'prava/chat',
        'context': context,
      },
    );
    final payload = data is Map<String, dynamic>
        ? data['asset'] as Map<String, dynamic>? ?? {}
        : <String, dynamic>{};
    return MediaAsset.fromJson(payload);
  }
}
