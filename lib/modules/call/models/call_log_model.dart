import 'dart:convert';

class CallLogData {
  final int version;
  final String callId;
  final String callType; // 'audio' | 'video'
  final String status; // 'completed' | 'missed' | 'declined' | 'canceled'
  final int duration; // in seconds
  final int callerId;
  final String? callerName;
  final int receiverId;

  CallLogData({
    this.version = 1,
    required this.callId,
    required this.callType,
    required this.status,
    required this.duration,
    required this.callerId,
    this.callerName,
    required this.receiverId,
  });

  factory CallLogData.fromJson(Map<String, dynamic> json) {
    return CallLogData(
      version: (json['version'] is int ? json['version'] : int.tryParse('${json['version']}')) ?? 1,
      callId: json['call_id']?.toString() ?? '',
      callType: json['call_type']?.toString() ?? 'audio',
      status: json['status']?.toString() ?? 'missed',
      duration: (json['duration'] is int ? json['duration'] : int.tryParse('${json['duration']}')) ?? 0,
      callerId: (json['caller_id'] is int ? json['caller_id'] : int.tryParse('${json['caller_id']}')) ?? 0,
      callerName: json['caller_name'] as String?,
      receiverId: (json['receiver_id'] is int ? json['receiver_id'] : int.tryParse('${json['receiver_id']}')) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'call_id': callId,
      'call_type': callType,
      'status': status,
      'duration': duration,
      'caller_id': callerId,
      'caller_name': callerName,
      'receiver_id': receiverId,
    };
  }
}

const String callLogPrefix = 'CALL_LOG:';

bool isCallLog(String? content) {
  if (content == null || content.isEmpty) return false;
  return content.startsWith(callLogPrefix);
}

CallLogData? parseCallLog(String? content) {
  if (!isCallLog(content)) return null;
  try {
    final jsonStr = content!.substring(callLogPrefix.length);
    final decoded = jsonDecode(jsonStr);
    if (decoded is Map<String, dynamic>) {
      return CallLogData.fromJson(decoded);
    }
  } catch (_) {}
  return null;
}

String formatCallLogPayload({
  required String callId,
  required String callType,
  required String status,
  required int duration,
  required int callerId,
  String? callerName,
  required int receiverId,
}) {
  final data = CallLogData(
    version: 1,
    callId: callId,
    callType: callType,
    status: status,
    duration: duration,
    callerId: callerId,
    callerName: callerName,
    receiverId: receiverId,
  );
  return '$callLogPrefix${jsonEncode(data.toJson())}';
}

String formatCallDuration(int seconds) {
  if (seconds <= 0) return '00:00';
  final hrs = seconds ~/ 3600;
  final mins = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;

  String pad(int n) => n.toString().padLeft(2, '0');

  if (hrs > 0) {
    return '${pad(hrs)}:${pad(mins)}:${pad(secs)}';
  }
  return '${pad(mins)}:${pad(secs)}';
}

class CallLogDisplayInfo {
  final String title;
  final String subtitle;
  final String statusLabel;
  final bool isOutgoing;
  final bool isMissed;
  final bool isCompleted;
  final String callType;
  final String formattedDuration;

  CallLogDisplayInfo({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.isOutgoing,
    required this.isMissed,
    required this.isCompleted,
    required this.callType,
    required this.formattedDuration,
  });
}

CallLogDisplayInfo getCallLogDisplay(CallLogData data, int currentUserId) {
  final isOutgoing = currentUserId == data.callerId;
  final isCompleted = data.status == 'completed' && data.duration > 0;
  final formattedDuration = formatCallDuration(data.duration);
  final isVideo = data.callType == 'video';
  final title = isVideo ? 'Panggilan Video' : 'Panggilan Suara';

  String statusLabel = '';
  bool isMissed = false;

  if (isCompleted) {
    statusLabel = 'Berakhir • $formattedDuration';
  } else if (data.status == 'declined') {
    statusLabel = 'Panggilan Ditolak';
    isMissed = true;
  } else if (data.status == 'canceled') {
    statusLabel = isOutgoing ? 'Panggilan Dibatalkan' : 'Panggilan Tak Terjawab';
    isMissed = !isOutgoing;
  } else {
    // missed / unavailable / timeout
    statusLabel = isOutgoing ? 'Tidak Ada Jawaban' : 'Panggilan Tak Terjawab';
    isMissed = !isOutgoing;
  }

  final subtitle = isOutgoing ? 'Keluar • $statusLabel' : 'Masuk • $statusLabel';

  return CallLogDisplayInfo(
    title: title,
    subtitle: subtitle,
    statusLabel: statusLabel,
    isOutgoing: isOutgoing,
    isMissed: isMissed,
    isCompleted: isCompleted,
    callType: data.callType,
    formattedDuration: formattedDuration,
  );
}

String getCallLogPreviewText(String? content) {
  final data = parseCallLog(content);
  if (data == null) return 'Panggilan';

  final typeIcon = data.callType == 'video' ? '📹' : '📞';
  final typeText = data.callType == 'video' ? 'Panggilan Video' : 'Panggilan Suara';

  if (data.status == 'completed' && data.duration > 0) {
    return '$typeIcon $typeText (${formatCallDuration(data.duration)})';
  } else if (data.status == 'declined') {
    return '$typeIcon $typeText Ditolak';
  } else if (data.status == 'canceled') {
    return '$typeIcon $typeText Dibatalkan';
  } else {
    return '$typeIcon $typeText Tak Terjawab';
  }
}
