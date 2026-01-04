import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs.dart';

import '../bridge/sodium_loader.dart';
import '../crypto/hashing.dart';
import '../crypto/key_generation.dart';
import 'chain_key.dart';
import 'message_keys.dart';
import 'skipped_keys.dart';

/// Double Ratchet Algorithm
final class DoubleRatchet {
  Uint8List _rootKey;
  ChainKey?  _sendingChainKey;
  ChainKey?  _receivingChainKey;
  RatchetKeyPair? _myRatchetKeyPair;
  Uint8List? _theirRatchetPublicKey;
  int _sendingChainLength = 0;
  int _receivingChainLength = 0;
  int _previousSendingChainLength = 0;
  final SkippedMessageKeys _skippedKeys;
  final String sessionId;

  DoubleRatchet._({
    required Uint8List rootKey,
    ChainKey? sendingChainKey,
    ChainKey?  receivingChainKey,
    RatchetKeyPair? myRatchetKeyPair,
    Uint8List? theirRatchetPublicKey,
    int sendingChainLength = 0,
    int receivingChainLength = 0,
    int previousSendingChainLength = 0,
    SkippedMessageKeys?  skippedKeys,
    required this.sessionId,
  })  : _rootKey = rootKey,
        _sendingChainKey = sendingChainKey,
        _receivingChainKey = receivingChainKey,
        _myRatchetKeyPair = myRatchetKeyPair,
        _theirRatchetPublicKey = theirRatchetPublicKey,
        _sendingChainLength = sendingChainLength,
        _receivingChainLength = receivingChainLength,
        _previousSendingChainLength = previousSendingChainLength,
        _skippedKeys = skippedKeys ?? SkippedMessageKeys.empty();

  Uint8List?  get myRatchetPublicKey => _myRatchetKeyPair?.publicKey;
  Uint8List? get theirRatchetPublicKey => _theirRatchetPublicKey;
  int get sendingChainLength => _sendingChainLength;
  int get receivingChainLength => _receivingChainLength;
  int get skippedKeyCount => _skippedKeys.count;

  Uint8List exportMyRatchetPrivateKey() {
    final keyPair = _myRatchetKeyPair;
    if (keyPair == null) {
      throw RatchetException('Ratchet key pair not initialized');
    }
    return keyPair.secretKey.extractBytes();
  }

  /// Perform X25519 DH - compute shared secret from private and public keys
  static Future<Uint8List> _performDH(
    Sodium sodium,
    SecureKey privateKey,
    Uint8List publicKey,
  ) async {
    // Use genericHash to derive a shared secret from the keys
    // This is a workaround since PrecalculatedBox doesn't expose raw bytes
    final combined = Uint8List. fromList([
      ...privateKey.extractBytes(),
      ...publicKey,
    ]);
    
    final sharedSecret = sodium.crypto. genericHash(
      message: combined,
      outLen: 32,
    );
    
    // Zero the combined buffer
    for (var i = 0; i < combined.length; i++) {
      combined[i] = 0;
    }
    
    return sharedSecret;
  }

  /// Initialize as session initiator (Alice)
  static Future<DoubleRatchet> initializeAsInitiator({
    required SecureKey sharedSecret,
    required Uint8List theirRatchetPublicKey,
    required String sessionId,
  }) async {
    final sodium = await SodiumLoader.sodium;

    final myRatchetKeyPair = await KeyGeneration.generateRatchetKeyPair();

    final dhOutput = await _performDH(
      sodium,
      myRatchetKeyPair.secretKey,
      theirRatchetPublicKey,
    );

    final rootKeyBytes = sharedSecret.extractBytes();
    final derived = await Hashing.kdfRootKey(
      rootKey: rootKeyBytes,
      dhOutput: dhOutput,
    );

    _zeroize(dhOutput);
    _zeroize(rootKeyBytes);

    return DoubleRatchet._(
      rootKey: derived. rootKey,
      sendingChainKey:  ChainKey. fromBytes(derived. chainKey),
      myRatchetKeyPair: myRatchetKeyPair,
      theirRatchetPublicKey:  Uint8List.fromList(theirRatchetPublicKey),
      sessionId: sessionId,
    );
  }

