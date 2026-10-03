enum CallState { idle, calling, incoming, connected, ended }
enum CallType { audio, video }

class CallSessionModel {
  final String callId;
  final int targetUserId;
  final String targetUserName;
  final CallType callType;
  final bool isCaller;
  final int? chatId;
  CallState state;
  int duration; // in seconds
  String? endReason;

  CallSessionModel({
    required this.callId,
    required this.targetUserId,
    required this.targetUserName,
    required this.callType,
    required this.isCaller,
    this.chatId,
    this.state = CallState.idle,
    this.duration = 0,
    this.endReason,
  });

  String get formattedDuration {
    final mins = (duration ~/ 60).toString().padLeft(2, '0');
    final secs = (duration % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String get statusDisplay {
    switch (state) {
      case CallState.calling:
        return isCaller ? 'Memanggil...' : 'Panggilan Masuk...';
      case CallState.incoming:
        return 'Panggilan Masuk...';
      case CallState.connected:
        return formattedDuration;
      case CallState.ended:
        if (endReason == 'busy') return 'Pengguna sedang sibuk';
        if (endReason == 'declined') return 'Panggilan ditolak';
        if (endReason == 'canceled') return 'Panggilan dibatalkan';
        if (endReason == 'missed') return 'Panggilan tidak terjawab';
        if (endReason == 'failed') return 'Panggilan gagal terhubung';
        if (duration > 0) return 'Panggilan berakhir • $formattedDuration';
        return 'Panggilan berakhir';
      default:
        return 'Menghubungkan...';
    }
  }
}
