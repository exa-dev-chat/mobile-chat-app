class MessageModel {
  final int id;
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
    return MessageModel(
      id: json['id'] as int? ?? 0,
      chatId: json['chat_id'] as int? ?? 0,
      senderId: json['sender_id'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      senderName: json['sender_name'] as String?,
      createdAt: json['created_at'] as String?,
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
      'sender_name': senderName,
      'created_at': createdAt,
      'is_read': isRead,
    };
  }
}