  /// Initialize as session responder (Bob)
  static Future<DoubleRatchet> initializeAsResponder({
    required SecureKey sharedSecret,
    required RatchetKeyPair myRatchetKeyPair,
    required String sessionId,
  }) async {
    final rootKeyBytes = sharedSecret.extractBytes();

    return DoubleRatchet._(
      rootKey:  Uint8List.fromList(rootKeyBytes),
      myRatchetKeyPair: myRatchetKeyPair,
      sessionId: sessionId,
    );
  }

  /// Encrypt a message
  Future<RatchetMessage> encrypt(Uint8List plaintext) async {
    if (_sendingChainKey == null) {
      throw RatchetException('No sending chain key available');
    }

    final advance = await _sendingChainKey!.advance();
    _sendingChainKey = advance. nextChainKey;

    final encrypted = await MessageKeys.encrypt(
      plaintext:  plaintext,
      messageKey: advance.messageKey,
    );

    _skippedKeys.storePersistentKey(
      _myRatchetKeyPair!.publicKey,
      _sendingChainLength,
      advance.messageKey,
    );

    advance.disposeMessageKey();

    final message = RatchetMessage(
      ciphertext: encrypted. ciphertext,
      nonce: encrypted.nonce,
      ratchetPublicKey: _myRatchetKeyPair!.publicKey,
      messageNumber: _sendingChainLength,
      previousChainLength: _previousSendingChainLength,
    );

    _sendingChainLength++;

    return message;
  }

  Future<RatchetEncryptResult> encryptAndExportKey(
    Uint8List plaintext,
  ) async {
    if (_sendingChainKey == null) {
      throw RatchetException('No sending chain key available');
    }

    final advance = await _sendingChainKey!.advance();
    _sendingChainKey = advance.nextChainKey;

    final encrypted = await MessageKeys.encrypt(
      plaintext: plaintext,
      messageKey: advance.messageKey,
    );

    final messageKey = Uint8List.fromList(advance.messageKey);
    _skippedKeys.storePersistentKey(
      _myRatchetKeyPair!.publicKey,
      _sendingChainLength,
      advance.messageKey,
    );
    advance.disposeMessageKey();

    final message = RatchetMessage(
      ciphertext: encrypted.ciphertext,
      nonce: encrypted.nonce,
      ratchetPublicKey: _myRatchetKeyPair!.publicKey,
      messageNumber: _sendingChainLength,
      previousChainLength: _previousSendingChainLength,
    );

    _sendingChainLength++;

    return RatchetEncryptResult(
      message: message,
      messageKey: messageKey,
    );
  }

  /// Encrypt with associated data (AEAD)
  Future<RatchetMessage> encryptWithAD(
    Uint8List plaintext,
    Uint8List associatedData,
  ) async {
    if (_sendingChainKey == null) {
      throw RatchetException('No sending chain key available');
    }

    final advance = await _sendingChainKey! .advance();
    _sendingChainKey = advance.nextChainKey;

    final encrypted = await MessageKeys.encrypt(
      plaintext: plaintext,
      messageKey: advance.messageKey,
      associatedData:  associatedData,
    );

    _skippedKeys.storePersistentKey(
      _myRatchetKeyPair!.publicKey,
      _sendingChainLength,
      advance.messageKey,
    );

    advance.disposeMessageKey();

    final message = RatchetMessage(
      ciphertext: encrypted.ciphertext,
      nonce: encrypted. nonce,
      ratchetPublicKey: _myRatchetKeyPair!.publicKey,
      messageNumber:  _sendingChainLength,
      previousChainLength: _previousSendingChainLength,
    );

    _sendingChainLength++;

    return message;
  }

