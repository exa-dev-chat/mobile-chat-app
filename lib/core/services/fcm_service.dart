import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../network/api_client.dart';
import 'logger_service.dart';
import 'storage_service.dart';
import '../../modules/call/controllers/call_controller.dart';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  LoggerService.i(
    'FCM Background message received: ${message.data}',
    tag: 'FCMBackground',
  );

  final type = message.data['type'] as String? ?? '';
  if (type == 'incoming_call') {
    // Show high priority local notification for incoming call in background
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidDetails = AndroidNotificationDetails(
      'incoming_calls',
      'Panggilan Masuk',
      channelDescription: 'Notifikasi panggilan suara dan video',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    final callerName = message.data['caller_name'] as String? ?? 'Pengguna';
    final mediaType = message.data['media_type'] as String? ?? 'audio';
    final callId = message.data['call_id'] as String? ?? '0';

    await flutterLocalNotificationsPlugin.show(
      id: callId.hashCode,
      title: 'Panggilan Masuk ($mediaType)',
      body: 'Panggilan dari $callerName',
      notificationDetails: notificationDetails,
      payload: jsonEncode(message.data),
    );
  } else if (type == 'call_dismiss') {
    final callId = message.data['call_id'] as String? ?? '';
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    if (callId.isNotEmpty) {
      await flutterLocalNotificationsPlugin.cancel(id: callId.hashCode);
    }
  }
}

class FcmService extends GetxService {
  static FcmService get to => Get.find<FcmService>();

  final StorageService storageService;
  final ApiClient apiClient;

  FcmService({
    required this.storageService,
    required this.apiClient,
  });

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isFirebaseAvailable = false;
  String? _currentToken;

  String? get currentToken => _currentToken;
  bool get isAvailable => _isFirebaseAvailable;

  Future<FcmService> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _isFirebaseAvailable = true;
      LoggerService.i('Firebase initialized successfully in Flutter', tag: 'FcmService');
    } catch (e) {
      LoggerService.w(
        'Firebase not configured yet in Flutter (mock/fallback mode): $e',
        tag: 'FcmService',
      );
      _isFirebaseAvailable = false;
      return this;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _initLocalNotifications();
      await _requestPermissions();
      _setupMessageListeners();
      await _fetchAndSyncToken();
    } catch (e) {
      LoggerService.e('Error setting up FCM service: $e', tag: 'FcmService');
    }

    return this;
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _handleNotificationClick,
    );

    // Create Android Notification Channels
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      // 1. Chat Messages Channel
      const chatChannel = AndroidNotificationChannel(
        'chat_messages',
        'Pesan Obrolan',
        description: 'Notifikasi pesan baru',
        importance: Importance.high,
        playSound: true,
      );
      await androidImplementation.createNotificationChannel(chatChannel);

      // 2. Incoming Calls Channel
      const callChannel = AndroidNotificationChannel(
        'incoming_calls',
        'Panggilan Masuk',
        description: 'Notifikasi panggilan masuk',
        importance: Importance.max,
        playSound: true,
      );
      await androidImplementation.createNotificationChannel(callChannel);
    }
  }

  Future<void> _requestPermissions() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    LoggerService.i(
      'FCM Permission status: ${settings.authorizationStatus}',
      tag: 'FcmService',
    );
  }

  void _setupMessageListeners() {
    // 1. Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      LoggerService.i(
        'Foreground FCM received: ${message.data}',
        tag: 'FcmService',
      );
      _handleMessageData(message.data, isForeground: true);
    });

    // 2. When notification is tapped while app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      LoggerService.i(
        'FCM clicked from background: ${message.data}',
        tag: 'FcmService',
      );
      _handleMessageData(message.data, isForeground: false);
    });

    // 3. Token refresh listener
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      LoggerService.i('FCM Token refreshed: $newToken', tag: 'FcmService');
      _currentToken = newToken;
      storageService.saveFcmToken(newToken);
      syncTokenWithBackend();
    });
  }

  Future<void> _fetchAndSyncToken() async {
    try {
      _currentToken = await FirebaseMessaging.instance.getToken();
      if (_currentToken != null && _currentToken!.isNotEmpty) {
        LoggerService.i('FCM Token acquired: $_currentToken', tag: 'FcmService');
        await storageService.saveFcmToken(_currentToken!);
        await syncTokenWithBackend();
      }
    } catch (e) {
      LoggerService.w('Could not fetch FCM token: $e', tag: 'FcmService');
    }
  }

  /// Sync device token to backend if user is logged in
  Future<void> syncTokenWithBackend() async {
    final token = _currentToken ?? storageService.fcmToken;
    if (token == null || token.isEmpty || !storageService.isLoggedIn) {
      return;
    }

    try {
      await apiClient.post(
        '/api/users/fcm-token',
        data: {
          'token': token,
          'device_type': 'android',
        },
      );
      LoggerService.i('FCM token synced with backend', tag: 'FcmService');
    } catch (e) {
      LoggerService.w('Failed to sync FCM token with backend: $e', tag: 'FcmService');
    }
  }

  /// Remove device token from backend upon logout
  Future<void> removeTokenFromBackend() async {
    final token = _currentToken ?? storageService.fcmToken;
    if (token == null || token.isEmpty || !storageService.isLoggedIn) {
      return;
    }

    try {
      await apiClient.delete(
        '/api/users/fcm-token',
        data: {
          'token': token,
        },
      );
      await storageService.clearFcmToken();
      LoggerService.i('FCM token removed from backend on logout', tag: 'FcmService');
    } catch (e) {
      LoggerService.w('Failed to remove FCM token from backend: $e', tag: 'FcmService');
    }
  }

  void _handleMessageData(Map<String, dynamic> data, {required bool isForeground}) {
    final type = data['type'] as String? ?? '';

    if (type == 'incoming_call') {
      final callId = data['call_id'] as String? ?? '';
      final callerId = int.tryParse(data['caller_id']?.toString() ?? '0') ?? 0;
      final callerName = data['caller_name'] as String? ?? 'Pengguna';
      final mediaType = data['media_type'] as String? ?? 'audio';
      final sdpOffer = data['sdp_offer'] as String?;

      if (Get.isRegistered<CallController>()) {
        final callController = Get.find<CallController>();
        callController.handleIncomingCallFromFCM(
          callId: callId,
          callerId: callerId,
          callerName: callerName,
          mediaType: mediaType,
          sdpOffer: sdpOffer,
        );
      }
    } else if (type == 'call_dismiss') {
      final callId = data['call_id'] as String? ?? '';
      _localNotifications.cancel(id: callId.hashCode);
      if (Get.isRegistered<CallController>()) {
        Get.find<CallController>().handleCallDismissFromFCM(callId);
      }
    } else if (type == 'chat_message') {
      final senderName = data['sender_name'] as String? ?? 'Pesan Baru';
      final chatId = data['chat_id'] as String? ?? '';
      final messageType = data['message_type'] as String? ?? 'text';

      String content = 'Mengirim pesan';
      if (messageType == 'audio') {
        content = '🎤 Pesan Suara';
      } else if (messageType == 'image') {
        content = '📷 Foto';
      }

      _showChatNotification(
        id: chatId.hashCode,
        title: senderName,
        body: content,
        payload: jsonEncode(data),
      );
    }
  }

  Future<void> _showChatNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Pesan Obrolan',
      channelDescription: 'Notifikasi pesan baru',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  void _handleNotificationClick(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _handleMessageData(data, isForeground: false);
    } catch (_) {}
  }
}
