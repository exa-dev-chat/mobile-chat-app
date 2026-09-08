import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/upload_service.dart';
import '../../../core/services/voice_recorder_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../../routes/app_routes.dart';
import '../../call/controllers/call_controller.dart';
import '../../call/models/call_log_model.dart';
import '../../call/models/call_session_model.dart';
import '../models/chat_room_model.dart';
import '../models/message_model.dart';
import '../repositories/chat_repository.dart';

class ChatController extends GetxController {
  final ChatRepository repository;
  final StorageService storageService;
  final WebSocketService wsService;
  final UploadService uploadService;
  final VoiceRecorderService voiceRecorderService;

  ChatController({
    required this.repository,
    required this.storageService,
    required this.wsService,
    required this.uploadService,
    required this.voiceRecorderService,
  });

  // Reactive State
  final chats = <ChatRoomModel>[].obs;
  final activeChat = Rxn<ChatRoomModel>();
  final messages = <MessageModel>[].obs;

  final isLoadingChats = false.obs;
  final isLoadingMessages = false.obs;
  final isSendingMessage = false.obs;
  final isUploadingMedia = false.obs;
  final isOtherUserTyping = false.obs;
  final searchQuery = ''.obs;
  final onlineUsers = <int>{}.obs;
  final incomingRequestCount = 0.obs;

  // Controllers
  final messageInputController = TextEditingController();
  final searchController = TextEditingController();
  final messageScrollController = ScrollController();
  final hasInputText = false.obs;

  final _imagePicker = ImagePicker();
  Timer? _typingResetTimer;
  StreamSubscription? _msgSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _presenceSub;

  int get currentUserId {
    final profile = storageService.userProfile;
    if (profile != null && profile['id'] != null) {
      return profile['id'] as int;
    }
    return 0;
  }

  @override
  void onInit() {
    super.onInit();
    messageInputController.addListener(_onInputTextChanged);
    loadChats();
    _initWebSocket();
  }

  void _onInputTextChanged() {
    final has = messageInputController.text.trim().isNotEmpty;
    if (hasInputText.value != has) {
      hasInputText.value = has;
    }
  }

  void _initWebSocket() {
    wsService.connect();

    _msgSub = wsService.onMessage.listen((event) {
      final msgData = event['data'] ?? event;
      if (msgData is Map) {
        final chatId = msgData['chat_id'] is int
            ? msgData['chat_id'] as int
            : int.tryParse('${msgData['chat_id']}');
        if (chatId != null && activeChat.value?.id == chatId) {
          final newMsg = MessageModel.fromJson(Map<String, dynamic>.from(msgData));
          final newId = newMsg.id;

          // Avoid duplicate insertion
          final isDuplicate = messages.any((m) {
            if (newId.isNotEmpty && m.id.isNotEmpty && m.id == newId) return true;
            if (m.content == newMsg.content &&
                m.senderId == newMsg.senderId &&
                m.createdAt == newMsg.createdAt) {
              return true;
            }
            if (isCallLog(m.content) && isCallLog(newMsg.content)) {
              final log1 = parseCallLog(m.content);
              final log2 = parseCallLog(newMsg.content);
              if (log1 != null && log2 != null && log1.callId.isNotEmpty && log1.callId == log2.callId) {
                return true;
              }
            }
            return false;
          });

          if (!isDuplicate) {
            messages.insert(0, newMsg);
            _scrollToBottom();
          }
        }
      }
    });

    _typingSub = wsService.onTyping.listen((event) {
      final data = event['data'] as Map<String, dynamic>?;
      if (data != null) {
        final chatId = data['chat_id'] as int?;
        final senderId = data['user_id'] as int?;
        if (chatId == activeChat.value?.id && senderId != currentUserId) {
          isOtherUserTyping.value = true;
          _typingResetTimer?.cancel();
          _typingResetTimer = Timer(const Duration(seconds: 3), () {
            isOtherUserTyping.value = false;
          });
        }
      }
    });

    _presenceSub = wsService.onPresence.listen((event) {
      final type = event['type'] as String?;
      final data = event['data'] as Map<String, dynamic>?;
      final userId = data?['user_id'] as int?;

      if (userId != null) {
        if (type == 'user_online') {
          onlineUsers.add(userId);
        } else if (type == 'user_offline') {
          onlineUsers.remove(userId);
        }
      }
    });
  }

  Future<void> loadChats() async {
    try {
      isLoadingChats.value = true;
      final result = await repository.getChats(search: searchQuery.value);
      chats.assignAll(result);
      LoggerService.i('Loaded ${result.length} chats', tag: 'ChatController');

      // Also refresh incoming request badge count
      try {
        final res = await repository.apiClient.get(ApiEndpoints.chatRequestsCount);
        if (res.data is Map && res.data['data'] is Map) {
          incomingRequestCount.value = (res.data['data']['received_count'] as int?) ?? 0;
        }
      } catch (_) {}
    } catch (e) {
      LoggerService.e('Failed to load chats: $e', tag: 'ChatController');
    } finally {
      isLoadingChats.value = false;
    }
  }

  void selectChat(ChatRoomModel chat, {required bool isWideScreen}) {
    // Leave previous chat channel
    if (activeChat.value != null) {
      wsService.leaveChat(activeChat.value!.id);
    }

    activeChat.value = chat;
    messageInputController.clear();
    hasInputText.value = false;
    wsService.joinChat(chat.id);
    loadMessages(chat.id);

    if (!isWideScreen) {
      Get.toNamed(Routes.chatDetail);
    }
  }