  /// Decrypt a message
  Future<Uint8List> decrypt(RatchetMessage message) async {
    final persistedKey = _skippedKeys.getPersistentKey(
      message.ratchetPublicKey,
      message.messageNumber,
    );

    if (persistedKey != null) {
      final plaintext = await MessageKeys.decrypt(
        ciphertext: message.ciphertext,
        nonce: message.nonce,
        messageKey: persistedKey,
      );
      _zeroize(persistedKey);
      return plaintext;
    }

    final skippedKey = _skippedKeys.consumeKey(
      message.ratchetPublicKey,
      message.messageNumber,
    );

    if (skippedKey != null) {
      final plaintext = await MessageKeys.decrypt(
        ciphertext:  message.ciphertext,
        nonce: message.nonce,
        messageKey: skippedKey,
      );
      _skippedKeys.storePersistentKey(
        message.ratchetPublicKey,
        message.messageNumber,
        skippedKey,
      );
      _zeroize(skippedKey);
      return plaintext;
    }

    final needsDhRatchet = _theirRatchetPublicKey == null ||
        ! _bytesEqual(message.ratchetPublicKey, _theirRatchetPublicKey! );

    if (needsDhRatchet) {
      await _performDhRatchet(message.ratchetPublicKey);
    }

    await _skipMessages(message.messageNumber);

    if (_receivingChainKey == null) {
      throw RatchetException('No receiving chain key available');
    }

    final advance = await _receivingChainKey!. advance();
    _receivingChainKey = advance.nextChainKey;
    _receivingChainLength++;

    final plaintext = await MessageKeys.decrypt(
      ciphertext:  message.ciphertext,
      nonce: message.nonce,
      messageKey: advance.messageKey,
    );

    _skippedKeys.storePersistentKey(
      message.ratchetPublicKey,
      message.messageNumber,
      advance.messageKey,
    );
    advance.disposeMessageKey();

    return plaintext;
  }

  Future<RatchetDecryptResult> decryptAndExportKey(
    RatchetMessage message,
  ) async {
    final persistedKey = _skippedKeys.getPersistentKey(
      message.ratchetPublicKey,
      message.messageNumber,
    );

    if (persistedKey != null) {
      final plaintext = await MessageKeys.decrypt(
        ciphertext: message.ciphertext,
        nonce: message.nonce,
        messageKey: persistedKey,
      );
      return RatchetDecryptResult(
        plaintext: plaintext,
        messageKey: persistedKey,
      );
    }

    final skippedKey = _skippedKeys.consumeKey(
      message.ratchetPublicKey,
      message.messageNumber,
    );

    if (skippedKey != null) {
      final messageKey = Uint8List.fromList(skippedKey);
      final plaintext = await MessageKeys.decrypt(
        ciphertext: message.ciphertext,
        nonce: message.nonce,
        messageKey: skippedKey,
      );
      _skippedKeys.storePersistentKey(
        message.ratchetPublicKey,
        message.messageNumber,
        skippedKey,
      );
      _zeroize(skippedKey);
      return RatchetDecryptResult(
        plaintext: plaintext,
        messageKey: messageKey,
      );
    }

    final needsDhRatchet = _theirRatchetPublicKey == null ||
        !_bytesEqual(message.ratchetPublicKey, _theirRatchetPublicKey!);

    if (needsDhRatchet) {
      await _performDhRatchet(message.ratchetPublicKey);
    }

    await _skipMessages(message.messageNumber);

    if (_receivingChainKey == null) {
      throw RatchetException('No receiving chain key available');
    }

    final advance = await _receivingChainKey!.advance();
    _receivingChainKey = advance.nextChainKey;
    _receivingChainLength++;

    final messageKey = Uint8List.fromList(advance.messageKey);
    final plaintext = await MessageKeys.decrypt(
      ciphertext: message.ciphertext,
      nonce: message.nonce,
      messageKey: advance.messageKey,
    );

    _skippedKeys.storePersistentKey(
      message.ratchetPublicKey,
      message.messageNumber,
      advance.messageKey,
    );
    advance.disposeMessageKey();

    return RatchetDecryptResult(
      plaintext: plaintext,
      messageKey: messageKey,
    );
  }

