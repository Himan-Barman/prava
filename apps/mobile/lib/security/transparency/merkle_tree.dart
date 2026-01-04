// Merkle tree for key transparency
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// ============================================================
/// Merkle Tree
/// ============================================================
/// Key transparency implementation: 
///
/// • Audit log verification
/// • Proof of inclusion
/// • Key consistency verification
/// ============================================================
final class MerkleTree {
  MerkleTree._();

  /// Hash a leaf node
  static Uint8List hashLeaf(Uint8List data) {
    return Uint8List.fromList(sha256.convert(data).bytes);
  }

  /// Combine two hashes
  static Uint8List combineHashes(Uint8List left, Uint8List right) {
    final combined = _compare(left, right) <= 0
        ?  [... left, ...right]
        : [...right, ...left];
    return hashLeaf(Uint8List.fromList(combined));
  }

  /// Build tree from leaves
  static MerkleTreeResult build(List<Uint8List> leaves) {
    if (leaves.isEmpty) {
      throw ArgumentError('Cannot build tree from empty leaves');
    }

    List<Uint8List> level = leaves.map(hashLeaf).toList();
    final levels = <List<Uint8List>>[List.from(level)];

    while (level.length > 1) {
      final next = <Uint8List>[];

      for (var i = 0; i < level.length; i += 2) {
        if (i + 1 < level.length) {
          next.add(combineHashes(level[i], level[i + 1]));
        } else {
          next.add(level[i]);
        }
      }

      level = next;
      levels.add(List.from(level));
    }

    return MerkleTreeResult(
      root: level.first,
      levels:  levels,
      leafCount: leaves.length,
    );
  }

  /// Generate inclusion proof
  static MerkleProof generateProof(MerkleTreeResult tree, int leafIndex) {
    if (leafIndex < 0 || leafIndex >= tree.leafCount) {
      throw ArgumentError('Leaf index out of range');
    }

    final path = <ProofNode>[];
    var index = leafIndex;

    for (var i = 0; i < tree.levels.length - 1; i++) {
      final level = tree.levels[i];
      final isLeft = index % 2 == 0;
      final siblingIndex = isLeft ? index + 1 : index - 1;

      if (siblingIndex < level.length) {
        path. add(ProofNode(
          hash:  level[siblingIndex],
          isLeft: ! isLeft,
        ));
      }

      index ~/= 2;
    }

    return MerkleProof(
      leafIndex: leafIndex,
      path: path,
      root:  tree.root,
    );
  }

  /// Verify inclusion proof
  static bool verifyProof(MerkleProof proof, Uint8List leaf) {
    Uint8List current = hashLeaf(leaf);

    for (final node in proof.path) {
      if (node.isLeft) {
        current = combineHashes(node.hash, current);
      } else {
        current = combineHashes(current, node.hash);
      }
    }

    return _bytesEqual(current, proof.root);
  }

  /// Compare two byte arrays
  static int _compare(Uint8List a, Uint8List b) {
    final minLen = a.length < b.length ? a.length : b. length;
    for (var i = 0; i < minLen; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }

  /// Constant-time comparison
  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}

/// Merkle tree build result
class MerkleTreeResult {
  final Uint8List root;
  final List<List<Uint8List>> levels;
  final int leafCount;

  const MerkleTreeResult({
    required this.root,
    required this.levels,
    required this. leafCount,
  });

  int get height => levels.length;

  String get rootHex =>
      root.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Proof node in path
class ProofNode {
  final Uint8List hash;
  final bool isLeft;

  const ProofNode({
    required this.hash,
    required this.isLeft,
  });

  Map<String, dynamic> toJson() => {
        'hash': hash. toList(),
        'isLeft': isLeft,
      };

  factory ProofNode.fromJson(Map<String, dynamic> json) {
    return ProofNode(
      hash: Uint8List.fromList((json['hash'] as List).cast<int>()),
      isLeft: json['isLeft'] as bool,
    );
  }
}

/// Merkle inclusion proof
class MerkleProof {
  final int leafIndex;
  final List<ProofNode> path;
  final Uint8List root;

  const MerkleProof({
    required this. leafIndex,
    required this.path,
    required this. root,
  });

  bool verify(Uint8List leaf) => MerkleTree.verifyProof(this, leaf);

  Map<String, dynamic> toJson() => {
        'leafIndex': leafIndex,
        'path': path.map((n) => n.toJson()).toList(),
        'root': root. toList(),
      };

  factory MerkleProof. fromJson(Map<String, dynamic> json) {
    return MerkleProof(
      leafIndex: json['leafIndex'] as int,
      path: (json['path'] as List)
          .map((e) => ProofNode.fromJson(e as Map<String, dynamic>))
          .toList(),
      root: Uint8List.fromList((json['root'] as List).cast<int>()),
    );
  }
}