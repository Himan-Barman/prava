// Signed PreKey entity
import 'package:isar/isar.dart';

part 'signed_prekey_entity.g.dart';

/// ============================================================
/// Signed PreKey Entity - Database Model
/// ============================================================
/// Stores signed pre-keys for X3DH. 
/// ============================================================
@Collection()
class SignedPreKeyEntity {
  Id id = Isar.autoIncrement;

  /// Unique key identifier
  @Index(unique: true)
  late int keyId;

  /// X25519 public key (32 bytes)
  late List<int> publicKey;

  /// X25519 private key (32 bytes)
  late List<int> privateKey;

  /// Ed25519 signature over public key
  late List<int> signature;

  /// Whether this is the current active key
  @Index()
  bool isActive = true;

  /// Creation timestamp
  late int createdAt;
}