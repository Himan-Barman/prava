// Session entity
import 'package:isar/isar.dart';

part 'session_entity.g.dart';

/// Session lifecycle status
enum SessionStatus {
  /// Active session
  active,

  /// No recent activity
  stale,

  /// Explicitly closed
  closed,
}

/// ============================================================
/// Session Entity - Database Model
/// ============================================================
/// Stores Double Ratchet session state.
/// ============================================================
@Collection()
class SessionEntity {
  Id id = Isar.autoIncrement;

  /// Unique session identifier
  @Index(unique: true)
  late String sessionId;

  /// Our user ID
  @Index()
  late String myOdid;

  /// Remote user ID
  @Index()
  late String remoteOdid;

  /// Remote device ID
  late String remoteDeviceId;

  /// Root key (32 bytes)
  late List<int> rootKey;

  /// Sending chain key (JSON)
  String? sendingChainKey;

  /// Receiving chain key (JSON)
  String? receivingChainKey;

  /// My ratchet private key
  List<int>? myRatchetPrivateKey;

  /// My ratchet public key
  List<int>? myRatchetPublicKey;

  /// Their ratchet public key
  List<int>? theirRatchetPublicKey;

  /// Sending chain length
  int sendingChainLength = 0;

  /// Receiving chain length
  int receivingChainLength = 0;

  /// Previous sending chain length
  int previousSendingChainLength = 0;

  /// Skipped message keys (JSON)
  late String skippedKeys;

  /// Creation timestamp
  late int createdAt;

  /// Last message timestamp
  int? lastMessageAt;

  /// Session status
  @Enumerated(EnumType.ordinal)
  SessionStatus status = SessionStatus.active;
}