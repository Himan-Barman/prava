import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';

class AccountInfo {
  AccountInfo({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    required this.phoneCountryCode,
    required this.phoneNumber,
    required this.bio,
    required this.location,
    required this.website,
    required this.avatarUrl,
    required this.coverUrl,
    required this.pinnedDetails,
    required this.category,
    required this.aiCreator,
    required this.hometown,
    required this.isVerified,
    required this.emailVerifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String email;
  final String username;
  final String displayName;
  final String firstName;
  final String lastName;
  final String phoneCountryCode;
  final String phoneNumber;
  final String bio;
  final String location;
  final String website;
  final String avatarUrl;
  final String coverUrl;
  final String pinnedDetails;
  final String category;
  final bool aiCreator;
  final String hometown;
  final bool isVerified;
  final DateTime? emailVerifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AccountInfo.fromJson(Map<String, dynamic> json) {
    return AccountInfo(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      phoneCountryCode: json['phoneCountryCode']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      pinnedDetails: json['pinnedDetails']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      aiCreator: json['aiCreator'] == true,
      hometown: json['hometown']?.toString() ?? '',
      isVerified: json['isVerified'] == true,
      emailVerifiedAt: DateTime.tryParse(
        json['emailVerifiedAt']?.toString() ?? '',
      ),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}

class AccountService {
  AccountService({SecureStore? store})
      : _client = ApiClient(store ?? SecureStore());

  final ApiClient _client;

  Future<AccountInfo> fetchAccountInfo() async {
    final data = await _client.get('/users/me/account', auth: true);
    final payload = data is Map<String, dynamic>
        ? data['account'] as Map<String, dynamic>? ?? {}
        : <String, dynamic>{};
    return AccountInfo.fromJson(payload);
  }

  Future<AccountInfo> updateEmail(String email) async {
    await _client.put(
      '/users/me/email',
      auth: true,
      body: {'email': email},
    );
    return fetchAccountInfo();
  }

  Future<AccountInfo> updateDetails({
    required String firstName,
    required String lastName,
    required String phoneCountryCode,
    required String phoneNumber,
  }) async {
    await _client.put(
      '/users/me/details',
      auth: true,
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'phoneCountryCode': phoneCountryCode,
        'phoneNumber': phoneNumber,
      },
    );
    return fetchAccountInfo();
  }

  Future<AccountInfo> updateHandle({
    String? username,
    String? displayName,
    String? bio,
    String? location,
    String? website,
  }) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (displayName != null) body['displayName'] = displayName;
    if (bio != null) body['bio'] = bio;
    if (location != null) body['location'] = location;
    if (website != null) body['website'] = website;

    await _client.put(
      '/users/me/handle',
      auth: true,
      body: body,
    );
    return fetchAccountInfo();
  }

  Future<AccountInfo> updateProfileDetails({
    String? bio,
    String? pinnedDetails,
    String? category,
    bool? aiCreator,
    String? location,
    String? hometown,
    String? website,
    String? phoneCountryCode,
    String? phoneNumber,
  }) async {
    final body = <String, dynamic>{};
    if (bio != null) body['bio'] = bio;
    if (pinnedDetails != null) body['pinnedDetails'] = pinnedDetails;
    if (category != null) body['category'] = category;
    if (aiCreator != null) body['aiCreator'] = aiCreator;
    if (location != null) body['location'] = location;
    if (hometown != null) body['hometown'] = hometown;
    if (website != null) body['website'] = website;
    if (phoneCountryCode != null) {
      body['phoneCountryCode'] = phoneCountryCode;
    }
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;

    final data = await _client.put(
      '/users/me/profile-details',
      auth: true,
      body: body,
    );
    final payload = data is Map<String, dynamic>
        ? data['profile'] as Map<String, dynamic>? ?? {}
        : <String, dynamic>{};
    return AccountInfo.fromJson(payload);
  }

  Future<AccountInfo> updateProfileMedia({
    String? avatarUrl,
    String? coverUrl,
  }) async {
    final body = <String, dynamic>{};
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
    if (coverUrl != null) body['coverUrl'] = coverUrl;

    final data = await _client.put(
      '/users/me/profile-media',
      auth: true,
      body: body,
    );
    final payload = data is Map<String, dynamic>
        ? data['profile'] as Map<String, dynamic>? ?? {}
        : <String, dynamic>{};
    return AccountInfo.fromJson(payload);
  }

  Future<void> deleteAccount() async {
    await _client.delete('/users/me', auth: true);
  }
}
