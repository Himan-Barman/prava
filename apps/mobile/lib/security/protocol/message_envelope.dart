// Message envelope
import 'dart:convert';
import 'dart:typed_data';

/// ============================================================
/// Message Envelope
/// ============================================================
/// Wire format for encrypted messages. 
/// ============================================================

/// Message types
enum MessageType {
  /// Regular encrypted message
  message,

  /// Pre-key message (session initiation)
  preKeyMessage,

  /// Sender key distribution
  senderKeyDistribution,

  /// Sender key message (group)
  senderKeyMessage,

  /// Receipt (delivered/read)
  receipt,

  /// Typing indicator
  typing,
}

/// Message envelope for wire transmission
final class MessageEnvelope {
  /// Protocol version
  static const int protocolVersion = 1;

  /// Message type
  final MessageType type;

  /// Sender device ID
  final String senderDeviceId;

  /// Recipient device ID (null for group messages)
  final String? recipientDeviceId;

  /// Encrypted content
  final Uint8List content;

  /// Timestamp
  final int timestamp;

  /// Message ID
  final String messageId;

  const MessageEnvelope({
    required this. type,
    required this.senderDeviceId,
    this.recipientDeviceId,
    required this.content,
    required this.timestamp,
    required this.messageId,
  });

  /// Serialize to bytes
  Uint8List toBytes() {
    final json = toJson();
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }

  /// Deserialize from bytes
  factory MessageEnvelope. fromBytes(Uint8List bytes) {
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return MessageEnvelope. fromJson(json);
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() => {
        'version': protocolVersion,
        'type':  type.index,
        'senderDeviceId':  senderDeviceId,
        'recipientDeviceId':  recipientDeviceId,
        'content': base64Encode(content),
        'timestamp':  timestamp,
        'messageId': messageId,
      };

  /// Deserialize from JSON
  factory MessageEnvelope. fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int?  ?? 1;
    if (version > protocolVersion) {
      throw UnsupportedError('Unsupported protocol version:  $version');
    }

    return MessageEnvelope(
      type: MessageType.values[json['type'] as int],
      senderDeviceId: json['senderDeviceId'] as String,
      recipientDeviceId: json['recipientDeviceId'] as String?,
      content: base64Decode(json['content'] as String),
      timestamp: json['timestamp'] as int,
      messageId: json['messageId'] as String,
    );
  }

  /// Create regular message envelope
  factory MessageEnvelope. message({
    required String senderDeviceId,
    required String recipientDeviceId,
    required Uint8List content,
    required String messageId,
  }) {
    return MessageEnvelope(
      type: MessageType.message,
      senderDeviceId: senderDeviceId,
      recipientDeviceId: recipientDeviceId,
      content: content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      messageId: messageId,
    );
  }

  /// Create pre-key message envelope
  factory MessageEnvelope.preKeyMessage({
    required String senderDeviceId,
    required String recipientDeviceId,
    required Uint8List content,
    required String messageId,
  }) {
    return MessageEnvelope(
      type: MessageType.preKeyMessage,
      senderDeviceId: senderDeviceId,
      recipientDeviceId: recipientDeviceId,
      content: content,
      timestamp: DateTime. now().millisecondsSinceEpoch,
      messageId: messageId,
    );
  }

  /// Create sender key message envelope
  factory MessageEnvelope.senderKeyMessage({
    required String senderDeviceId,
    required Uint8List content,
    required String messageId,
  }) {
    return MessageEnvelope(
      type: MessageType.senderKeyMessage,
      senderDeviceId: senderDeviceId,
      content: content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      messageId: messageId,
    );
  }

  @override
  String toString() => 'MessageEnvelope(type:  $type, id: $messageId)';
}