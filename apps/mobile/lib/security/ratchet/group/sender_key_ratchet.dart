// Group ratchet logic
import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs.dart';

import '../../bridge/sodium_loader.dart';
import '../../crypto/random_generator.dart';
import '../../crypto/signatures.dart';
import '../message_keys.dart';
import 'sender_key_state.dart';

/// ============================================================
/// Sender Key Ratchet
/// ============================================================
/// Encryption engine for group messaging: 
///
/// Advantages over pairwise: 
/// • O(1) encryption vs O(n) for pairwise
/// • Single encryption for all recipients
/// • Efficient for large groups
///
/// Trade-offs:
/// • No per-recipient forward secrecy
/// • Requires key redistribution on member removal
/// • Members share key material
///
/// Usage:
/// 1. Create sender key when joining group
/// 2. Distribute to all members via pairwise channels
/// 3. Encrypt messages with sender key
/// 4. Rotate on member removal
/// ============================================================
final class SenderKeyRatchet {
  SenderKeyRatchet._();

  /// Encrypt message for group
  static Future<SenderKeyMessage> encrypt({
    required Uint8List plaintext,
    required SenderKeyState senderKey,
  }) async {
    if (! senderKey.isOwnKey) {
      throw SenderKeyException('Cannot encrypt with received sender key');
    }

    // Advance sender key to get message key
    final advance = await senderKey.advance();

    // Encrypt message
    final encrypted = await MessageKeys.encrypt(
      plaintext: plaintext,
      messageKey: advance.messageKey,
    );

    // Sign the ciphertext
    final signature = await Signatures.sign(
      encrypted.ciphertext,
      senderKey.signaturePrivateKey! ,
    );

    // Create message
    final message = SenderKeyMessage(
      groupId: senderKey.groupId,
      senderId: senderKey.senderId,
      deviceId: senderKey. deviceId,
      keyId: senderKey.keyId,
      messageIndex: advance.messageIndex,
      ciphertext: encrypted. ciphertext,
      nonce: encrypted.nonce,
      signature: signature,
    );

    // Dispose message key
    advance.dispose();

    return message;
  }

  /// Decrypt message from group
  static Future<Uint8List> decrypt({
    required SenderKeyMessage message,
    required SenderKeyState senderKey,
  }) async {
    // Verify sender key matches message
    if (senderKey.groupId != message.groupId ||
        senderKey.senderId != message.senderId ||
        senderKey. deviceId != message. deviceId ||
        senderKey.keyId != message.keyId) {
      throw SenderKeyException('Sender key mismatch');
    }

    // Verify signature
    final signatureValid = await Signatures.verify(
      message.ciphertext,
      message.signature,
      senderKey.signaturePublicKey,
    );

    if (!signatureValid) {
      throw SenderKeyException('Invalid message signature');
    }

    // Get message key for this index
    final messageKey = await senderKey.advanceToIndex(message. messageIndex);

    if (messageKey == null) {
      throw SenderKeyException(
        'Cannot derive message key for index ${message.messageIndex}',
      );
    }

    // Decrypt message
    final plaintext = await MessageKeys.decrypt(
      ciphertext: message.ciphertext,
      nonce: message.nonce,
      messageKey: messageKey,
    );

    // Zero message key
    for (var i = 0; i < messageKey.length; i++) {
      messageKey[i] = 0;
    }

    return plaintext;
  }

  /// Create sender key for group
  static Future<SenderKeyState> createSenderKey({
    required String groupId,
    required String senderId,
    required String deviceId,
  }) async {
    return SenderKeyState. create(
      groupId: groupId,
      senderId:  senderId,
      deviceId: deviceId,
    );
  }

  /// Check if sender key needs rotation
  static bool needsRotation(SenderKeyState senderKey, {int maxMessages = 1000}) {
    return senderKey.messageIndex >= maxMessages;
  }
}

/// Encrypted group message
class SenderKeyMessage {
  /// Group identifier
  final String groupId;

  /// Sender user ID
  final String senderId;

  /// Sender device ID
  final String deviceId;

  /// Sender key generation ID
  final int keyId;

  /// Message index in sender's chain
  final int messageIndex;

  /// Encrypted content
  final Uint8List ciphertext;

  /// Encryption nonce
  final Uint8List nonce;

  /// Ed25519 signature over ciphertext
  final Uint8List signature;

  /// Timestamp
  final int timestamp;

  SenderKeyMessage({
    required this.groupId,
    required this.senderId,
    required this.deviceId,
    required this.keyId,
    required this. messageIndex,
    required this.ciphertext,
    required this.nonce,
    required this. signature,
    int?  timestamp,
  }) : timestamp = timestamp ??  DateTime.now().millisecondsSinceEpoch;

  /// Serialize for transmission
  Map<String, dynamic> toJson() => {
        'groupId':  groupId,
        'senderId': senderId,
        'deviceId': deviceId,
        'keyId': keyId,
        'messageIndex': messageIndex,
        'ciphertext': ciphertext. toList(),
        'nonce': nonce.toList(),
        'signature':  signature.toList(),
        'timestamp':  timestamp,
      };

  /// Deserialize from transmission
  factory SenderKeyMessage.fromJson(Map<String, dynamic> json) {
    return SenderKeyMessage(
      groupId: json['groupId'] as String,
      senderId: json['senderId'] as String,
      deviceId: json['deviceId'] as String,
      keyId:  json['keyId'] as int,
      messageIndex: json['messageIndex'] as int,
      ciphertext: Uint8List.fromList((json['ciphertext'] as List).cast<int>()),
      nonce:  Uint8List.fromList((json['nonce'] as List).cast<int>()),
      signature: Uint8List.fromList((json['signature'] as List).cast<int>()),
      timestamp: json['timestamp'] as int?,
    );
  }
}

/// Sender key exception
class SenderKeyException implements Exception {
  final String message;

  SenderKeyException(this.message);

  @override
  String toString() => 'SenderKeyException: $message';
}