class MessageModel {
  final String id;
  final int chatId;
  final int senderId;
  final String content;
  final String messageType;
  final String? senderName;
  final String? createdAt;
  final bool isRead;
  final MessageModel? replyTo;
  final List<String> reactions;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    this.senderName,
    this.createdAt,
    this.isRead = false,
    this.replyTo,
    this.reactions = const [],
  });

  MessageModel copyWith({
    String? id,
    int? chatId,
    int? senderId,
    String? content,
    String? messageType,
    String? senderName,
    String? createdAt,
    bool? isRead,
    MessageModel? replyTo,
    List<String>? reactions,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      senderName: senderName ?? this.senderName,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      replyTo: replyTo ?? this.replyTo,
      reactions: reactions ?? this.reactions,
    );
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    String? senderName;
    if (json['sender'] is Map) {
      senderName = json['sender']['name'] as String?;
    } else if (json['sender_name'] is String) {
      senderName = json['sender_name'] as String;
    }

    final readAt = json['read_at'];
    final isRead = json['is_read'] == true ||
        (readAt != null && readAt.toString().isNotEmpty && readAt.toString() != 'null');

    final rawId = json['id']?.toString() ?? json['message_id']?.toString() ?? '';

    final rawSenderId = json['sender_id'] ??
        json['user_id'] ??
        (json['sender'] is Map ? json['sender']['id'] : null);
    final senderId = rawSenderId is int
        ? rawSenderId
        : int.tryParse('$rawSenderId') ?? 0;

    final rawChatId = json['chat_id'];
    final chatId = rawChatId is int
        ? rawChatId
        : int.tryParse('$rawChatId') ?? 0;

    MessageModel? replyToMsg;
    if (json['reply_to'] is Map) {
      replyToMsg = MessageModel.fromJson(Map<String, dynamic>.from(json['reply_to']));
    }

    List<String> reactionsList = [];
    if (json['reactions'] is List) {
      reactionsList = (json['reactions'] as List).map((e) => e.toString()).toList();
    }

    return MessageModel(
      id: rawId,
      chatId: chatId,
      senderId: senderId,
      content: json['content']?.toString() ?? '',
      messageType: json['type'] as String? ?? json['message_type'] as String? ?? 'text',
      senderName: senderName,
      createdAt: json['created_at']?.toString(),
      isRead: isRead,
      replyTo: replyToMsg,
      reactions: reactionsList,
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
      if (replyTo != null) 'reply_to': replyTo!.toJson(),
      'reactions': reactions,
    };
  }
}
