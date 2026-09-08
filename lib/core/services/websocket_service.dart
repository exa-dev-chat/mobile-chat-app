import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/app_constants.dart';
import 'logger_service.dart';
import 'storage_service.dart';

class WebSocketService extends GetxService {
  final StorageService storageService;

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isManualDisconnect = false;
  final isConnected = false.obs;

  // Stream broadcast controllers for events
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  final _callSignalingController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onPresence => _presenceController.stream;
  Stream<Map<String, dynamic>> get onCallSignaling => _callSignalingController.stream;

  WebSocketService({required this.storageService});

  String get _wsUrl {
    final wsBase = AppConstants.defaultWsUrl;
    final token = storageService.accessToken ?? '';
    final separator = wsBase.contains('?') ? '&' : '?';
    return '$wsBase${separator}token=$token';
  }

  void connect() {
    final token = storageService.accessToken;
    if (token == null || token.isEmpty) {
      LoggerService.w('WebSocket connect aborted: No access token', tag: 'WebSocketService');
      return;
    }

    _isManualDisconnect = false;
    _cleanupChannel();

    try {
      final uri = Uri.parse(_wsUrl);
      LoggerService.i('Connecting to WebSocket: ${uri.replace(queryParameters: {'token': '***'})}', tag: 'WebSocketService');

      _channel = WebSocketChannel.connect(uri);
      isConnected.value = true;
      _startHeartbeat();

      _channel?.stream.listen(
        _handleIncomingMessage,
        onError: (err) {
          LoggerService.e('WebSocket stream error: $err', tag: 'WebSocketService');
          _scheduleReconnect();
        },
        onDone: () {
          LoggerService.i('WebSocket stream closed', tag: 'WebSocketService');
          isConnected.value = false;
          _stopHeartbeat();
          if (!_isManualDisconnect) {
            _scheduleReconnect();
          }
        },
      );
    } catch (e) {
      LoggerService.e('WebSocket connection failed: $e', tag: 'WebSocketService');
      _scheduleReconnect();
    }
  }

  void _handleIncomingMessage(dynamic rawData) {
    try {
      final text = rawData.toString();
      final Map<String, dynamic> data = jsonDecode(text);
      final type = data['type'] as String? ?? '';

      LoggerService.d('WS received [$type]: $text', tag: 'WebSocketService');

      if (type == 'pong') {
        // Heartbeat ACK
        return;
      }

      if (type == 'user_online' || type == 'user_offline') {
        _presenceController.add(data);
      } else if (type == 'typing') {
        _typingController.add(data);
      } else if (type.startsWith('call:')) {
        _callSignalingController.add(data);
      } else if (type == 'new_message' || type == 'message') {
        _messageController.add(data);
      } else {
        // Other events (join_chat_success, system, etc.)
        _messageController.add(data);
      }
    } catch (e) {
      LoggerService.w('Failed to parse WebSocket message: $e', tag: 'WebSocketService');
    }
  }

  void send(Map<String, dynamic> payload) {
    if (_channel != null && isConnected.value) {
      try {
        final text = jsonEncode(payload);
        LoggerService.d('WS sending: $text', tag: 'WebSocketService');
        _channel?.sink.add(text);
      } catch (e) {
        LoggerService.e('Failed to send WebSocket payload: $e', tag: 'WebSocketService');
      }
    } else {
      LoggerService.w('WebSocket not connected. Dropping payload: $payload', tag: 'WebSocketService');
    }
  }

  // Chat actions
  void joinChat(int chatId) {
    send({'type': 'join_chat', 'chat_id': chatId});
  }

  void leaveChat(int chatId) {
    send({'type': 'leave_chat', 'chat_id': chatId});
  }

  void sendTyping(int chatId) {
    send({'type': 'typing', 'chat_id': chatId});
  }

  // WebRTC Call Signaling
  void sendCallSignaling({
    required String type,
    required int targetUserId,
    required Map<String, dynamic> data,
  }) {
    send({
      'type': type,
      'target_user_id': targetUserId,
      'data': data,
    });
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isConnected.value) {
        send({'type': 'ping'});
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _scheduleReconnect() {
    _stopHeartbeat();
    isConnected.value = false;
    _reconnectTimer?.cancel();

    if (_isManualDisconnect) return;

    LoggerService.i('Scheduling WebSocket reconnect in 5s...', tag: 'WebSocketService');
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isManualDisconnect && storageService.isLoggedIn) {
        connect();
      }
    });
  }

  void disconnect() {
    _isManualDisconnect = true;
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _cleanupChannel();
    isConnected.value = false;
    LoggerService.i('WebSocket disconnected manually', tag: 'WebSocketService');
  }

  void _cleanupChannel() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  @override
  void onClose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _presenceController.close();
    _callSignalingController.close();
    super.onClose();
  }
}