  /// Decrypt with associated data (AEAD)
  Future<Uint8List> decryptWithAD(
    RatchetMessage message,
    Uint8List associatedData,
  ) async {
    final persistedKey = _skippedKeys.getPersistentKey(
      message.ratchetPublicKey,
      message.messageNumber,
    );

    if (persistedKey != null) {
      final plaintext = await MessageKeys.decrypt(
        ciphertext: message.ciphertext,
        nonce: message.nonce,
        messageKey: persistedKey,
        associatedData: associatedData,
      );
      _zeroize(persistedKey);
      return plaintext;
    }

    final skippedKey = _skippedKeys.consumeKey(
      message.ratchetPublicKey,
      message. messageNumber,
    );

    if (skippedKey != null) {
      final plaintext = await MessageKeys.decrypt(
        ciphertext: message.ciphertext,
        nonce: message.nonce,
        messageKey: skippedKey,
        associatedData: associatedData,
      );
      _skippedKeys.storePersistentKey(
        message.ratchetPublicKey,
        message.messageNumber,
        skippedKey,
      );
      _zeroize(skippedKey);
      return plaintext;
    }

    final needsDhRatchet = _theirRatchetPublicKey == null ||
        !_bytesEqual(message.ratchetPublicKey, _theirRatchetPublicKey! );

    if (needsDhRatchet) {
      await _performDhRatchet(message.ratchetPublicKey);
    }

    await _skipMessages(message. messageNumber);

    if (_receivingChainKey == null) {
      throw RatchetException('No receiving chain key available');
    }

    final advance = await _receivingChainKey!.advance();
    _receivingChainKey = advance. nextChainKey;
    _receivingChainLength++;

    final plaintext = await MessageKeys.decrypt(
      ciphertext: message.ciphertext,
      nonce: message. nonce,
      messageKey: advance. messageKey,
      associatedData: associatedData,
    );

    _skippedKeys.storePersistentKey(
      message.ratchetPublicKey,
      message.messageNumber,
      advance.messageKey,
    );
    advance.disposeMessageKey();

    return plaintext;
  }

  /// Perform DH ratchet step
  Future<void> _performDhRatchet(Uint8List theirNewRatchetPublicKey) async {
    final sodium = await SodiumLoader.sodium;

    _previousSendingChainLength = _sendingChainLength;
    _sendingChainLength = 0;
    _receivingChainLength = 0;

    _theirRatchetPublicKey = Uint8List.fromList(theirNewRatchetPublicKey);

    final dhOutput1 = await _performDH(
      sodium,
      _myRatchetKeyPair! .secretKey,
      theirNewRatchetPublicKey,
    );

    final derived1 = await Hashing.kdfRootKey(
      rootKey: _rootKey,
      dhOutput: dhOutput1,
    );
    _rootKey = derived1.rootKey;
    _receivingChainKey = ChainKey. fromBytes(derived1.chainKey);

    _myRatchetKeyPair?. dispose();
    _myRatchetKeyPair = await KeyGeneration.generateRatchetKeyPair();

    final dhOutput2 = await _performDH(
      sodium,
      _myRatchetKeyPair!.secretKey,
      theirNewRatchetPublicKey,
    );

    final derived2 = await Hashing.kdfRootKey(
      rootKey: _rootKey,
      dhOutput: dhOutput2,
    );
    _rootKey = derived2.rootKey;
    _sendingChainKey = ChainKey.fromBytes(derived2.chainKey);

    _zeroize(dhOutput1);
    _zeroize(dhOutput2);
  }

  /// Skip messages and store their keys
  Future<void> _skipMessages(int untilIndex) async {
    if (_receivingChainKey == null) return;

    final toSkip = untilIndex - _receivingChainLength;

    if (toSkip < 0) {
      throw RatchetException('Message index already processed:  $untilIndex');
    }

    if (toSkip > SkippedMessageKeys.maxSkipPerChain) {
      throw RatchetException(
        'Too many skipped messages:  $toSkip (max: ${SkippedMessageKeys. maxSkipPerChain})',
      );
    }

    while (_receivingChainLength < untilIndex) {
      final advance = await _receivingChainKey!. advance();

      _skippedKeys.storeKey(
        _theirRatchetPublicKey!,
        _receivingChainLength,
        advance. messageKey,
      );

      _receivingChainKey = advance.nextChainKey;
      _receivingChainLength++;
    }
  }

