class MessageModel {
  final String id;
  final int chatId;
  final int senderId;
  final String content;
  final String messageType;
  final String? senderName;
  final String? createdAt;
  final bool isRead;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    this.senderName,
    this.createdAt,
    this.isRead = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    String? senderName;
    if (json['sender'] is Map) {
      senderName = json['sender']['name'] as String?;
    } else if (json['sender_name'] is String) {
      senderName = json['sender_name'] as String;
    }

    final readAt = json['read_at'];
    final isRead = json['is_read'] == true || (readAt != null && readAt.toString().isNotEmpty);

    return MessageModel(
      id: json['id']?.toString() ?? '',
      chatId: (json['chat_id'] is int ? json['chat_id'] : int.tryParse('${json['chat_id']}')) ?? 0,
      senderId: (json['sender_id'] is int ? json['sender_id'] : int.tryParse('${json['sender_id']}')) ?? 0,
      content: json['content']?.toString() ?? '',
      messageType: json['type'] as String? ?? json['message_type'] as String? ?? 'text',
      senderName: senderName,
      createdAt: json['created_at']?.toString(),
      isRead: isRead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'type': messageType,
      'message_type': messageType,
      'sender_name': senderName,
      'created_at': createdAt,
      'is_read': isRead,
    };
  }
}