  Future<void> loadMessages(int chatId) async {
    try {
      isLoadingMessages.value = true;
      messages.clear();
      final result = await repository.getMessages(chatId);
      // Sort newest-first (index 0) so bottom-to-top rendering (reverse: true) shows newest at bottom
      result.sort((a, b) {
        final dateA = DateTime.tryParse(a.createdAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(b.createdAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
      messages.assignAll(result);
      _scrollToBottom();
    } catch (e) {
      LoggerService.e('Failed to load messages: $e', tag: 'ChatController');
    } finally {
      isLoadingMessages.value = false;
    }
  }

  void notifyTyping() {
    final chat = activeChat.value;
    if (chat != null) {
      wsService.sendTyping(chat.id);
    }
  }

  Future<void> sendMessage({String type = 'text', String? customContent}) async {
    final text = customContent ?? messageInputController.text.trim();
    final chat = activeChat.value;

    if (text.isEmpty || chat == null) return;

    try {
      isSendingMessage.value = true;
      if (customContent == null) {
        messageInputController.clear();
      }

      final sentMessage = await repository.sendMessage(
        chatId: chat.id,
        content: text,
        messageType: type,
      );

      final isDuplicate = messages.any((m) {
        if (sentMessage.id.isNotEmpty && m.id.isNotEmpty && m.id == sentMessage.id) return true;
        if (isCallLog(m.content) && isCallLog(sentMessage.content)) {
          final log1 = parseCallLog(m.content);
          final log2 = parseCallLog(sentMessage.content);
          if (log1 != null && log2 != null && log1.callId.isNotEmpty && log1.callId == log2.callId) {
            return true;
          }
        }
        return false;
      });

      if (!isDuplicate) {
        messages.insert(0, sentMessage);
      }
      _scrollToBottom();
    } catch (e) {
      LoggerService.e('Failed to send message: $e', tag: 'ChatController');
      SnackbarService.error('Gagal mengirim pesan.');
    } finally {
      isSendingMessage.value = false;
    }
  }

  // Voice Note Recording Flow
  Future<void> startVoiceRecording() async {
    await voiceRecorderService.startRecording();
  }

  Future<void> cancelVoiceRecording() async {
    await voiceRecorderService.cancelRecording();
  }

  Future<void> stopAndSendVoiceNote() async {
    final path = await voiceRecorderService.stopRecording();
    if (path == null) {
      SnackbarService.warning('Pesan suara terlalu singkat.');
      return;
    }

    try {
      isUploadingMedia.value = true;
      final fileUrl = await uploadService.uploadFile(filePath: path);
      if (fileUrl != null) {
        await sendMessage(type: 'audio', customContent: fileUrl);
      } else {
        SnackbarService.error('Gagal mengunggah pesan suara.');
      }
    } finally {
      isUploadingMedia.value = false;
    }
  }

  // Image & File Sharing Flow
  Future<void> pickAndSendImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    try {
      isUploadingMedia.value = true;
      final fileUrl = await uploadService.uploadFile(filePath: picked.path);
      if (fileUrl != null) {
        await sendMessage(type: 'image', customContent: fileUrl);
      } else {
        SnackbarService.error('Gagal mengunggah gambar.');
      }
    } finally {
      isUploadingMedia.value = false;
    }
  }

  Future<void> pickAndSendFile() async {
    final result = await FilePicker.pickFiles();
    final path = result.firstOrNull?.path;
    if (path == null) return;

    try {
      isUploadingMedia.value = true;
      final fileUrl = await uploadService.uploadFile(filePath: path);
      if (fileUrl != null) {
        await sendMessage(type: 'file', customContent: fileUrl);
      } else {
        SnackbarService.error('Gagal mengunggah berkas.');
      }
    } finally {
      isUploadingMedia.value = false;
    }
  }

  // WebRTC Call Initiation
  void startCall(CallType type) {
    final chat = activeChat.value;
    if (chat == null) return;

    // Resolve target user ID for call signaling:
    // 1. From chat.userId (for direct chat)
    // 2. Or from other participant's senderId in loaded messages
    int? targetId = chat.userId;
    if (targetId == null || targetId == currentUserId || targetId == 0) {
      final otherMsg = messages.firstWhereOrNull(
        (m) => m.senderId != currentUserId && m.senderId != 0,
      );
      if (otherMsg != null) {
        targetId = otherMsg.senderId;
      }
    }

    if (targetId == null || targetId == 0) {
      SnackbarService.warning('Pengguna tujuan tidak ditemukan untuk panggilan.');
      return;
    }

    final targetName = chat.name ?? 'Kontak';

    final callController = Get.find<CallController>();
    callController.startCall(
      targetUserId: targetId,
      targetUserName: targetName,
      callType: type,
      chatId: chat.id,
    );
  }

  void onSearchChanged(String value) {
    searchQuery.value = value.trim();
    loadChats();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messageScrollController.hasClients) {
        messageScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void onClose() {
    _msgSub?.cancel();
    _typingSub?.cancel();
    _presenceSub?.cancel();
    _typingResetTimer?.cancel();
    messageInputController.removeListener(_onInputTextChanged);
    messageInputController.dispose();
    searchController.dispose();
    messageScrollController.dispose();
    super.onClose();
  }
}