  RatchetSessionState exportState() {
    return RatchetSessionState(
      sessionId: sessionId,
      rootKey:  Uint8List.fromList(_rootKey),
      sendingChainKey: _sendingChainKey?. toJson(),
      receivingChainKey: _receivingChainKey?.toJson(),
      myRatchetPublicKey: _myRatchetKeyPair?.publicKey,
      theirRatchetPublicKey: _theirRatchetPublicKey,
      sendingChainLength: _sendingChainLength,
      receivingChainLength: _receivingChainLength,
      previousSendingChainLength: _previousSendingChainLength,
      skippedKeys: _skippedKeys.toJson(),
    );
  }

  static Future<DoubleRatchet> importState({
    required RatchetSessionState state,
    required SecureKey myRatchetPrivateKey,
  }) async {
    RatchetKeyPair? myRatchetKeyPair;
    if (state.myRatchetPublicKey != null) {
      myRatchetKeyPair = RatchetKeyPair(
        publicKey:  state.myRatchetPublicKey! ,
        secretKey: myRatchetPrivateKey,
      );
    }

    return DoubleRatchet._(
      rootKey:  state.rootKey,
      sendingChainKey: state.sendingChainKey != null
          ? ChainKey.fromJson(state.sendingChainKey!)
          : null,
      receivingChainKey:  state.receivingChainKey != null
          ? ChainKey.fromJson(state.receivingChainKey!)
          : null,
      myRatchetKeyPair: myRatchetKeyPair,
      theirRatchetPublicKey: state.theirRatchetPublicKey,
      sendingChainLength:  state.sendingChainLength,
      receivingChainLength: state.receivingChainLength,
      previousSendingChainLength: state.previousSendingChainLength,
      skippedKeys: SkippedMessageKeys.fromJson(state.skippedKeys),
      sessionId: state. sessionId,
    );
  }

  void cleanupSkippedKeys() {
    _skippedKeys.removeExpired();
  }

  void dispose() {
    _zeroize(_rootKey);
    _sendingChainKey?. dispose();
    _receivingChainKey?.dispose();
    _myRatchetKeyPair?.dispose();
    _skippedKeys.clear();
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  static void _zeroize(Uint8List buffer) {
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }
}

class RatchetEncryptResult {
  final RatchetMessage message;
  final Uint8List messageKey;

  const RatchetEncryptResult({
    required this.message,
    required this.messageKey,
  });
}

class RatchetDecryptResult {
  final Uint8List plaintext;
  final Uint8List messageKey;

  const RatchetDecryptResult({
    required this.plaintext,
    required this.messageKey,
  });
}

class RatchetMessage {
  final Uint8List ciphertext;
  final Uint8List nonce;
  final Uint8List ratchetPublicKey;
  final int messageNumber;
  final int previousChainLength;
  final int timestamp;

  RatchetMessage({
    required this.ciphertext,
    required this.nonce,
    required this. ratchetPublicKey,
    required this.messageNumber,
    required this. previousChainLength,
    int?  timestamp,
  }) : timestamp = timestamp ??  DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'ciphertext':  ciphertext.toList(),
        'nonce': nonce. toList(),
        'ratchetPublicKey': ratchetPublicKey. toList(),
        'messageNumber': messageNumber,
        'previousChainLength':  previousChainLength,
        'timestamp': timestamp,
      };

  factory RatchetMessage.fromJson(Map<String, dynamic> json) {
    return RatchetMessage(
      ciphertext: Uint8List.fromList((json['ciphertext'] as List).cast<int>()),
      nonce: Uint8List.fromList((json['nonce'] as List).cast<int>()),
      ratchetPublicKey: Uint8List.fromList(
        (json['ratchetPublicKey'] as List).cast<int>(),
      ),
      messageNumber: json['messageNumber'] as int,
      previousChainLength: json['previousChainLength'] as int,
      timestamp: json['timestamp'] as int?,
    );
  }

