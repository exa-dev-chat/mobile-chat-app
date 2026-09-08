import 'message_model.dart';

class ChatRoomModel {
  final int id;
  final String type; // 'direct' or 'group'
  final String? name;
  final String? lastMessagePreview;
  final String? updatedAt;
  final int unreadCount;
  final MessageModel? lastMessage;

  ChatRoomModel({
    required this.id,
    this.type = 'direct',
    this.name,
    this.lastMessagePreview,
    this.updatedAt,
    this.unreadCount = 0,
    this.lastMessage,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    MessageModel? lastMsg;
    String? preview;

    if (json['last_message'] != null) {
      if (json['last_message'] is Map) {
        lastMsg = MessageModel.fromJson(
          Map<String, dynamic>.from(json['last_message'] as Map),
        );
        preview = lastMsg.content;
      } else if (json['last_message'] is String) {
        preview = json['last_message'] as String;
      }
    }

    return ChatRoomModel(
      id: json['id'] as int? ?? 0,
      type: json['type'] as String? ?? 'direct',
      name: json['name'] as String?,
      lastMessagePreview: preview ?? json['last_message_content'] as String?,
      updatedAt: json['updated_at'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
      lastMessage: lastMsg,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'last_message_preview': lastMessagePreview,
      'updated_at': updatedAt,
      'unread_count': unreadCount,
    };
  }
}
