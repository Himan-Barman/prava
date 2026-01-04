// Sender key state
import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs.dart';

import '../../bridge/sodium_loader.dart';

/// ============================================================
/// Sender Key State
/// ============================================================
/// State for a single sender in a group chat: 
///
/// Components:
/// • Chain Key:  Symmetric key that ratchets forward
/// • Signature Key: Ed25519 key pair for authentication
/// • Message Index: Counter for each message
///
/// Security:
/// • Forward secrecy within sender's messages
/// • Authentication via signatures
/// • Each sender has independent key material
/// ============================================================
class SenderKeyState {
  /// Group identifier
  final String groupId;

  /// Sender user ID
  final String senderId;

  /// Sender device ID
  final String deviceId;

  /// Key generation ID (for rotation)
  final int keyId;

  /// Current chain key (32 bytes)
  Uint8List _chainKey;

  /// Signature private key (for signing messages)
  final SecureKey?  signaturePrivateKey;

  /// Signature public key (for verifying messages)
  final Uint8List signaturePublicKey;

  /// Current message index
  int _messageIndex;

  /// Creation timestamp
  final int createdAt;

  SenderKeyState._({
    required this.groupId,
    required this.senderId,
    required this.deviceId,
    required this. keyId,
    required Uint8List chainKey,
    this.signaturePrivateKey,
    required this.signaturePublicKey,
    int messageIndex = 0,
    required this.createdAt,
  })  : _chainKey = chainKey,
        _messageIndex = messageIndex;

  /// Current chain key
  Uint8List get chainKey => Uint8List.fromList(_chainKey);

  /// Current message index
  int get messageIndex => _messageIndex;

  /// Check if this is our own sender key (has private key)
  bool get isOwnKey => signaturePrivateKey != null;

  /// Create new sender key state (for our own key)
  static Future<SenderKeyState> create({
    required String groupId,
    required String senderId,
    required String deviceId,
  }) async {
    final sodium = await SodiumLoader.sodium;

    // Generate chain key
    final chainKey = sodium.randombytes. buf(32);

    // Generate signature key pair
    final signatureKeyPair = sodium.crypto. sign. keyPair();

    // Generate key ID
    final keyId = sodium.randombytes.random();

    return SenderKeyState. _(
      groupId: groupId,
      senderId: senderId,
      deviceId: deviceId,
      keyId:  keyId,
      chainKey: chainKey,
      signaturePrivateKey: signatureKeyPair. secretKey,
      signaturePublicKey: signatureKeyPair.publicKey,
      createdAt: DateTime. now().millisecondsSinceEpoch,
    );
  }

  /// Create from received distribution message
  static SenderKeyState fromDistribution({
    required String groupId,
    required String senderId,
    required String deviceId,
    required int keyId,
    required Uint8List chainKey,
    required Uint8List signaturePublicKey,
    int messageIndex = 0,
  }) {
    return SenderKeyState. _(
      groupId: groupId,
      senderId: senderId,
      deviceId: deviceId,
      keyId:  keyId,
      chainKey:  Uint8List.fromList(chainKey),
      signaturePublicKey: Uint8List.fromList(signaturePublicKey),
      messageIndex: messageIndex,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Create from stored state (optionally with private key)
  static SenderKeyState fromStorage({
    required String groupId,
    required String senderId,
    required String deviceId,
    required int keyId,
    required Uint8List chainKey,
    required Uint8List signaturePublicKey,
    SecureKey? signaturePrivateKey,
    required int messageIndex,
    required int createdAt,
  }) {
    return SenderKeyState._(
      groupId: groupId,
      senderId: senderId,
      deviceId: deviceId,
      keyId: keyId,
      chainKey: Uint8List.fromList(chainKey),
      signaturePrivateKey: signaturePrivateKey,
      signaturePublicKey: Uint8List.fromList(signaturePublicKey),
      messageIndex: messageIndex,
      createdAt: createdAt,
    );
  }

  /// Advance chain key and get message key
  Future<SenderKeyAdvance> advance() async {
    final sodium = await SodiumLoader.sodium;

    // Derive message key:  HMAC(chainKey, 0x01)
    final messageKey = sodium.crypto.genericHash(
      message:  Uint8List.fromList([0x01, ..._chainKey]),
      outLen: 32,
    );

    // Advance chain key:  HMAC(chainKey, 0x02)
    final nextChainKey = sodium.crypto.genericHash(
      message: Uint8List.fromList([0x02, ..._chainKey]),
      outLen: 32,
    );

    // Update state
    _zeroize(_chainKey);
    _chainKey = nextChainKey;
    final currentIndex = _messageIndex;
    _messageIndex++;

    return SenderKeyAdvance(
      messageKey: messageKey,
      messageIndex: currentIndex,
    );
  }

  /// Advance to specific index (for receiving out-of-order)
  Future<Uint8List? > advanceToIndex(int targetIndex) async {
    if (targetIndex < _messageIndex) {
      return null; // Already processed
    }

    if (targetIndex - _messageIndex > 1000) {
      return null; // Too many to skip
    }

    final sodium = await SodiumLoader.sodium;
    var currentKey = Uint8List.fromList(_chainKey);

    // Advance until we reach target
    while (_messageIndex < targetIndex) {
      final nextKey = sodium.crypto.genericHash(
        message: Uint8List.fromList([0x02, ... currentKey]),
        outLen: 32,
      );
      _zeroize(currentKey);
      currentKey = nextKey;
      _messageIndex++;
    }

    // Derive message key at target index
    final messageKey = sodium. crypto.genericHash(
      message:  Uint8List.fromList([0x01, ...currentKey]),
      outLen:  32,
    );

    // Advance chain key one more
    final nextChainKey = sodium.crypto.genericHash(
      message: Uint8List.fromList([0x02, ...currentKey]),
      outLen: 32,
    );

    _zeroize(_chainKey);
    _chainKey = nextChainKey;
    _messageIndex++;

    _zeroize(currentKey);

    return messageKey;
  }

  /// Serialize for storage
  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'senderId': senderId,
        'deviceId': deviceId,
        'keyId': keyId,
        'chainKey':  _chainKey.toList(),
        'signaturePublicKey': signaturePublicKey.toList(),
        'messageIndex': _messageIndex,
        'createdAt':  createdAt,
      };

  /// Deserialize from storage
  factory SenderKeyState.fromJson(Map<String, dynamic> json) {
    return SenderKeyState. _(
      groupId: json['groupId'] as String,
      senderId: json['senderId'] as String,
      deviceId: json['deviceId'] as String,
      keyId:  json['keyId'] as int,
      chainKey: Uint8List.fromList((json['chainKey'] as List).cast<int>()),
      signaturePublicKey: Uint8List.fromList(
        (json['signaturePublicKey'] as List).cast<int>(),
      ),
      messageIndex: json['messageIndex'] as int,
      createdAt: json['createdAt'] as int,
    );
  }

  /// Dispose sensitive material
  void dispose() {
    _zeroize(_chainKey);
    signaturePrivateKey?. dispose();
  }

  void _zeroize(Uint8List buffer) {
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }
}

/// Result of advancing sender key
class SenderKeyAdvance {
  final Uint8List messageKey;
  final int messageIndex;

  const SenderKeyAdvance({
    required this.messageKey,
    required this.messageIndex,
  });

  void dispose() {
    for (var i = 0; i < messageKey.length; i++) {
      messageKey[i] = 0;
    }
  }
}
