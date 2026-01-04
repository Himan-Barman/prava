import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs.dart';

import '../core/device/device_id.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';
import '../security/bridge/sodium_loader.dart';
import '../security/crypto/key_generation.dart';
import '../security/crypto/x3dh.dart';
import '../security/entities/prekey_entity.dart';
import '../security/ratchet/double_ratchet.dart';
import '../security/ratchet/message_keys.dart';
import '../security/ratchet/skipped_keys.dart';
import '../security/security_init.dart';
import '../security/storage/identity_store.dart';
import '../security/storage/prekey_store.dart';
import '../security/storage/session_store.dart';
import '../security/storage/signed_prekey_store.dart';

class E2eeService {
  static const String envelopePrefix = 'e2ee.v1:';

  E2eeService({SecureStore? store})
      : _store = store ?? SecureStore(),
        _deviceIdStore = DeviceIdStore(store ?? SecureStore()),
        _client = ApiClient(store ?? SecureStore());

  final SecureStore _store;
  final DeviceIdStore _deviceIdStore;
  final ApiClient _client;

  static bool isEncrypted(String body) {
    return body.startsWith(envelopePrefix);
  }

  Future<void> ensureReady() async {
    await _ensureSecurityInitialized();
    final userId = await _store.getUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('Missing user id');
    }
    final deviceId = await _deviceIdStore.getOrCreate();
    final localIdentity = await _ensureLocalIdentity(userId, deviceId);
    final xIdentity = await _ensureLocalXIdentity();
    try {
      final signedPreKey =
          await _ensureSignedPreKey(localIdentity.privateKey);
      final pendingPreKeys = await _ensurePreKeys();
      await _registerDevice(
        deviceId: deviceId,
        identityKeyEd: localIdentity.publicKey,
        identityKeyX: xIdentity.publicKey,
        registrationId: localIdentity.registrationId,
        signedPreKey: signedPreKey,
        pendingPreKeys: pendingPreKeys,
      );
    } finally {
      localIdentity.dispose();
      xIdentity.dispose();
    }
  }

  Future<bool> refreshKeysIfNeeded() async {
    await _ensureSecurityInitialized();
    final userId = await _store.getUserId();
    if (userId == null || userId.isEmpty) return false;
    final deviceId = await _deviceIdStore.getOrCreate();
    final localIdentity = await _ensureLocalIdentity(userId, deviceId);
    final xIdentity = await _ensureLocalXIdentity();
    try {
      final needsRotation = await SignedPreKeyStore.needsRotation();
      final pendingPreKeys = await PreKeyStore.getPendingUpload();
      final needsPreKeys =
          pendingPreKeys.isNotEmpty || await PreKeyStore.needsReplenishment();
      if (!needsRotation && !needsPreKeys) return false;

      final signedPreKey =
          await _ensureSignedPreKey(localIdentity.privateKey);
      final refreshedPreKeys = await _ensurePreKeys();
      await _registerDevice(
        deviceId: deviceId,
        identityKeyEd: localIdentity.publicKey,
        identityKeyX: xIdentity.publicKey,
        registrationId: localIdentity.registrationId,
        signedPreKey: signedPreKey,
        pendingPreKeys: refreshedPreKeys,
      );
      return true;
    } finally {
      localIdentity.dispose();
      xIdentity.dispose();
    }
  }

  Future<String?> encryptBody({
    required String peerUserId,
    required String plaintext,
    bool includeSelfDevices = true,
  }) async {
    return encryptBodyForUsers(
      userIds: [peerUserId],
      plaintext: plaintext,
      includeSelfDevices: includeSelfDevices,
    );
  }

  Future<String?> encryptBodyForUsers({
    required List<String> userIds,
    required String plaintext,
    bool includeSelfDevices = true,
  }) async {
    await _ensureSecurityInitialized();
    final userId = await _store.getUserId();
    if (userId == null || userId.isEmpty) return null;
    final deviceId = await _deviceIdStore.getOrCreate();
    final localIdentity = await _ensureLocalIdentity(userId, deviceId);
    final xIdentity = await _ensureLocalXIdentity();
    try {
      final targets = await _buildTargetsForUsers(
        myUserId: userId,
        myDeviceId: deviceId,
        userIds: userIds,
        includeSelfDevices: includeSelfDevices,
      );
      if (targets.isEmpty) return null;

      final recipients = <Map<String, dynamic>>[];
      for (final target in targets) {
        final encrypted = await _encryptForDevice(
          myUserId: userId,
          myDeviceId: deviceId,
          myRegistrationId: localIdentity.registrationId,
          myIdentityKeyEd: localIdentity.publicKey,
          myIdentityKeyX: xIdentity.publicKey,
          myIdentityPrivateKeyX: xIdentity.privateKey,
          target: target,
          plaintext: plaintext,
        );
        if (encrypted != null) {
          recipients.add(encrypted);
        }
      }

      if (recipients.isEmpty) return null;

      final envelope = <String, dynamic>{
        'v': 1,
        'senderUserId': userId,
        'senderDeviceId': deviceId,
        'recipients': recipients,
      };
      return _encodeEnvelope(envelope);
    } finally {
      localIdentity.dispose();
      xIdentity.dispose();
    }
  }

  Future<String?> decryptBody({
    required String body,
    required String senderUserId,
    required String senderDeviceId,
  }) async {
    if (!isEncrypted(body)) return body;
    await _ensureSecurityInitialized();
    final userId = await _store.getUserId();
    if (userId == null || userId.isEmpty) return null;
    final deviceId = await _deviceIdStore.getOrCreate();
    final envelope = _decodeEnvelope(body);
    if (envelope == null) return null;

    final recipients = envelope['recipients'];
    if (recipients is! List) return null;
    Map<String, dynamic>? entry;
    for (final item in recipients) {
      if (item is! Map<String, dynamic>) continue;
      final targetDeviceId = item['deviceId']?.toString();
      final targetUserId = item['userId']?.toString();
      if (targetDeviceId == deviceId &&
          (targetUserId == null || targetUserId == userId)) {
        entry = item;
        break;
      }
    }
    if (entry == null) {
      final fallback = await _tryDecryptOutgoing(
        myUserId: userId,
        senderUserId: senderUserId,
        recipients: recipients,
      );
      if (fallback != null) return fallback;
      return null;
    }

    final ratchetEncoded = entry['ratchet']?.toString();
    if (ratchetEncoded == null || ratchetEncoded.isEmpty) return null;
    final ratchetMessage =
        RatchetMessage.fromBytes(base64Decode(ratchetEncoded));

    final sessionId =
        SessionStore.makeSessionId(userId, senderUserId, senderDeviceId);
    final preKey = entry['preKey'];
    if (preKey is Map<String, dynamic>) {
      return _decryptPreKeyMessage(
        sessionId: sessionId,
        senderUserId: senderUserId,
        senderDeviceId: senderDeviceId,
        preKey: preKey,
        message: ratchetMessage,
      );
    }

    return _decryptWithSession(
      sessionId: sessionId,
      message: ratchetMessage,
    );
  }

  Future<void> _ensureSecurityInitialized() async {
    if (SecurityInit.isInitialized) return;
    await SecurityInit.initialize(config: SecurityConfig.development());
  }

  Future<_LocalIdentity> _ensureLocalIdentity(
    String userId,
    String deviceId,
  ) async {
    final existing = await IdentityStore.getLocalIdentity();
    if (existing != null &&
        existing.privateKey != null &&
        existing.privateKey!.isNotEmpty) {
      final sodium = await SodiumLoader.sodium;
      final privateKey = sodium.secureCopy(
        Uint8List.fromList(existing.privateKey!),
      );
      return _LocalIdentity(
        userId: existing.odid,
        deviceId: existing.deviceId,
        registrationId: existing.registrationId,
        publicKey: Uint8List.fromList(existing.publicKey),
        privateKey: privateKey,
      );
    }

    final identity = await KeyGeneration.generateIdentityKeyPair();
    final registrationId = await KeyGeneration.generateRegistrationId();
    await IdentityStore.saveLocalIdentity(
      odid: userId,
      deviceId: deviceId,
      registrationId: registrationId,
      publicKey: identity.publicKey,
      privateKey: identity.secretKey.extractBytes(),
    );
    return _LocalIdentity(
      userId: userId,
      deviceId: deviceId,
      registrationId: registrationId,
      publicKey: identity.publicKey,
      privateKey: identity.secretKey,
    );
  }

  Future<_XIdentityKeyPair> _ensureLocalXIdentity() async {
    final storedPublic = await _store.getE2eeIdentityXPublicKey();
    final storedPrivate = await _store.getE2eeIdentityXPrivateKey();
    if (storedPublic != null &&
        storedPublic.isNotEmpty &&
        storedPrivate != null &&
        storedPrivate.isNotEmpty) {
      final sodium = await SodiumLoader.sodium;
      return _XIdentityKeyPair(
        publicKey: base64Decode(storedPublic),
        privateKey: sodium.secureCopy(base64Decode(storedPrivate)),
      );
    }

    final sodium = await SodiumLoader.sodium;
    final keyPair = sodium.crypto.box.keyPair();
    await _store.setE2eeIdentityXPublicKey(
      base64Encode(keyPair.publicKey),
    );
    await _store.setE2eeIdentityXPrivateKey(
      base64Encode(keyPair.secretKey.extractBytes()),
    );
    return _XIdentityKeyPair(
      publicKey: keyPair.publicKey,
      privateKey: keyPair.secretKey,
    );
  }

  Future<_SignedPreKeyBundle> _ensureSignedPreKey(
    SecureKey identityPrivateKey,
  ) async {
    final needsRotation = await SignedPreKeyStore.needsRotation();
    final current = await SignedPreKeyStore.getCurrentSignedPreKey();
    if (current == null || needsRotation) {
      final keyId = await SignedPreKeyStore.getNextKeyId();
      final signed = await KeyGeneration.generateSignedPreKey(
        keyId: keyId,
        identityPrivateKey: identityPrivateKey,
      );
      final publicKey = signed.publicKey;
      final signature = signed.signature;
      await SignedPreKeyStore.saveSignedPreKey(
        keyId: signed.keyId,
        publicKey: publicKey,
        privateKey: signed.secretKey.extractBytes(),
        signature: signature,
        isActive: true,
      );
      signed.dispose();
      return _SignedPreKeyBundle(
        keyId: signed.keyId,
        publicKey: publicKey,
        signature: signature,
      );
    }

    return _SignedPreKeyBundle(
      keyId: current.keyId,
      publicKey: Uint8List.fromList(current.publicKey),
      signature: Uint8List.fromList(current.signature),
    );
  }

  Future<List<PreKeyEntity>> _ensurePreKeys() async {
    if (await PreKeyStore.needsReplenishment()) {
      final startId = await PreKeyStore.getNextKeyId();
      final batch = await KeyGeneration.generateOneTimePreKeyBatch(
        startId: startId,
      );
      final data = <PreKeyData>[];
      for (final key in batch) {
        data.add(
          PreKeyData(
            keyId: key.keyId,
            publicKey: key.publicKey,
            privateKey: key.secretKey.extractBytes(),
          ),
        );
        key.dispose();
      }
      await PreKeyStore.savePreKeyBatch(data);
    }
    return PreKeyStore.getPendingUpload();
  }

  Future<void> _registerDevice({
    required String deviceId,
    required Uint8List identityKeyEd,
    required Uint8List identityKeyX,
    required int registrationId,
    required _SignedPreKeyBundle signedPreKey,
    required List<PreKeyEntity> pendingPreKeys,
  }) async {
    final identityJson = jsonEncode({
      'ed25519': base64Encode(identityKeyEd),
      'x25519': base64Encode(identityKeyX),
    });

    final registerKeys = pendingPreKeys.take(200).toList();
    final body = <String, dynamic>{
      'deviceId': deviceId,
      'platform': _platformName(),
      'identityKey': identityJson,
      'registrationId': registrationId,
      'signedPreKey': {
        'keyId': signedPreKey.keyId,
        'publicKey': base64Encode(signedPreKey.publicKey),
        'signature': base64Encode(signedPreKey.signature),
      },
      if (registerKeys.isNotEmpty)
        'oneTimePreKeys': registerKeys
            .map(
              (key) => {
                'keyId': key.keyId,
                'publicKey': base64Encode(
                  Uint8List.fromList(key.publicKey),
                ),
              },
            )
            .toList(),
    };

    await _client.post(
      '/crypto/devices/register',
      auth: true,
      body: body,
    );

    if (registerKeys.isNotEmpty) {
      await PreKeyStore.markUploaded(
        registerKeys.map((key) => key.keyId).toList(),
      );
    }

    final remaining = pendingPreKeys.skip(registerKeys.length).toList();
    if (remaining.isNotEmpty) {
      await _uploadPreKeys(deviceId: deviceId, preKeys: remaining);
    }
  }

  Future<void> _uploadPreKeys({
    required String deviceId,
    required List<PreKeyEntity> preKeys,
  }) async {
    if (preKeys.isEmpty) return;
    await _client.post(
      '/crypto/prekeys',
      auth: true,
      body: {
        'deviceId': deviceId,
        'preKeys': preKeys
            .map(
              (key) => {
                'keyId': key.keyId,
                'publicKey': base64Encode(
                  Uint8List.fromList(key.publicKey),
                ),
              },
            )
            .toList(),
      },
    );
    await PreKeyStore.markUploaded(
      preKeys.map((key) => key.keyId).toList(),
    );
  }

  Future<List<_RemoteDevice>> _listDevices(String userId) async {
    final data = await _client.get(
      '/crypto/devices/$userId',
      auth: true,
    );
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => _RemoteDevice(
            userId: userId,
            deviceId: row['deviceId']?.toString() ?? '',
          ),
        )
        .where((device) => device.deviceId.isNotEmpty)
        .toList();
  }

  Future<List<_RemoteDevice>> _buildTargets({
    required String myUserId,
    required String myDeviceId,
    required String peerUserId,
    required bool includeSelfDevices,
  }) async {
    final targets = <_RemoteDevice>[];
    final peerDevices = await _listDevices(peerUserId);
    targets.addAll(peerDevices);
    if (includeSelfDevices) {
      final myDevices = await _listDevices(myUserId);
      targets.addAll(
        myDevices.where((device) => device.deviceId != myDeviceId),
      );
    }
    return targets;
  }

  Future<List<_RemoteDevice>> _buildTargetsForUsers({
    required String myUserId,
    required String myDeviceId,
    required List<String> userIds,
    required bool includeSelfDevices,
  }) async {
    final targets = <_RemoteDevice>[];
    final seen = <String>{};

    for (final userId in userIds) {
      final trimmed = userId.trim();
      if (trimmed.isEmpty) continue;
      final devices = await _listDevices(trimmed);
      for (final device in devices) {
        final key = '${device.userId}:${device.deviceId}';
        if (seen.add(key)) {
          targets.add(device);
        }
      }
    }

    if (includeSelfDevices) {
      final myDevices = await _listDevices(myUserId);
      for (final device in myDevices) {
        if (device.deviceId == myDeviceId) continue;
        final key = '${device.userId}:${device.deviceId}';
        if (seen.add(key)) {
          targets.add(device);
        }
      }
    }

    return targets;
  }

  Future<Map<String, dynamic>?> _encryptForDevice({
    required String myUserId,
    required String myDeviceId,
    required int myRegistrationId,
    required Uint8List myIdentityKeyEd,
    required Uint8List myIdentityKeyX,
    required SecureKey myIdentityPrivateKeyX,
    required _RemoteDevice target,
    required String plaintext,
  }) async {
    final sessionId = SessionStore.makeSessionId(
      myUserId,
      target.userId,
      target.deviceId,
    );
    final existing = await SessionStore.getSession(sessionId);
    DoubleRatchet ratchet;
    Map<String, dynamic>? preKeyPayload;

    if (existing != null && existing.myRatchetPrivateKey != null) {
      final state = SessionStore.entityToState(existing);
      final sodium = await SodiumLoader.sodium;
      final privateKey = sodium.secureCopy(
        Uint8List.fromList(existing.myRatchetPrivateKey!),
      );
      ratchet = await DoubleRatchet.importState(
        state: state,
        myRatchetPrivateKey: privateKey,
      );
    } else {
      final bundle = await _fetchPreKeyBundle(
        userId: target.userId,
        deviceId: target.deviceId,
      );
      if (bundle == null) return null;

      final initiator = await X3DH.initiateSession(
        myIdentityPublicKeyX25519: myIdentityKeyX,
        myIdentityPrivateKeyX25519: myIdentityPrivateKeyX,
        theirIdentityPublicKeyX25519: bundle.identityKeyX,
        theirSignedPreKeyPublic: bundle.signedPreKeyPublic,
        theirSignedPreKeySignature: bundle.signedPreKeySignature,
        theirIdentityPublicKeyEd25519: bundle.identityKeyEd,
        theirOneTimePreKeyPublic: bundle.oneTimePreKeyPublic,
        theirOneTimePreKeyId: bundle.oneTimePreKeyId,
      );

      ratchet = await DoubleRatchet.initializeAsInitiator(
        sharedSecret: initiator.sharedSecret,
        theirRatchetPublicKey: bundle.signedPreKeyPublic,
        sessionId: sessionId,
      );
      final ephemeralKey = initiator.ephemeralPublicKey;
      final usedOneTimePreKeyId = initiator.usedOneTimePreKeyId;
      initiator.dispose();

      preKeyPayload = {
        'senderIdentityKeyEd': base64Encode(myIdentityKeyEd),
        'senderIdentityKeyX': base64Encode(myIdentityKeyX),
        'senderEphemeralKey': base64Encode(ephemeralKey),
        'senderRegistrationId': myRegistrationId,
        'signedPreKeyId': bundle.signedPreKeyId,
        if (usedOneTimePreKeyId != null)
          'oneTimePreKeyId': usedOneTimePreKeyId,
      };
    }

    try {
      final message = await ratchet.encrypt(
        Uint8List.fromList(utf8.encode(plaintext)),
      );
      final encrypted = base64Encode(message.toBytes());

      final state = ratchet.exportState();
      final myRatchetPrivateKey = ratchet.exportMyRatchetPrivateKey();

      if (existing != null && existing.myRatchetPrivateKey != null) {
        await SessionStore.updateSession(
          sessionId: sessionId,
          state: state,
          myRatchetPrivateKey: myRatchetPrivateKey,
        );
      } else {
        await SessionStore.saveSession(
          sessionId: sessionId,
          myOdid: myUserId,
          remoteOdid: target.userId,
          remoteDeviceId: target.deviceId,
          state: state,
          myRatchetPrivateKey: myRatchetPrivateKey,
        );
      }

      return {
        'userId': target.userId,
        'deviceId': target.deviceId,
        'ratchet': encrypted,
        if (preKeyPayload != null) 'preKey': preKeyPayload,
      };
    } finally {
      ratchet.dispose();
    }
  }

  Future<_PreKeyBundle?> _fetchPreKeyBundle({
    required String userId,
    required String deviceId,
  }) async {
    final data = await _client.get(
      '/crypto/bundle/$userId/$deviceId',
      auth: true,
    );
    if (data is! Map<String, dynamic>) return null;

    final identityRaw = data['identityKey']?.toString() ?? '';
    final identity = _parseIdentityKey(identityRaw);
    if (identity == null) return null;

    final signed = data['signedPreKey'];
    if (signed is! Map<String, dynamic>) return null;

    final signedPublic = _decodeKey(signed['publicKey']);
    final signedSignature = _decodeKey(signed['signature']);
    final signedKeyId = _parseInt(signed['keyId']);
    if (signedPublic == null || signedSignature == null || signedKeyId == null) {
      return null;
    }

    final oneTime = data['oneTimePreKey'];
    Uint8List? oneTimePublic;
    int? oneTimeKeyId;
    if (oneTime is Map<String, dynamic>) {
      oneTimePublic = _decodeKey(oneTime['publicKey']);
      oneTimeKeyId = _parseInt(oneTime['keyId']);
    }

    final registrationId = _parseInt(data['registrationId']) ?? 0;
    await IdentityStore.saveRemoteIdentity(
      odid: userId,
      deviceId: deviceId,
      registrationId: registrationId,
      publicKey: identity.edPublicKey,
    );

    return _PreKeyBundle(
      identityKeyEd: identity.edPublicKey,
      identityKeyX: identity.xPublicKey,
      signedPreKeyPublic: signedPublic,
      signedPreKeySignature: signedSignature,
      signedPreKeyId: signedKeyId,
      oneTimePreKeyPublic: oneTimePublic,
      oneTimePreKeyId: oneTimeKeyId,
    );
  }

  Future<String?> _decryptPreKeyMessage({
    required String sessionId,
    required String senderUserId,
    required String senderDeviceId,
    required Map<String, dynamic> preKey,
    required RatchetMessage message,
  }) async {
    final identityEd = _decodeKey(preKey['senderIdentityKeyEd']);
    final identityX = _decodeKey(preKey['senderIdentityKeyX']);
    final senderEphemeral = _decodeKey(preKey['senderEphemeralKey']);
    final signedPreKeyId = _parseInt(preKey['signedPreKeyId']);
    if (identityX == null ||
        senderEphemeral == null ||
        signedPreKeyId == null) {
      return null;
    }

    if (identityEd != null) {
      final registrationId =
          _parseInt(preKey['senderRegistrationId']) ?? 0;
      await IdentityStore.saveRemoteIdentity(
        odid: senderUserId,
        deviceId: senderDeviceId,
        registrationId: registrationId,
        publicKey: identityEd,
      );
    }

    final signedPreKey =
        await SignedPreKeyStore.getSignedPreKey(signedPreKeyId);
    if (signedPreKey == null || signedPreKey.privateKey == null) {
      return null;
    }

    final sodium = await SodiumLoader.sodium;
    final mySignedPreKeyPrivate = sodium.secureCopy(
      Uint8List.fromList(signedPreKey.privateKey!),
    );

    SecureKey? myOneTimePreKeyPrivate;
    final oneTimeId = _parseInt(preKey['oneTimePreKeyId']);
    if (oneTimeId != null) {
      final oneTimeBytes = await PreKeyStore.consumePreKey(oneTimeId);
      if (oneTimeBytes != null) {
        myOneTimePreKeyPrivate = sodium.secureCopy(oneTimeBytes);
      }
    }

    final xIdentity = await _ensureLocalXIdentity();
    X3DHResponderResult? responder;
    DoubleRatchet? ratchet;
    try {
      if (oneTimeId != null && myOneTimePreKeyPrivate == null) {
        return null;
      }
      responder = await X3DH.completeSession(
        myIdentityPrivateKeyX25519: xIdentity.privateKey,
        mySignedPreKeyPrivate: mySignedPreKeyPrivate,
        myOneTimePreKeyPrivate: myOneTimePreKeyPrivate,
        theirIdentityPublicKeyX25519: identityX,
        theirEphemeralPublicKey: senderEphemeral,
      );

      ratchet = await DoubleRatchet.initializeAsResponder(
        sharedSecret: responder.sharedSecret,
        myRatchetKeyPair: RatchetKeyPair(
          publicKey: Uint8List.fromList(signedPreKey.publicKey),
          secretKey: mySignedPreKeyPrivate,
        ),
        sessionId: sessionId,
      );

      final plaintextBytes = await ratchet.decrypt(message);
      final plaintext = utf8.decode(plaintextBytes);
      final state = ratchet.exportState();
      final ratchetPrivateKey = ratchet.exportMyRatchetPrivateKey();
      await SessionStore.saveSession(
        sessionId: sessionId,
        myOdid: await _store.getUserId() ?? '',
        remoteOdid: senderUserId,
        remoteDeviceId: senderDeviceId,
        state: state,
        myRatchetPrivateKey: ratchetPrivateKey,
      );
      return plaintext;
    } finally {
      if (ratchet == null) {
        mySignedPreKeyPrivate.dispose();
      } else {
        ratchet.dispose();
      }
      responder?.dispose();
      myOneTimePreKeyPrivate?.dispose();
      xIdentity.dispose();
    }
  }

  Future<String?> _decryptWithSession({
    required String sessionId,
    required RatchetMessage message,
  }) async {
    final existing = await SessionStore.getSession(sessionId);
    if (existing == null || existing.myRatchetPrivateKey == null) {
      return null;
    }
    final state = SessionStore.entityToState(existing);
    final sodium = await SodiumLoader.sodium;
    final privateKey = sodium.secureCopy(
      Uint8List.fromList(existing.myRatchetPrivateKey!),
    );

    final ratchet = await DoubleRatchet.importState(
      state: state,
      myRatchetPrivateKey: privateKey,
    );
    try {
      final plaintextBytes = await ratchet.decrypt(message);
      final plaintext = utf8.decode(plaintextBytes);
      final nextState = ratchet.exportState();
      final nextPrivate = ratchet.exportMyRatchetPrivateKey();
      await SessionStore.updateSession(
        sessionId: sessionId,
        state: nextState,
        myRatchetPrivateKey: nextPrivate,
      );
      return plaintext;
    } finally {
      ratchet.dispose();
    }
  }

  Future<String?> _tryDecryptOutgoing({
    required String myUserId,
    required String senderUserId,
    required List recipients,
  }) async {
    if (senderUserId != myUserId) return null;

    for (final item in recipients) {
      if (item is! Map<String, dynamic>) continue;
      final targetUserId = item['userId']?.toString() ?? '';
      final targetDeviceId = item['deviceId']?.toString() ?? '';
      if (targetUserId.isEmpty || targetDeviceId.isEmpty) continue;

      final ratchetEncoded = item['ratchet']?.toString();
      if (ratchetEncoded == null || ratchetEncoded.isEmpty) continue;

      RatchetMessage? ratchetMessage;
      try {
        ratchetMessage =
            RatchetMessage.fromBytes(base64Decode(ratchetEncoded));
      } catch (_) {
        continue;
      }

      final sessionId =
          SessionStore.makeSessionId(myUserId, targetUserId, targetDeviceId);
      final existing = await SessionStore.getSession(sessionId);
      if (existing == null) continue;

      Uint8List? messageKey;
      try {
        final skippedRaw = jsonDecode(existing.skippedKeys);
        if (skippedRaw is! Map<String, dynamic>) continue;
        final skippedKeys = SkippedMessageKeys.fromJson(skippedRaw);
        messageKey = skippedKeys.getPersistentKey(
          ratchetMessage.ratchetPublicKey,
          ratchetMessage.messageNumber,
        );
        skippedKeys.clear();
        if (messageKey == null) continue;

        final plaintextBytes = await MessageKeys.decrypt(
          ciphertext: ratchetMessage.ciphertext,
          nonce: ratchetMessage.nonce,
          messageKey: messageKey,
        );
        _zeroize(messageKey);
        return utf8.decode(plaintextBytes);
      } catch (_) {
        if (messageKey != null) {
          _zeroize(messageKey);
        }
        continue;
      }
    }

    return null;
  }

  String _encodeEnvelope(Map<String, dynamic> payload) {
    final bytes = utf8.encode(jsonEncode(payload));
    return '$envelopePrefix${base64Encode(bytes)}';
  }

  Map<String, dynamic>? _decodeEnvelope(String body) {
    if (!body.startsWith(envelopePrefix)) return null;
    final encoded = body.substring(envelopePrefix.length);
    try {
      final decoded = utf8.decode(base64Decode(encoded));
      final json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) return json;
    } catch (_) {}
    return null;
  }

  _IdentityKeyBundle? _parseIdentityKey(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final edKey = decoded['ed25519'] ?? decoded['ed'];
      final xKey = decoded['x25519'] ?? decoded['x'];
      if (edKey is! String || xKey is! String) return null;
      return _IdentityKeyBundle(
        edPublicKey: base64Decode(edKey),
        xPublicKey: base64Decode(xKey),
      );
    } catch (_) {
      return null;
    }
  }

  Uint8List? _decodeKey(dynamic value) {
    if (value is String && value.isNotEmpty) {
      try {
        return base64Decode(value);
      } catch (_) {}
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  void _zeroize(Uint8List buffer) {
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }

  String _platformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return 'desktop';
    }
    return 'web';
  }
}

