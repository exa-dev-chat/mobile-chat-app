class ChatRequestIncoming {
  final int id;
  final int senderId;
  final int receiverId;
  final String status;
  final String createdAt;
  final String? message;
  final String senderName;
  final String senderEmail;
  final String? senderAvatar;
  final String? respondedAt;

  ChatRequestIncoming({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.message,
    required this.senderName,
    required this.senderEmail,
    this.senderAvatar,
    this.respondedAt,
  });

  factory ChatRequestIncoming.fromJson(Map<String, dynamic> json) {
    return ChatRequestIncoming(
      id: json['id'] as int? ?? 0,
      senderId: json['sender_id'] as int? ?? 0,
      receiverId: json['receiver_id'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String? ?? '',
      message: json['message'] as String?,
      senderName: json['sender_name'] as String? ?? 'Pengguna',
      senderEmail: json['sender_email'] as String? ?? '',
      senderAvatar: json['sender_avatar'] as String?,
      respondedAt: json['responded_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'status': status,
      'created_at': createdAt,
      'message': message,
      'sender_name': senderName,
      'sender_email': senderEmail,
      'sender_avatar': senderAvatar,
      'responded_at': respondedAt,
    };
  }
}

class ChatRequestOutgoing {
  final int id;
  final int senderId;
  final int receiverId;
  final String status;
  final String createdAt;
  final String? message;
  final String receiverName;
  final String receiverEmail;
  final String? receiverAvatar;
  final String? respondedAt;

  ChatRequestOutgoing({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.message,
    required this.receiverName,
    required this.receiverEmail,
    this.receiverAvatar,
    this.respondedAt,
  });

  factory ChatRequestOutgoing.fromJson(Map<String, dynamic> json) {
    return ChatRequestOutgoing(
      id: json['id'] as int? ?? 0,
      senderId: json['sender_id'] as int? ?? 0,
      receiverId: json['receiver_id'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String? ?? '',
      message: json['message'] as String?,
      receiverName: json['receiver_name'] as String? ?? 'Pengguna',
      receiverEmail: json['receiver_email'] as String? ?? '',
      receiverAvatar: json['receiver_avatar'] as String?,
      respondedAt: json['responded_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'status': status,
      'created_at': createdAt,
      'message': message,
      'receiver_name': receiverName,
      'receiver_email': receiverEmail,
      'receiver_avatar': receiverAvatar,
      'responded_at': respondedAt,
    };
  }
}

class ChatRequestCount {
  final int receivedCount;
  final int sentCount;

  ChatRequestCount({
    this.receivedCount = 0,
    this.sentCount = 0,
  });

  factory ChatRequestCount.fromJson(Map<String, dynamic> json) {
    return ChatRequestCount(
      receivedCount: json['received_count'] as int? ?? 0,
      sentCount: json['sent_count'] as int? ?? 0,
    );
  }
}
