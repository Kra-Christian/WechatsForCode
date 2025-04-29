import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  emoji,
  audio,
}

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.type,
    required this.timestamp,
    required this.isRead,
  });

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  factory MessageModel.fromMap(Map<String, dynamic> data) {
    MessageType messageType;
    if (data['type'] is String) {
      try {
        int typeIndex = int.parse(data['type']);
        messageType = MessageType.values[typeIndex];
      } catch (e) {
        messageType = MessageType.text;
      }
    } else {
      messageType = MessageType.values[data['type'] ?? 0];
    }

    return MessageModel(
      id: data['id'] ?? '',
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      content: data['content'] ?? '',
      type: messageType,
      timestamp: data['timestamp'] != null 
        ? (data['timestamp'] is Timestamp 
            ? (data['timestamp'] as Timestamp).toDate() 
            : DateTime.parse(data['timestamp'].toString()))
        : DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'type': type.index,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }
}

class ChatModel {
  final String id;
  final List<String> participants;
  final MessageModel lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, bool> typing;
  final List<String> mutedBy;
  final List<String> blockedBy;

  ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.updatedAt,
    DateTime? createdAt,
    this.typing = const {},
    this.mutedBy = const [],
    this.blockedBy = const [],
  }) : this.createdAt = createdAt ?? updatedAt;

  factory ChatModel.fromMap(Map<String, dynamic> data, MessageModel lastMsg) {
    Map<String, bool> typingMap = {};
    if (data['typing'] != null) {
      (data['typing'] as Map<String, dynamic>).forEach((key, value) {
        typingMap[key] = value as bool;
      });
    }

    return ChatModel(
      id: data['id'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: lastMsg,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] is Timestamp 
              ? (data['createdAt'] as Timestamp).toDate() 
              : DateTime.parse(data['createdAt'].toString()))
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] is Timestamp 
              ? (data['updatedAt'] as Timestamp).toDate() 
              : DateTime.parse(data['updatedAt'].toString()))
          : DateTime.now(),
      typing: typingMap,
      mutedBy: List<String>.from(data['mutedBy'] ?? []),
      blockedBy: List<String>.from(data['blockedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participants': participants,
      'lastMessageId': lastMessage.id,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'typing': typing,
      'mutedBy': mutedBy,
      'blockedBy': blockedBy,
    };
  }

  bool isMuted(String userId) {
    return mutedBy.contains(userId);
  }

  bool isBlocked(String userId) {
    return blockedBy.contains(userId);
  }

  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere((id) => id != currentUserId);
  }
}
