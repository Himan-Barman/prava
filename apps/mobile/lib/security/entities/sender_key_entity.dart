// Sender key entity
import 'package:isar/isar.dart';

part 'sender_key_entity.g.dart';

/// ============================================================
/// Sender Key Entity - Database Model
/// ============================================================
/// Stores sender keys for group messaging.
/// ============================================================
@Collection()
class SenderKeyEntity {
  Id id = Isar.autoIncrement;

  /// Group identifier
  @Index()
  late String groupId;

  /// Sender user ID
  @Index()
  late String senderId;

  /// Sender device ID
  late String deviceId;

  /// Key generation ID
  late int keyId;

  /// Chain key (32 bytes)
  late List<int> chainKey;

  /// Signature private key (for own keys)
  List<int>? signaturePrivateKey;

  /// Signature public key
  late List<int> signaturePublicKey;

  /// Current message index
  int messageIndex = 0;

  /// Whether this is our own sender key
  @Index()
  bool isOwn = false;

  /// Creation timestamp
  late int createdAt;

  /// Last used timestamp
  int?  lastUsedAt;

  /// Composite index
  @Index(composite: [CompositeIndex('senderId'), CompositeIndex('deviceId')])
  String get groupSenderDevice => '$groupId: $senderId:$deviceId';
}