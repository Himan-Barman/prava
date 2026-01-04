import 'dart:convert';
import 'dart:typed_data';

import '../core/device/device_id.dart';
import '../core/storage/secure_store.dart';
import '../security/ratchet/group/sender_key_distribution.dart';
import '../security/ratchet/group/sender_key_ratchet.dart';
import '../security/ratchet/group/sender_key_state.dart';
import '../security/security_init.dart';
import '../security/storage/sender_key_store.dart';
import 'e2ee_service.dart';

class GroupE2eeService {
  static const String groupEnvelopePrefix = 'e2ee.g1:';
  static const String distributionType = 'sender_key_distribution';

  GroupE2eeService({SecureStore? store, E2eeService? e2ee})
      : _store = store ?? SecureStore(),
        _deviceIdStore = DeviceIdStore(store ?? SecureStore()),
        _e2ee = e2ee ?? E2eeService(store: store ?? SecureStore());

  final SecureStore _store;
  final DeviceIdStore _deviceIdStore;
  final E2eeService _e2ee;

  static bool isGroupEncrypted(String body) {
    return body.startsWith(groupEnvelopePrefix);
  }

  Future<void> ensureReady() async {
    if (SecurityInit.isInitialized) return;
    await SecurityInit.initialize(config: SecurityConfig.development());
  }

  Future<GroupSenderKeyBundle?> ensureOwnSenderKey({
    required String groupId,
  }) async {
    await ensureReady();
    final userId = await _store.getUserId();
    if (userId == null || userId.isEmpty) return null;
    final deviceId = await _deviceIdStore.getOrCreate();

    var existing = await SenderKeyStore.getLatestOwnSenderKey(
      groupId: groupId,
      senderId: userId,
      deviceId: deviceId,
    );
    final needsRotate = existing == null ||
        existing.signaturePrivateKey == null ||
        SenderKeyRatchet.needsRotation(existing);

    if (needsRotate) {
      existing?.dispose();
      final created = await SenderKeyRatchet.createSenderKey(
        groupId: groupId,
        senderId: userId,
        deviceId: deviceId,
      );
      await SenderKeyStore.saveSenderKey(
        senderKey: created,
        isOwn: true,
      );
      return GroupSenderKeyBundle(
        senderKey: created,
        needsDistribution: true,
      );
    }

    return GroupSenderKeyBundle(
      senderKey: existing,
      needsDistribution: false,
    );
  }

  Future<GroupEncryptResult?> encryptGroupMessage({
    required String groupId,
    required String plaintext,
  }) async {
    final bundle = await ensureOwnSenderKey(groupId: groupId);
    if (bundle == null) return null;
    return encryptGroupMessageWithKey(
      senderKey: bundle.senderKey,
      plaintext: plaintext,
      needsDistribution: bundle.needsDistribution,
    );
  }

  Future<GroupEncryptResult?> encryptGroupMessageWithKey({
    required SenderKeyState senderKey,
    required String plaintext,
    bool needsDistribution = false,
  }) async {
    final message = await SenderKeyRatchet.encrypt(
      plaintext: Uint8List.fromList(utf8.encode(plaintext)),
      senderKey: senderKey,
    );

    await SenderKeyStore.saveSenderKey(
      senderKey: senderKey,
      isOwn: true,
    );

    return GroupEncryptResult(
      body: _encodeGroupEnvelope(message),
      needsDistribution: needsDistribution,
    );
  }

  Future<String?> decryptGroupMessage({
    required String body,
    required String senderUserId,
    required String senderDeviceId,
  }) async {
    final payload = _decodeGroupEnvelope(body);
    if (payload == null) return null;
    final messageRaw = payload['message'];
    if (messageRaw is! Map<String, dynamic>) return null;
    final message = SenderKeyMessage.fromJson(messageRaw);
    if (message.senderId != senderUserId ||
        message.deviceId != senderDeviceId) {
      return null;
    }

    final senderKey = await SenderKeyStore.getSenderKey(
      groupId: message.groupId,
      senderId: message.senderId,
      deviceId: message.deviceId,
      keyId: message.keyId,
    );
    if (senderKey == null) return null;

    final plaintext = await SenderKeyRatchet.decrypt(
      message: message,
      senderKey: senderKey,
    );
    await SenderKeyStore.saveSenderKey(
      senderKey: senderKey,
      isOwn: senderKey.isOwnKey,
    );

    return utf8.decode(plaintext);
  }