class _LocalIdentity {
  _LocalIdentity({
    required this.userId,
    required this.deviceId,
    required this.registrationId,
    required this.publicKey,
    required this.privateKey,
  });

  final String userId;
  final String deviceId;
  final int registrationId;
  final Uint8List publicKey;
  final SecureKey privateKey;

  void dispose() {
    privateKey.dispose();
  }
}

class _XIdentityKeyPair {
  _XIdentityKeyPair({
    required this.publicKey,
    required this.privateKey,
  });

  final Uint8List publicKey;
  final SecureKey privateKey;

  void dispose() {
    privateKey.dispose();
  }
}

class _SignedPreKeyBundle {
  _SignedPreKeyBundle({
    required this.keyId,
    required this.publicKey,
    required this.signature,
  });

  final int keyId;
  final Uint8List publicKey;
  final Uint8List signature;
}

class _RemoteDevice {
  _RemoteDevice({
    required this.userId,
    required this.deviceId,
  });

  final String userId;
  final String deviceId;
}

class _IdentityKeyBundle {
  _IdentityKeyBundle({
    required this.edPublicKey,
    required this.xPublicKey,
  });

  final Uint8List edPublicKey;
  final Uint8List xPublicKey;
}

class _PreKeyBundle {
  _PreKeyBundle({
    required this.identityKeyEd,
    required this.identityKeyX,
    required this.signedPreKeyPublic,
    required this.signedPreKeySignature,
    required this.signedPreKeyId,
    this.oneTimePreKeyPublic,
    this.oneTimePreKeyId,
  });

  final Uint8List identityKeyEd;
  final Uint8List identityKeyX;
  final Uint8List signedPreKeyPublic;
  final Uint8List signedPreKeySignature;
  final int signedPreKeyId;
  final Uint8List? oneTimePreKeyPublic;
  final int? oneTimePreKeyId;
}
