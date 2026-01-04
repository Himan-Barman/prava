// Main public exports
/// ============================================================
/// PRAVA SECURITY MODULE v1.0.0
/// ============================================================
/// Production-grade End-to-End Encryption
/// 
/// Implements: 
/// • Signal Protocol (X3DH + Double Ratchet)
/// • Sender Keys for group messaging
/// • Multi-device support
/// • Forward secrecy & post-compromise security
///
/// Security Level: 256-bit (AES-256 equivalent)
/// Target:  10M+ users, 40K concurrent connections
/// 
/// Compliance: GDPR, CCPA, SOC2 ready
/// ============================================================

library prava_security;

// ─────────────────────────────────────────────────────────────
// BRIDGE LAYER
// ─────────────────────────────────────────────────────────────
export 'bridge/memory_allocator.dart';
export 'bridge/native_api.dart';
export 'bridge/sodium_loader.dart';

// ─────────────────────────────────────────────────────────────
// CRYPTOGRAPHIC PRIMITIVES
// ─────────────────────────────────────────────────────────────
export 'crypto/hashing.dart';
export 'crypto/key_generation.dart';
export 'crypto/random_generator.dart';
export 'crypto/signatures.dart';
export 'crypto/x3dh.dart';

// ─────────────────────────────────────────────────────────────
// DOUBLE RATCHET ENGINE
// ─────────────────────────────────────────────────────────────
export 'ratchet/double_ratchet.dart';
export 'ratchet/chain_key.dart';
export 'ratchet/message_keys.dart';
export 'ratchet/skipped_keys.dart';
export 'ratchet/group/sender_key_state.dart';
export 'ratchet/group/sender_key_ratchet.dart';
export 'ratchet/group/sender_key_distribution.dart';

// ─────────────────────────────────────────────────────────────
// STORAGE LAYER
// ─────────────────────────────────────────────────────────────
export 'storage/vault.dart';
export 'storage/identity_store.dart';
export 'storage/session_store.dart';
export 'storage/prekey_store.dart';
export 'storage/signed_prekey_store.dart';

// ─────────────────────────────────────────────────────────────
// DATABASE ENTITIES
// ─────────────────────────────────────────────────────────────
export 'entities/identity_entity.dart';
export 'entities/session_entity.dart';
export 'entities/prekey_entity.dart';
export 'entities/signed_prekey_entity.dart';
export 'entities/sender_key_entity.dart';

// ─────────────────────────────────────────────────────────────
// MEMORY PROTECTION
// ─────────────────────────────────────────────────────────────
export 'memory/secure_buffer.dart';
export 'memory/protected_string.dart';
export 'memory/zeroize.dart';

// ─────────────────────────────────────────────────────────────
// BACKUP & RECOVERY
// ─────────────────────────────────────────────────────────────
export 'backup/backup_crypto.dart';
export 'backup/backup_manager.dart';
export 'backup/backup_payload.dart';

// ─────────────────────────────────────────────────────────────
// MULTI-DEVICE
// ─────────────────────────────────────────────────────────────
export 'device/device_identity.dart';
export 'device/device_registry.dart';
export 'device/device_bundle.dart';
export 'device/multi_device_manager.dart';

// ─────────────────────────────────────────────────────────────
// TRANSPORT SECURITY
// ─────────────────────────────────────────────────────────────
export 'transport/cert_pinning.dart';
export 'transport/traffic_obfuscation.dart';
export 'transport/packet_padding.dart';

// ─────────────────────────────────────────────────────────────
// PRIVACY
// ─────────────────────────────────────────────────────────────
export 'privacy/contact_hash.dart';
export 'privacy/metadata_strip.dart';

// ─────────────────────────────────────────────────────────────
// THREAT DETECTION
// ─────────────────────────────────────────────────────────────
export 'threat/root_detection.dart';
export 'threat/debugger_check.dart';
export 'threat/screen_protector.dart';

// ─────────────────────────────────────────────────────────────
// KEY TRANSPARENCY
// ─────────────────────────────────────────────────────────────
export 'transparency/merkle_tree.dart';

// ─────────────────────────────────────────────────────────────
// PROTOCOL
// ─────────────────────────────────────────────────────────────
export 'protocol/crypto_tasks.dart';
export 'protocol/message_envelope.dart';
export 'protocol/key_distribution.dart';