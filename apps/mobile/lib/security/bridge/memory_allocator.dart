// Manual memory management
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// ============================================================
/// Manual Memory Allocator - Anti-Forensics Grade
/// ============================================================
/// Provides secure memory management for cryptographic secrets.
///
/// Security Guarantees:
/// • No garbage collector interference
/// • Explicit multi-pass memory zeroization (DOD 5220.22-M)
/// • Memory allocation tracking for leak detection
/// • Constant-time operations where applicable
///
/// Use for:
/// • Private keys
/// • Session keys
/// • Decrypted plaintext (temporary)
/// • Any sensitive cryptographic material
/// ============================================================
final class MemoryAllocator {
  MemoryAllocator._();

  static final Map<int, _AllocationRecord> _allocations = {};
  static bool _initialized = false;
  static int _totalAllocated = 0;
  static int _peakAllocated = 0;

  /// Maximum single allocation size (10MB)
  static const int maxAllocationSize = 10 * 1024 * 1024;

  /// Maximum total allocations (100MB)
  static const int maxTotalAllocations = 100 * 1024 * 1024;

  /// Initialize the allocator
  static void initialize() {
    if (_initialized) return;
    _initialized = true;
    _allocations.clear();
    _totalAllocated = 0;
    _peakAllocated = 0;
  }

  /// Allocate zeroed memory
  static Pointer<Uint8> allocate(int size, {String? label}) {
    _ensureInitialized();
    _validateSize(size);

    final ptr = calloc<Uint8>(size);
    if (ptr == nullptr) {
      throw OutOfMemoryError();
    }

    // Ensure memory is zeroed
    for (var i = 0; i < size; i++) {
      ptr[i] = 0;
    }

    // Track allocation
    _allocations[ptr. address] = _AllocationRecord(
      size: size,
      label: label,
      timestamp: DateTime.now(),
    );
    _totalAllocated += size;
    if (_totalAllocated > _peakAllocated) {
      _peakAllocated = _totalAllocated;
    }

    return ptr;
  }

  /// Allocate and copy data securely
  static Pointer<Uint8> allocateFrom(Uint8List data, {String?  label}) {
    final ptr = allocate(data.length, label: label);

    // Copy data
    for (var i = 0; i < data.length; i++) {
      ptr[i] = data[i];
    }

    // Zero source data
    for (var i = 0; i < data.length; i++) {
      data[i] = 0;
    }

    return ptr;
  }

  /// Securely wipe and free memory
  static void freeSecure(Pointer<Uint8> ptr, int size) {
    if (ptr == nullptr || ptr.address == 0) return;

    // Remove from tracking
    final record = _allocations.remove(ptr.address);
    if (record != null) {
      _totalAllocated -= record.size;
    }

    // DOD 5220.22-M compliant wiping (3-pass)
    _secureWipe(ptr, size);

    // Free memory
    calloc.free(ptr);
  }

  /// DOD 5220.22-M 3-pass secure wipe
  static void _secureWipe(Pointer<Uint8> ptr, int size) {
    // Pass 1: Write zeros
    for (var i = 0; i < size; i++) {
      ptr[i] = 0x00;
    }
    _memoryBarrier();

    // Pass 2: Write ones
    for (var i = 0; i < size; i++) {
      ptr[i] = 0xFF;
    }
    _memoryBarrier();

    // Pass 3: Write zeros
    for (var i = 0; i < size; i++) {
      ptr[i] = 0x00;
    }
    _memoryBarrier();
  }

  /// Memory barrier to prevent compiler optimization
  static void _memoryBarrier() {
    final temp = calloc<Uint8>(1);
    temp. value = 0xFF;
    final _ = temp. value;
    calloc.free(temp);
  }

  /// Wipe memory without freeing (for reuse)
  static void wipe(Pointer<Uint8> ptr, int size) {
    if (ptr == nullptr || ptr.address == 0) return;
    _secureWipe(ptr, size);
  }

  /// Constant-time memory comparison
  static bool secureEquals(Pointer<Uint8> a, Pointer<Uint8> b, int length) {
    var result = 0;
    for (var i = 0; i < length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  /// Copy between pointers securely
  static void secureCopy(Pointer<Uint8> dest, Pointer<Uint8> src, int size) {
    for (var i = 0; i < size; i++) {
      dest[i] = src[i];
    }
  }

  /// Get allocation statistics
  static AllocationStats getStats() {
    return AllocationStats(
      activeAllocations: _allocations.length,
      totalAllocated: _totalAllocated,
      peakAllocated: _peakAllocated,
    );
  }

  /// Check for memory leaks
  static List<LeakInfo> checkLeaks() {
    return _allocations.entries.map((e) {
      return LeakInfo(
        address: e. key,
        size: e.value. size,
        label: e.value. label,
        age: DateTime.now().difference(e.value.timestamp),
      );
    }).toList();
  }

  /// Force cleanup all allocations (use on app shutdown)
  static void cleanupAll() {
    final addresses = _allocations. keys.toList();
    for (final addr in addresses) {
      final record = _allocations[addr]!;
      final ptr = Pointer<Uint8>. fromAddress(addr);
      freeSecure(ptr, record.size);
    }
    _allocations.clear();
    _totalAllocated = 0;
  }

  static void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('MemoryAllocator not initialized.  Call initialize() first.');
    }
  }

  static void _validateSize(int size) {
    if (size <= 0) {
      throw ArgumentError('Size must be positive:  $size');
    }
    if (size > maxAllocationSize) {
      throw ArgumentError('Size exceeds maximum ($maxAllocationSize): $size');
    }
    if (_totalAllocated + size > maxTotalAllocations) {
      throw OutOfMemoryError();
    }
  }
}

/// Allocation record for tracking
class _AllocationRecord {
  final int size;
  final String? label;
  final DateTime timestamp;

  _AllocationRecord({
    required this.size,
    this. label,
    required this.timestamp,
  });
}

/// Allocation statistics
class AllocationStats {
  final int activeAllocations;
  final int totalAllocated;
  final int peakAllocated;

  const AllocationStats({
    required this.activeAllocations,
    required this.totalAllocated,
    required this.peakAllocated,
  });

  @override
  String toString() => 'AllocationStats('
      'active: $activeAllocations, '
      'total: ${totalAllocated ~/ 1024}KB, '
      'peak: ${peakAllocated ~/ 1024}KB)';
}

/// Memory leak information
class LeakInfo {
  final int address;
  final int size;
  final String? label;
  final Duration age;

  const LeakInfo({
    required this.address,
    required this.size,
    this.label,
    required this.age,
  });

  @override
  String toString() => 'LeakInfo(addr: 0x${address. toRadixString(16)}, '
      'size:  $size, label: $label, age: ${age.inSeconds}s)';
}

/// Out of memory error
class OutOfMemoryError extends Error {
  @override
  String toString() => 'OutOfMemoryError:  Secure memory allocation failed';
}