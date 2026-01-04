// PreKey entity
import 'package:isar/isar.dart';

part 'prekey_entity.g.dart';

/// ============================================================
/// PreKey Entity - Database Model
/// ============================================================
/// Stores one-time pre-keys for X3DH. 
/// ============================================================
@Collection()
class PreKeyEntity {
  Id id = Isar.autoIncrement;

  /// Unique key identifier
  @Index(unique: true)
  late int keyId;

  /// X25519 public key (32 bytes)
  late List<int> publicKey;

  /// X25519 private key (32 bytes)
  late List<int> privateKey;

  /// Whether uploaded to server
  @Index()
  bool uploaded = false;

  /// Whether consumed (used)
  @Index()
  bool consumed = false;

  /// Creation timestamp
  late int createdAt;

  /// Consumption timestamp
  int?  consumedAt;
}