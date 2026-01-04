// Identity key storage
import 'dart:typed_data';

import 'package:isar/isar.dart';

import '../entities/identity_entity.dart';
import 'vault.dart';

/// ============================================================
/// Identity Store
/// ============================================================
/// Manages identity key persistence: 
///
/// • Local identity (our key pair)
/// • Remote identities (contacts' public keys)
/// • Trust state management
/// ============================================================
final class IdentityStore {
  IdentityStore._();

  // ─────────────────────────────────────────────────────────
  // Local Identity
  // ─────────────────────────────────────────────────────────

  /// Get local identity
  static Future<IdentityEntity?> getLocalIdentity() async {
    return Vault.read((db) async {
      return db.identityEntitys
          .filter()
          .isLocalEqualTo(true)
          .findFirst();
    });
  }

  /// Save local identity
  static Future<void> saveLocalIdentity({
    required String odid,
    required String deviceId,
    required int registrationId,
    required Uint8List publicKey,
    required Uint8List privateKey,
  }) async {
    final entity = IdentityEntity()
      ..odid = odid
      ..deviceId = deviceId
      ..registrationId = registrationId
      ..publicKey = publicKey. toList()
      ..privateKey = privateKey. toList()
      ..isLocal = true
      ..createdAt = DateTime.now().millisecondsSinceEpoch
      ..trustLevel = TrustLevel.trusted;

    await Vault.write((db) async {
      await db.identityEntitys.put(entity);
    });
  }

  /// Check if local identity exists
  static Future<bool> hasLocalIdentity() async {
    final identity = await getLocalIdentity();
    return identity != null;
  }

  /// Delete local identity (account reset)
  static Future<void> deleteLocalIdentity() async {
    await Vault.write((db) async {
      await db.identityEntitys
          .filter()
          .isLocalEqualTo(true)
          .deleteAll();
    });
  }

  // ─────────────────────────────────────────────────────────
  // Remote Identities
  // ─────────────────────────────────────────────────────────

  /// Get remote identity by user ID and device ID
  static Future<IdentityEntity?> getRemoteIdentity(
    String odid,
    String deviceId,
  ) async {
    return Vault.read((db) async {
      return db.identityEntitys
          . filter()
          .odidEqualTo(odid)
          .and()
          .deviceIdEqualTo(deviceId)
          .and()
          .isLocalEqualTo(false)
          .findFirst();
    });
  }

  /// Get all identities for a user (all devices)
  static Future<List<IdentityEntity>> getRemoteIdentitiesForUser(
    String odid,
  ) async {
    return Vault.read((db) async {
      return db. identityEntitys
          .filter()
          .odidEqualTo(odid)
          .and()
          .isLocalEqualTo(false)
          .findAll();
    });
  }

  /// Save remote identity
  static Future<IdentitySaveResult> saveRemoteIdentity({
    required String odid,
    required String deviceId,
    required int registrationId,
    required Uint8List publicKey,
  }) async {
    // Check if identity already exists
    final existing = await getRemoteIdentity(odid, deviceId);

    if (existing != null) {
      // Check if key changed
      final existingKey = Uint8List.fromList(existing.publicKey);
      final keysMatch = _bytesEqual(existingKey, publicKey);

      if (! keysMatch) {
        // Key changed - security event! 
        existing.publicKey = publicKey. toList();
        existing.trustLevel = TrustLevel.untrusted;
        existing.keyChangedAt = DateTime. now().millisecondsSinceEpoch;

        await Vault. write((db) async {
          await db.identityEntitys.put(existing);
        });

        return IdentitySaveResult.keyChanged;
      }

      return IdentitySaveResult.unchanged;
    }

    // New identity
    final entity = IdentityEntity()
      ..odid = odid
      ..deviceId = deviceId
      .. registrationId = registrationId
      .. publicKey = publicKey.toList()
      ..isLocal = false
      .. createdAt = DateTime.now().millisecondsSinceEpoch
      .. trustLevel = TrustLevel.untrusted;

    await Vault.write((db) async {
      await db.identityEntitys.put(entity);
    });

    return IdentitySaveResult.saved;
  }

  /// Update trust level
  static Future<void> updateTrustLevel(
    String odid,
    String deviceId,
    TrustLevel trustLevel,
  ) async {
    await Vault.write((db) async {
      final entity = await db.identityEntitys
          .filter()
          .odidEqualTo(odid)
          .and()
          .deviceIdEqualTo(deviceId)
          .findFirst();

      if (entity != null) {
        entity. trustLevel = trustLevel;
        entity.verifiedAt = trustLevel == TrustLevel.verified
            ? DateTime.now().millisecondsSinceEpoch
            : null;
        await db.identityEntitys.put(entity);
      }
    });
  }

  /// Delete remote identity
  static Future<void> deleteRemoteIdentity(
    String odid,
    String deviceId,
  ) async {
    await Vault.write((db) async {
      await db.identityEntitys
          .filter()
          .odidEqualTo(odid)
          .and()
          .deviceIdEqualTo(deviceId)
          .and()
          .isLocalEqualTo(false)
          .deleteAll();
    });
  }

  /// Delete all identities for a user
  static Future<void> deleteAllForUser(String odid) async {
    await Vault.write((db) async {
      await db.identityEntitys
          .filter()
          .odidEqualTo(odid)
          .and()
          .isLocalEqualTo(false)
          .deleteAll();
    });
  }

  /// Get all trusted identities
  static Future<List<IdentityEntity>> getTrustedIdentities() async {
    return Vault.read((db) async {
      return db.identityEntitys
          . filter()
          .trustLevelEqualTo(TrustLevel. trusted)
          .or()
          .trustLevelEqualTo(TrustLevel.verified)
          .findAll();
    });
  }

  /// Get count of identities
  static Future<int> getCount() async {
    return Vault.read((db) async {
      return db. identityEntitys. count();
    });
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a. length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}

/// Result of saving an identity
enum IdentitySaveResult {
  /// New identity saved
  saved,

  /// Identity unchanged (same key)
  unchanged,

  /// Identity key changed (security event)
  keyChanged,
}