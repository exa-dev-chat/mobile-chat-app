import 'message_model.dart';

class ChatRoomModel {
  final int id;
  final int? userId;
  final String type; // 'direct' or 'group'
  final String? name;
  final String? avatar;
  final String? lastMessagePreview;
  final String? updatedAt;
  final int unreadCount;
  final MessageModel? lastMessage;

  ChatRoomModel({
    required this.id,
    this.userId,
    this.type = 'direct',
    this.name,
    this.avatar,
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
      id: (json['id'] is int ? json['id'] : int.tryParse('${json['id']}')) ?? 0,
      userId: json['user_id'] is int ? json['user_id'] as int : int.tryParse('${json['user_id']}'),
      type: json['type'] as String? ?? 'direct',
      name: json['name'] as String?,
      avatar: json['avatar'] as String?,
      lastMessagePreview: preview ?? json['last_message_content'] as String?,
      updatedAt: (json['last_message_at'] ?? json['updated_at'] ?? json['created_at']) as String?,
      unreadCount: (json['unread_count'] is int ? json['unread_count'] : int.tryParse('${json['unread_count']}')) ?? 0,
      lastMessage: lastMsg,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'name': name,
      'avatar': avatar,
      'last_message_preview': lastMessagePreview,
      'updated_at': updatedAt,
      'unread_count': unreadCount,
    };
  }
}
