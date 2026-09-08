enum CallState { idle, calling, incoming, connected, ended }
enum CallType { audio, video }

class CallSessionModel {
  final String callId;
  final int targetUserId;
  final String targetUserName;
  final CallType callType;
  final bool isCaller;
  CallState state;
  int duration; // in seconds

  CallSessionModel({
    required this.callId,
    required this.targetUserId,
    required this.targetUserName,
    required this.callType,
    required this.isCaller,
    this.state = CallState.idle,
    this.duration = 0,
  });

  String get formattedDuration {
    final mins = (duration ~/ 60).toString().padLeft(2, '0');
    final secs = (duration % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}
