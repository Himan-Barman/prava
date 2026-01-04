// Sender key state storage
import 'dart:typed_data';

import 'package:isar/isar.dart';
import 'package:sodium_libs/sodium_libs.dart';

import '../bridge/sodium_loader.dart';
import '../entities/sender_key_entity.dart';
import '../ratchet/group/sender_key_state.dart';
import 'vault.dart';

/// ============================================================
/// Sender Key Store
/// ============================================================
/// Persists sender key state for group messaging.
/// ============================================================
final class SenderKeyStore {
  SenderKeyStore._();

  /// Get sender key by group, sender, device, and key ID
  static Future<SenderKeyState?> getSenderKey({
    required String groupId,
    required String senderId,
    required String deviceId,
    required int keyId,
  }) async {
    final entity = await Vault.read((db) async {
      return db.senderKeyEntitys
          .filter()
          .groupIdEqualTo(groupId)
          .and()
          .senderIdEqualTo(senderId)
          .and()
          .deviceIdEqualTo(deviceId)
          .and()
          .keyIdEqualTo(keyId)
          .findFirst();
    });
    if (entity == null) return null;
    return _entityToState(entity);
  }

  /// Get latest own sender key for a group
  static Future<SenderKeyState?> getLatestOwnSenderKey({
    required String groupId,
    required String senderId,
    required String deviceId,
  }) async {
    final entity = await Vault.read((db) async {
      return db.senderKeyEntitys
          .filter()
          .groupIdEqualTo(groupId)
          .and()
          .senderIdEqualTo(senderId)
          .and()
          .deviceIdEqualTo(deviceId)
          .and()
          .isOwnEqualTo(true)
          .sortByKeyIdDesc()
          .findFirst();
    });
    if (entity == null) return null;
    return _entityToState(entity);
  }

  /// Save or update sender key state
  static Future<void> saveSenderKey({
    required SenderKeyState senderKey,
    required bool isOwn,
  }) async {
    await Vault.write((db) async {
      final existing = await db.senderKeyEntitys
          .filter()
          .groupIdEqualTo(senderKey.groupId)
          .and()
          .senderIdEqualTo(senderKey.senderId)
          .and()
          .deviceIdEqualTo(senderKey.deviceId)
          .and()
          .keyIdEqualTo(senderKey.keyId)
          .findFirst();

      final entity = existing ?? SenderKeyEntity();
      entity.groupId = senderKey.groupId;
      entity.senderId = senderKey.senderId;
      entity.deviceId = senderKey.deviceId;
      entity.keyId = senderKey.keyId;
      entity.chainKey = senderKey.chainKey.toList();
      entity.signaturePublicKey = senderKey.signaturePublicKey.toList();
      if (isOwn && senderKey.signaturePrivateKey != null) {
        entity.signaturePrivateKey =
            senderKey.signaturePrivateKey!.extractBytes().toList();
      } else {
        entity.signaturePrivateKey = null;
      }
      entity.messageIndex = senderKey.messageIndex;
      entity.isOwn = isOwn;
      entity.createdAt = existing?.createdAt ?? senderKey.createdAt;
      entity.lastUsedAt = DateTime.now().millisecondsSinceEpoch;

      await db.senderKeyEntitys.put(entity);
    });
  }

  /// Delete sender keys for a group
  static Future<void> deleteGroupKeys(String groupId) async {
    await Vault.write((db) async {
      await db.senderKeyEntitys
          .filter()
          .groupIdEqualTo(groupId)
          .deleteAll();
    });
  }

  static Future<SenderKeyState> _entityToState(
    SenderKeyEntity entity,
  ) async {
    SecureKey? privateKey;
    final storedPrivate = entity.signaturePrivateKey;
    if (storedPrivate != null && storedPrivate.isNotEmpty) {
      final sodium = await SodiumLoader.sodium;
      privateKey = sodium.secureCopy(Uint8List.fromList(storedPrivate));
    }
    return SenderKeyState.fromStorage(
      groupId: entity.groupId,
      senderId: entity.senderId,
      deviceId: entity.deviceId,
      keyId: entity.keyId,
      chainKey: Uint8List.fromList(entity.chainKey),
      signaturePublicKey: Uint8List.fromList(entity.signaturePublicKey),
      signaturePrivateKey: privateKey,
      messageIndex: entity.messageIndex,
      createdAt: entity.createdAt,
    );
  }
}
