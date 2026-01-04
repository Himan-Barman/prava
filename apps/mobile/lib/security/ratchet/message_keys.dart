import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs.dart';

import '../bridge/sodium_loader.dart';
import '../crypto/random_generator.dart';

/// Message Key Management - XSalsa20-Poly1305 AEAD
final class MessageKeys {
  MessageKeys._();

  static const int nonceSize = 24;
  static const int tagSize = 16;
  static const int keySize = 32;

  /// Encrypt message with message key
  static Future<EncryptedMessage> encrypt({
    required Uint8List plaintext,
    required Uint8List messageKey,
    Uint8List? associatedData,
  }) async {
    if (messageKey.length != keySize) {
      throw ArgumentError('Message key must be $keySize bytes');
    }

    final sodium = await SodiumLoader.sodium;

    // Generate random nonce
    final nonce = await RandomGenerator.nonce(length: nonceSize);

    // Convert message key to SecureKey
    final key = sodium.secureCopy(messageKey);

    try {
      // Encrypt with secretBox (XSalsa20-Poly1305)
      final ciphertext = sodium. crypto.secretBox. easy(
        message: plaintext,
        nonce: nonce,
        key: key,
      );

      return EncryptedMessage(
        ciphertext: ciphertext,
        nonce: nonce,
      );
    } finally {
      key.dispose();
    }
  }

  /// Encrypt message synchronously
  static EncryptedMessage encryptSync({
    required Uint8List plaintext,
    required Uint8List messageKey,
    Uint8List?  associatedData,
  }) {
    if (messageKey. length != keySize) {
      throw ArgumentError('Message key must be $keySize bytes');
    }

    final sodium = SodiumLoader.sodiumSync;

    // Generate random nonce
    final nonce = sodium.randombytes. buf(nonceSize);

    // Convert message key to SecureKey
    final key = sodium.secureCopy(messageKey);

    try {
      final ciphertext = sodium.crypto.secretBox.easy(
        message: plaintext,
        nonce:  nonce,
        key: key,
      );

      return EncryptedMessage(
        ciphertext: ciphertext,
        nonce: nonce,
      );
    } finally {
      key.dispose();
    }
  }

  /// Decrypt message with message key
  static Future<Uint8List> decrypt({
    required Uint8List ciphertext,
    required Uint8List nonce,
    required Uint8List messageKey,
    Uint8List? associatedData,
  }) async {
    if (messageKey. length != keySize) {
      throw ArgumentError('Message key must be $keySize bytes');
    }
    if (nonce.length != nonceSize) {
      throw ArgumentError('Nonce must be $nonceSize bytes');
    }

    final sodium = await SodiumLoader.sodium;

    // Convert message key to SecureKey
    final key = sodium.secureCopy(messageKey);

    try {
      return sodium.crypto.secretBox.openEasy(
        cipherText: ciphertext,
        nonce: nonce,
        key: key,
      );
    } finally {
      key.dispose();
    }
  }

  /// Decrypt message synchronously
  static Uint8List decryptSync({
    required Uint8List ciphertext,
    required Uint8List nonce,
    required Uint8List messageKey,
    Uint8List? associatedData,
  }) {
    if (messageKey.length != keySize) {
      throw ArgumentError('Message key must be $keySize bytes');
    }
    if (nonce.length != nonceSize) {
      throw ArgumentError('Nonce must be $nonceSize bytes');
    }

    final sodium = SodiumLoader. sodiumSync;

    // Convert message key to SecureKey
    final key = sodium.secureCopy(messageKey);

    try {
      return sodium.crypto.secretBox.openEasy(
        cipherText: ciphertext,
        nonce: nonce,
        key: key,
      );
    } finally {
      key.dispose();
    }
  }

  /// Derive encryption key and IV from message key
  static Future<DerivedMessageKey> deriveKeyAndIV(Uint8List messageKey) async {
    final sodium = await SodiumLoader.sodium;

    final derived = sodium.crypto. genericHash(
      message: messageKey,
      outLen: 56,
    );

    return DerivedMessageKey(
      encryptionKey: derived.sublist(0, 32),
      iv: derived.sublist(32, 56),
    );
  }
}

class EncryptedMessage {
  final Uint8List ciphertext;
  final Uint8List nonce;

  const EncryptedMessage({
    required this.ciphertext,
    required this. nonce,
  });

  Uint8List get combined => Uint8List.fromList([... nonce, ...ciphertext]);

  factory EncryptedMessage.fromCombined(Uint8List combined) {
    if (combined.length <= MessageKeys.nonceSize) {
      throw ArgumentError('Combined ciphertext too short');
    }

    return EncryptedMessage(
      nonce: combined.sublist(0, MessageKeys.nonceSize),
      ciphertext: combined.sublist(MessageKeys. nonceSize),
    );
  }

  Map<String, dynamic> toJson() => {
        'ciphertext':  ciphertext. toList(),
        'nonce': nonce. toList(),
      };

  factory EncryptedMessage.fromJson(Map<String, dynamic> json) {
    return EncryptedMessage(
      ciphertext: Uint8List.fromList((json['ciphertext'] as List).cast<int>()),
      nonce: Uint8List.fromList((json['nonce'] as List).cast<int>()),
    );
  }
}

class DerivedMessageKey {
  final Uint8List encryptionKey;
  final Uint8List iv;

  const DerivedMessageKey({
    required this. encryptionKey,
    required this. iv,
  });

  void dispose() {
    for (var i = 0; i < encryptionKey. length; i++) {
      encryptionKey[i] = 0;
    }
    for (var i = 0; i < iv. length; i++) {
      iv[i] = 0;
    }
  }
}