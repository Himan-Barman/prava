// Sender key distribution
import 'dart:typed_data';

import 'sender_key_state.dart';

/// ============================================================
/// Sender Key Distribution
/// ============================================================
/// Handles distribution of sender keys to group members:
///
/// Distribution Flow:
/// 1. User creates sender key for group
/// 2. Creates distribution message
/// 3. Sends distribution message to each member via pairwise E2EE
/// 4. Members process and store received keys
///
/// When to Distribute:
/// • Joining a group
/// • Creating a group
/// • After key rotation
/// • When new member joins (to them only)
/// ============================================================
final class SenderKeyDistribution {
  SenderKeyDistribution._();

  /// Create distribution message from sender key
  static SenderKeyDistributionMessage createDistributionMessage({
    required SenderKeyState senderKey,
  }) {
    if (!senderKey. isOwnKey) {
      throw ArgumentError('Can only distribute own sender key');
    }

    return SenderKeyDistributionMessage(
      groupId: senderKey.groupId,
      senderId:  senderKey.senderId,
      deviceId: senderKey.deviceId,
      keyId: senderKey.keyId,
      chainKey: senderKey.chainKey,
      signaturePublicKey: senderKey.signaturePublicKey,
      messageIndex: senderKey.messageIndex,
    );
  }

  /// Process received distribution message
  static SenderKeyState processDistributionMessage({
    required SenderKeyDistributionMessage message,
  }) {
    return SenderKeyState. fromDistribution(
      groupId: message.groupId,
      senderId: message.senderId,
      deviceId: message.deviceId,
      keyId: message.keyId,
      chainKey: message.chainKey,
      signaturePublicKey: message.signaturePublicKey,
      messageIndex:  message.messageIndex,
    );
  }

  /// Check if we have sender key for a member
  static bool hasSenderKey(
    Map<String, SenderKeyState> senderKeys,
    String senderId,
    String deviceId,
  ) {
    final key = '$senderId: $deviceId';
    return senderKeys.containsKey(key);
  }

  /// Get sender key for a member
  static SenderKeyState?  getSenderKey(
    Map<String, SenderKeyState> senderKeys,
    String senderId,
    String deviceId,
  ) {
    final key = '$senderId:$deviceId';
    return senderKeys[key];
  }

  /// Store sender key
  static void storeSenderKey(
    Map<String, SenderKeyState> senderKeys,
    SenderKeyState senderKey,
  ) {
    final key = '${senderKey. senderId}:${senderKey.deviceId}';
    senderKeys[key] = senderKey;
  }

  /// Remove sender key (e.g., when member leaves)
  static SenderKeyState? removeSenderKey(
    Map<String, SenderKeyState> senderKeys,
    String senderId,
    String deviceId,
  ) {
    final key = '$senderId:$deviceId';
    return senderKeys. remove(key);
  }

  /// Get all sender keys for a group
  static List<SenderKeyState> getAllSenderKeys(
    Map<String, SenderKeyState> senderKeys,
    String groupId,
  ) {
    return senderKeys.values
        .where((sk) => sk.groupId == groupId)
        .toList();
  }

  /// Clear all sender keys for a group
  static void clearGroupSenderKeys(
    Map<String, SenderKeyState> senderKeys,
    String groupId,
  ) {
    final keysToRemove = senderKeys.entries
        .where((e) => e.value.groupId == groupId)
        .map((e) => e.key)
        .toList();

    for (final key in keysToRemove) {
      senderKeys[key]?.dispose();
      senderKeys.remove(key);
    }
  }
}

/// Sender key distribution message
class SenderKeyDistributionMessage {
  /// Group identifier
  final String groupId;

  /// Sender user ID
  final String senderId;

  /// Sender device ID
  final String deviceId;

  /// Key generation ID
  final int keyId;

  /// Initial chain key
  final Uint8List chainKey;

  /// Signature public key
  final Uint8List signaturePublicKey;

  /// Current message index
  final int messageIndex;

  /// Timestamp
  final int timestamp;

  SenderKeyDistributionMessage({
    required this.groupId,
    required this.senderId,
    required this.deviceId,
    required this. keyId,
    required this.chainKey,
    required this.signaturePublicKey,
    required this.messageIndex,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  /// Serialize for transmission
  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'senderId': senderId,
        'deviceId': deviceId,
        'keyId': keyId,
        'chainKey':  chainKey.toList(),
        'signaturePublicKey':  signaturePublicKey.toList(),
        'messageIndex':  messageIndex,
        'timestamp': timestamp,
      };

  /// Deserialize from transmission
  factory SenderKeyDistributionMessage.fromJson(Map<String, dynamic> json) {
    return SenderKeyDistributionMessage(
      groupId:  json['groupId'] as String,
      senderId: json['senderId'] as String,
      deviceId: json['deviceId'] as String,
      keyId: json['keyId'] as int,
      chainKey: Uint8List.fromList((json['chainKey'] as List).cast<int>()),
      signaturePublicKey: Uint8List.fromList(
        (json['signaturePublicKey'] as List).cast<int>(),
      ),
      messageIndex: json['messageIndex'] as int,
      timestamp: json['timestamp'] as int?,
    );
  }

  /// Serialize to bytes for E2EE transmission
  Uint8List toBytes() {
    final json = toJson();
    final jsonString = json.toString();
    return Uint8List.fromList(jsonString.codeUnits);
  }
}