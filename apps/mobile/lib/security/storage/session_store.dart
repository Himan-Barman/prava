// Session state storage
import 'dart:convert';
import 'dart:typed_data';

import 'package:isar/isar.dart';

import '../entities/session_entity.dart';
import '../ratchet/double_ratchet.dart';
import 'vault.dart';

/// ============================================================
/// Session Store
/// ============================================================
/// Manages Double Ratchet session persistence:
///
/// • Active sessions
/// • Session state serialization
/// • Multi-device session management
/// ============================================================
final class SessionStore {
  SessionStore._();

  /// Create session ID from participants
  static String makeSessionId(
    String myOdid,
    String theirOdid,
    String theirDeviceId,
  ) {
    return '$myOdid: $theirOdid:$theirDeviceId';
  }

  // ─────────────────────────────────────────────────────────
  // Session CRUD
  // ─────────────────────────────────────────────────────────

  /// Get session by ID
  static Future<SessionEntity? > getSession(String sessionId) async {
    return Vault.read((db) async {
      return db.sessionEntitys
          .filter()
          .sessionIdEqualTo(sessionId)
          .findFirst();
    });
  }

  /// Get session for a contact
  static Future<SessionEntity?> getSessionForContact(
    String myOdid,
    String theirOdid,
    String theirDeviceId,
  ) async {
    final sessionId = makeSessionId(myOdid, theirOdid, theirDeviceId);
    return getSession(sessionId);
  }

  /// Get all sessions for a contact (all devices)
  static Future<List<SessionEntity>> getSessionsForContact(
    String theirOdid,
  ) async {
    return Vault.read((db) async {
      return db.sessionEntitys
          .filter()
          .remoteOdidEqualTo(theirOdid)
          .findAll();
    });
  }

  /// Save session state
  static Future<void> saveSession({
    required String sessionId,
    required String myOdid,
    required String remoteOdid,
    required String remoteDeviceId,
    required RatchetSessionState state,
    required Uint8List myRatchetPrivateKey,
  }) async {
    final entity = SessionEntity()
      ..sessionId = sessionId
      .. myOdid = myOdid
      ..remoteOdid = remoteOdid
      ..remoteDeviceId = remoteDeviceId
      .. rootKey = state.rootKey. toList()
      ..sendingChainKey = state. sendingChainKey != null
          ? jsonEncode(state. sendingChainKey)
          : null
      ..receivingChainKey = state. receivingChainKey != null
          ?  jsonEncode(state.receivingChainKey)
          : null
      ..myRatchetPrivateKey = myRatchetPrivateKey. toList()
      ..myRatchetPublicKey = state.myRatchetPublicKey?. toList()
      ..theirRatchetPublicKey = state. theirRatchetPublicKey?.toList()
      ..sendingChainLength = state.sendingChainLength
      ..receivingChainLength = state.receivingChainLength
      ..previousSendingChainLength = state.previousSendingChainLength
      ..skippedKeys = jsonEncode(state. skippedKeys)
      ..createdAt = DateTime. now().millisecondsSinceEpoch
      ..lastMessageAt = DateTime.now().millisecondsSinceEpoch
      ..status = SessionStatus.active;

    await Vault. write((db) async {
      await db.sessionEntitys. put(entity);
    });
  }

  /// Update session after message
  static Future<void> updateSession({
    required String sessionId,
    required RatchetSessionState state,
    required Uint8List myRatchetPrivateKey,
  }) async {
    await Vault.write((db) async {
      final entity = await db.sessionEntitys
          .filter()
          .sessionIdEqualTo(sessionId)
          .findFirst();

      if (entity != null) {
        entity.rootKey = state.rootKey.toList();
        entity.sendingChainKey = state.sendingChainKey != null
            ? jsonEncode(state. sendingChainKey)
            : null;
        entity. receivingChainKey = state.receivingChainKey != null
            ? jsonEncode(state.receivingChainKey)
            : null;
        entity.myRatchetPrivateKey = myRatchetPrivateKey. toList();
        entity.myRatchetPublicKey = state.myRatchetPublicKey?. toList();
        entity.theirRatchetPublicKey = state.theirRatchetPublicKey?.toList();
        entity.sendingChainLength = state.sendingChainLength;
        entity.receivingChainLength = state. receivingChainLength;
        entity. previousSendingChainLength = state. previousSendingChainLength;
        entity.skippedKeys = jsonEncode(state.skippedKeys);
        entity.lastMessageAt = DateTime. now().millisecondsSinceEpoch;

        await db.sessionEntitys.put(entity);
      }
    });
  }

  /// Check if session exists
  static Future<bool> hasSession(String sessionId) async {
    final session = await getSession(sessionId);
    return session != null;
  }

  /// Delete session
  static Future<void> deleteSession(String sessionId) async {
    await Vault. write((db) async {
      await db.sessionEntitys
          .filter()
          .sessionIdEqualTo(sessionId)
          .deleteAll();
    });
  }

  /// Delete all sessions for a contact
  static Future<void> deleteSessionsForContact(String remoteOdid) async {
    await Vault.write((db) async {
      await db.sessionEntitys
          . filter()
          .remoteOdidEqualTo(remoteOdid)
          .deleteAll();
    });
  }

  /// Get all active sessions
  static Future<List<SessionEntity>> getActiveSessions() async {
    return Vault.read((db) async {
      return db.sessionEntitys
          .filter()
          .statusEqualTo(SessionStatus.active)
          .findAll();
    });
  }

  /// Get stale sessions (no activity for X days)
  static Future<List<SessionEntity>> getStaleSessions({
    int staleDays = 30,
  }) async {
    final staleTime = DateTime.now()
        .subtract(Duration(days:  staleDays))
        .millisecondsSinceEpoch;

    return Vault. read((db) async {
      return db.sessionEntitys
          .filter()
          .lastMessageAtLessThan(staleTime)
          .findAll();
    });
  }

  /// Mark session as stale
  static Future<void> markSessionStale(String sessionId) async {
    await Vault. write((db) async {
      final entity = await db.sessionEntitys
          . filter()
          .sessionIdEqualTo(sessionId)
          .findFirst();

      if (entity != null) {
        entity.status = SessionStatus.stale;
        await db.sessionEntitys.put(entity);
      }
    });
  }

  /// Get session count
  static Future<int> getCount() async {
    return Vault.read((db) async {
      return db.sessionEntitys.count();
    });
  }

  /// Convert entity to RatchetSessionState
  static RatchetSessionState entityToState(SessionEntity entity) {
    return RatchetSessionState(
      sessionId: entity.sessionId,
      rootKey:  Uint8List.fromList(entity.rootKey),
      sendingChainKey:  entity.sendingChainKey != null
          ? jsonDecode(entity.sendingChainKey!) as Map<String, dynamic>
          : null,
      receivingChainKey: entity. receivingChainKey != null
          ?  jsonDecode(entity.receivingChainKey!) as Map<String, dynamic>
          : null,
      myRatchetPublicKey: entity.myRatchetPublicKey != null
          ?  Uint8List.fromList(entity.myRatchetPublicKey!)
          : null,
      theirRatchetPublicKey: entity. theirRatchetPublicKey != null
          ? Uint8List.fromList(entity.theirRatchetPublicKey!)
          : null,
      sendingChainLength:  entity.sendingChainLength,
      receivingChainLength: entity.receivingChainLength,
      previousSendingChainLength: entity.previousSendingChainLength,
      skippedKeys: jsonDecode(entity. skippedKeys) as Map<String, dynamic>,
    );
  }
}