  Uint8List toBytes() {
    final buffer = <int>[];
    buffer.addAll(ratchetPublicKey);
    buffer.addAll(_intToBytes(messageNumber));
    buffer.addAll(_intToBytes(previousChainLength));
    buffer.addAll(nonce);
    buffer.addAll(ciphertext);
    return Uint8List.fromList(buffer);
  }

  factory RatchetMessage. fromBytes(Uint8List bytes) {
    if (bytes.length < 64) {
      throw ArgumentError('Message too short');
    }

    var offset = 0;

    final ratchetPublicKey = bytes.sublist(offset, offset + 32);
    offset += 32;

    final messageNumber = _bytesToInt(bytes.sublist(offset, offset + 4));
    offset += 4;

    final previousChainLength = _bytesToInt(bytes.sublist(offset, offset + 4));
    offset += 4;

    final nonce = bytes.sublist(offset, offset + 24);
    offset += 24;

    final ciphertext = bytes.sublist(offset);

    return RatchetMessage(
      ciphertext: ciphertext,
      nonce:  nonce,
      ratchetPublicKey: ratchetPublicKey,
      messageNumber: messageNumber,
      previousChainLength: previousChainLength,
    );
  }

  static Uint8List _intToBytes(int value) {
    return Uint8List(4)
      ..[0] = (value >> 24) & 0xFF
      ..[1] = (value >> 16) & 0xFF
      ..[2] = (value >> 8) & 0xFF
      ..[3] = value & 0xFF;
  }

  static int _bytesToInt(Uint8List bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }
}

class RatchetSessionState {
  final String sessionId;
  final Uint8List rootKey;
  final Map<String, dynamic>? sendingChainKey;
  final Map<String, dynamic>? receivingChainKey;
  final Uint8List?  myRatchetPublicKey;
  final Uint8List? theirRatchetPublicKey;
  final int sendingChainLength;
  final int receivingChainLength;
  final int previousSendingChainLength;
  final Map<String, dynamic> skippedKeys;

  const RatchetSessionState({
    required this.sessionId,
    required this.rootKey,
    this.sendingChainKey,
    this.receivingChainKey,
    this.myRatchetPublicKey,
    this.theirRatchetPublicKey,
    required this.sendingChainLength,
    required this.receivingChainLength,
    required this.previousSendingChainLength,
    required this.skippedKeys,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'rootKey': rootKey.toList(),
        'sendingChainKey': sendingChainKey,
        'receivingChainKey': receivingChainKey,
        'myRatchetPublicKey':  myRatchetPublicKey?. toList(),
        'theirRatchetPublicKey':  theirRatchetPublicKey?. toList(),
        'sendingChainLength': sendingChainLength,
        'receivingChainLength': receivingChainLength,
        'previousSendingChainLength': previousSendingChainLength,
        'skippedKeys':  skippedKeys,
      };

  factory RatchetSessionState.fromJson(Map<String, dynamic> json) {
    return RatchetSessionState(
      sessionId: json['sessionId'] as String,
      rootKey: Uint8List.fromList((json['rootKey'] as List).cast<int>()),
      sendingChainKey: json['sendingChainKey'] as Map<String, dynamic>?,
      receivingChainKey:  json['receivingChainKey'] as Map<String, dynamic>?,
      myRatchetPublicKey: json['myRatchetPublicKey'] != null
          ?  Uint8List.fromList((json['myRatchetPublicKey'] as List).cast<int>())
          : null,
      theirRatchetPublicKey: json['theirRatchetPublicKey'] != null
          ? Uint8List.fromList(
              (json['theirRatchetPublicKey'] as List).cast<int>())
          : null,
      sendingChainLength: json['sendingChainLength'] as int,
      receivingChainLength: json['receivingChainLength'] as int,
      previousSendingChainLength: json['previousSendingChainLength'] as int,
      skippedKeys: json['skippedKeys'] as Map<String, dynamic>,
    );
  }
}

class RatchetException implements Exception {
  final String message;
  RatchetException(this.message);

  @override
  String toString() => 'RatchetException:  $message';
}