  Future<String?> buildDistributionEnvelope({
    required String groupId,
    required List<String> memberUserIds,
  }) async {
    final bundle = await ensureOwnSenderKey(groupId: groupId);
    if (bundle == null) return null;
    return buildDistributionEnvelopeForKey(
      senderKey: bundle.senderKey,
      memberUserIds: memberUserIds,
    );
  }

  Future<String?> buildDistributionEnvelopeForKey({
    required SenderKeyState senderKey,
    required List<String> memberUserIds,
  }) async {
    final distribution = SenderKeyDistribution.createDistributionMessage(
      senderKey: senderKey,
    );
    final payload = jsonEncode({
      'type': distributionType,
      'payload': distribution.toJson(),
    });

    return _e2ee.encryptBodyForUsers(
      userIds: memberUserIds,
      plaintext: payload,
      includeSelfDevices: true,
    );
  }

  Future<GroupDistributionResult?> handleDistributionMessage({
    required String body,
    required String senderUserId,
    required String senderDeviceId,
  }) async {
    if (!E2eeService.isEncrypted(body)) return null;
    final plaintext = await _e2ee.decryptBody(
      body: body,
      senderUserId: senderUserId,
      senderDeviceId: senderDeviceId,
    );
    if (plaintext == null || plaintext.isEmpty) return null;
    final decoded = _decodeDistributionPayload(plaintext);
    if (decoded == null) return null;

    final payload = decoded['payload'];
    if (payload is! Map<String, dynamic>) return null;

    final message = SenderKeyDistributionMessage.fromJson(payload);
    if (message.senderId != senderUserId ||
        message.deviceId != senderDeviceId) {
      return null;
    }

    final senderKey = SenderKeyDistribution.processDistributionMessage(
      message: message,
    );
    await SenderKeyStore.saveSenderKey(
      senderKey: senderKey,
      isOwn: false,
    );

    return GroupDistributionResult(
      groupId: message.groupId,
      senderId: message.senderId,
      deviceId: message.deviceId,
    );
  }

  String _encodeGroupEnvelope(SenderKeyMessage message) {
    final payload = {
      'v': 1,
      'message': message.toJson(),
    };
    return '$groupEnvelopePrefix${base64Encode(utf8.encode(jsonEncode(payload)))}';
  }

  Map<String, dynamic>? _decodeGroupEnvelope(String body) {
    if (!body.startsWith(groupEnvelopePrefix)) return null;
    final encoded = body.substring(groupEnvelopePrefix.length);
    try {
      final decoded = utf8.decode(base64Decode(encoded));
      final json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) return json;
    } catch (_) {}
    return null;
  }

  Map<String, dynamic>? _decodeDistributionPayload(String plaintext) {
    try {
      final json = jsonDecode(plaintext);
      if (json is! Map<String, dynamic>) return null;
      if (json['type'] != distributionType) return null;
      return json;
    } catch (_) {
      return null;
    }
  }
}

class GroupSenderKeyBundle {
  final SenderKeyState senderKey;
  final bool needsDistribution;

  const GroupSenderKeyBundle({
    required this.senderKey,
    required this.needsDistribution,
  });
}

class GroupEncryptResult {
  final String body;
  final bool needsDistribution;

  const GroupEncryptResult({
    required this.body,
    required this.needsDistribution,
  });
}

class GroupDistributionResult {
  final String groupId;
  final String senderId;
  final String deviceId;

  const GroupDistributionResult({
    required this.groupId,
    required this.senderId,
    required this.deviceId,
  });
}
