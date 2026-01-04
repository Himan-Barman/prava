// Isolate-safe crypto tasks
import 'dart:typed_data';

/// ============================================================
/// Crypto Tasks
/// ============================================================
/// Isolate-safe task objects for background crypto operations. 
/// ============================================================

/// Encryption task
final class EncryptTask {
  final String taskId;
  final Uint8List plaintext;
  final Uint8List sessionId;
  final int messageNumber;
  final DateTime createdAt;

  EncryptTask({
    required this.taskId,
    required this.plaintext,
    required this. sessionId,
    required this.messageNumber,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'plaintext': plaintext.toList(),
        'sessionId':  sessionId.toList(),
        'messageNumber': messageNumber,
        'createdAt':  createdAt.millisecondsSinceEpoch,
      };

  factory EncryptTask. fromJson(Map<String, dynamic> json) {
    return EncryptTask(
      taskId:  json['taskId'] as String,
      plaintext: Uint8List.fromList((json['plaintext'] as List).cast<int>()),
      sessionId:  Uint8List.fromList((json['sessionId'] as List).cast<int>()),
      messageNumber:  json['messageNumber'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
    );
  }
}

/// Decryption task
final class DecryptTask {
  final String taskId;
  final Uint8List ciphertext;
  final Uint8List nonce;
  final Uint8List sessionId;
  final int messageNumber;
  final DateTime createdAt;

  DecryptTask({
    required this.taskId,
    required this.ciphertext,
    required this. nonce,
    required this.sessionId,
    required this.messageNumber,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'ciphertext': ciphertext.toList(),
        'nonce':  nonce.toList(),
        'sessionId': sessionId. toList(),
        'messageNumber': messageNumber,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory DecryptTask.fromJson(Map<String, dynamic> json) {
    return DecryptTask(
      taskId: json['taskId'] as String,
      ciphertext: Uint8List.fromList((json['ciphertext'] as List).cast<int>()),
      nonce: Uint8List.fromList((json['nonce'] as List).cast<int>()),
      sessionId:  Uint8List.fromList((json['sessionId'] as List).cast<int>()),
      messageNumber:  json['messageNumber'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
    );
  }
}

/// Encryption result
final class EncryptResult {
  final String taskId;
  final bool success;
  final Uint8List?  ciphertext;
  final Uint8List? nonce;
  final String? error;
  final Duration processingTime;

  const EncryptResult({
    required this.taskId,
    required this.success,
    this. ciphertext,
    this.nonce,
    this. error,
    required this.processingTime,
  });

  factory EncryptResult. success({
    required String taskId,
    required Uint8List ciphertext,
    required Uint8List nonce,
    required Duration processingTime,
  }) =>
      EncryptResult(
        taskId: taskId,
        success: true,
        ciphertext: ciphertext,
        nonce: nonce,
        processingTime: processingTime,
      );

  factory EncryptResult.failure({
    required String taskId,
    required String error,
    required Duration processingTime,
  }) =>
      EncryptResult(
        taskId: taskId,
        success: false,
        error:  error,
        processingTime: processingTime,
      );
}

/// Decryption result
final class DecryptResult {
  final String taskId;
  final bool success;
  final Uint8List? plaintext;
  final String? error;
  final Duration processingTime;

  const DecryptResult({
    required this.taskId,
    required this.success,
    this.plaintext,
    this.error,
    required this.processingTime,
  });

  factory DecryptResult. success({
    required String taskId,
    required Uint8List plaintext,
    required Duration processingTime,
  }) =>
      DecryptResult(
        taskId: taskId,
        success: true,
        plaintext: plaintext,
        processingTime: processingTime,
      );

  factory DecryptResult.failure({
    required String taskId,
    required String error,
    required Duration processingTime,
  }) =>
      DecryptResult(
        taskId: taskId,
        success: false,
        error: error,
        processingTime:  processingTime,
      );
}