// Device identity
import 'package:equatable/equatable.dart';

/// Device trust levels
enum DeviceTrust {
  /// Primary device (full access)
  primary,

  /// Linked secondary device
  secondary,

  /// Pending verification
  pending,

  /// Revoked (blocked)
  revoked,
}

/// ============================================================
/// Device Identity
/// ============================================================
/// Represents a device in the multi-device system. 
/// ============================================================
class DeviceIdentity extends Equatable {
  /// Unique device identifier
  final String deviceId;

  /// Device trust level
  final DeviceTrust trust;

  /// Ed25519 identity public key
  final List<int> publicKey;

  /// Registration ID
  final int registrationId;

  /// User-facing device name
  final String?  name;

  /// Platform (android/ios/web)
  final String? platform;

  /// Last seen timestamp
  final int?  lastSeenAt;

  /// Creation timestamp
  final int createdAt;

  const DeviceIdentity({
    required this. deviceId,
    required this.trust,
    required this. publicKey,
    required this.registrationId,
    this.name,
    this.platform,
    this.lastSeenAt,
    required this.createdAt,
  });

  /// Can this device send messages?
  bool get canSend => trust == DeviceTrust. primary || trust == DeviceTrust.secondary;

  /// Can this device receive messages?
  bool get canReceive => trust != DeviceTrust. revoked;

  /// Is this device active?
  bool get isActive => trust != DeviceTrust.revoked && trust != DeviceTrust.pending;

  /// Create a revoked copy
  DeviceIdentity revoke() => copyWith(trust: DeviceTrust.revoked);

  /// Update last seen
  DeviceIdentity updateLastSeen() => copyWith(
        lastSeenAt: DateTime.now().millisecondsSinceEpoch,
      );

  /// Copy with modifications
  DeviceIdentity copyWith({
    String? deviceId,
    DeviceTrust? trust,
    List<int>? publicKey,
    int? registrationId,
    String? name,
    String? platform,
    int? lastSeenAt,
    int? createdAt,
  }) {
    return DeviceIdentity(
      deviceId: deviceId ?? this.deviceId,
      trust: trust ?? this. trust,
      publicKey: publicKey ??  this.publicKey,
      registrationId: registrationId ??  this.registrationId,
      name:  name ?? this.name,
      platform:  platform ?? this.platform,
      lastSeenAt: lastSeenAt ?? this. lastSeenAt,
      createdAt: createdAt ??  this.createdAt,
    );
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'trust': trust.index,
        'publicKey': publicKey,
        'registrationId': registrationId,
        'name': name,
        'platform': platform,
        'lastSeenAt': lastSeenAt,
        'createdAt':  createdAt,
      };

  /// Deserialize from JSON
  factory DeviceIdentity.fromJson(Map<String, dynamic> json) {
    return DeviceIdentity(
      deviceId:  json['deviceId'] as String,
      trust: DeviceTrust.values[json['trust'] as int],
      publicKey: (json['publicKey'] as List).cast<int>(),
      registrationId: json['registrationId'] as int,
      name: json['name'] as String?,
      platform:  json['platform'] as String?,
      lastSeenAt: json['lastSeenAt'] as int?,
      createdAt:  json['createdAt'] as int,
    );
  }

  @override
  List<Object? > get props => [deviceId, trust, registrationId];

  @override
  String toString() => 'DeviceIdentity(id: $deviceId, trust: $trust, platform: $platform)';
}