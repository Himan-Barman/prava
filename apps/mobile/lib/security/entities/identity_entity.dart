// Identity entity (Isar)
import 'package:isar/isar.dart';

part 'identity_entity.g.dart';

/// Trust levels for identity keys
enum TrustLevel {
  /// Not yet trusted (new contact)
  untrusted,

  /// Trusted (accepted by user)
  trusted,

  /// Verified (safety number verified)
  verified,

  /// Blocked (explicitly distrusted)
  blocked,
}

/// Length constants for Ed25519 keys
const int ed25519PublicKeyLength = 32;
const int ed25519PrivateKeyLength = 64; // Secret + public concatenated

/// ============================================================
/// Identity Entity - Database Model
/// ============================================================
/// Stores identity keys for local and remote users.
/// ============================================================
@Collection()
class IdentityEntity {
  Id id = Isar.autoIncrement;

  /// User identifier
  @Index(caseSensitive: false)
  late String odid;

  /// Device identifier
  @Index(caseSensitive: false)
  late String deviceId;

  /// Registration ID (Signal protocol)
  late int registrationId;

  /// Ed25519 public key (32 bytes)
  late List<int> publicKey;

  /// Ed25519 private key (64 bytes) - only for local identity
  /// NOTE: Storing private keys in the database should be avoided unless
  /// they are encrypted/encapsulated. Prefer secure storage or sealed boxes.
  List<int>? privateKey;

  /// Whether this is our local identity
  @Index()
  late bool isLocal;

  /// Trust level
  @Enumerated(EnumType.ordinal)
  TrustLevel trustLevel = TrustLevel.untrusted;

  /// Creation timestamp (ms since epoch)
  late int createdAt;

  /// When key was last changed (ms since epoch)
  int? keyChangedAt;

  /// When identity was verified (ms since epoch)
  int? verifiedAt;

  /// Composite index for lookups and uniqueness on (odid, deviceId)
  @Index(
    composite: [CompositeIndex('deviceId')],
    unique: true,
    caseSensitive: false,
  )
  String get odidDevice => '$odid:$deviceId';

  // ─────────────────────────────────────────────────────────
  // Validation helpers (not persisted)
  // ─────────────────────────────────────────────────────────

  @ignore
  bool get hasValidPublicKeyLength =>
      publicKey.length == ed25519PublicKeyLength;

  @ignore
  bool get hasValidPrivateKeyLength =>
      privateKey == null || privateKey!.length == ed25519PrivateKeyLength;

  @ignore
  void assertValid() {
    if (!hasValidPublicKeyLength) {
      throw ArgumentError(
        'publicKey must be $ed25519PublicKeyLength bytes, got ${publicKey.length}',
      );
    }
    if (!hasValidPrivateKeyLength) {
      throw ArgumentError(
        'privateKey must be $ed25519PrivateKeyLength bytes when present, got ${privateKey!.length}',
      );
    }
  }
}