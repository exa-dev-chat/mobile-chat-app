import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/upload_service.dart';
import '../../../core/services/voice_recorder_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../routes/app_routes.dart';
import '../../call/controllers/call_controller.dart';
import '../../call/models/call_log_model.dart';
import '../../call/models/call_session_model.dart';
import '../../auth/models/user_model.dart';
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
  final userLastSeen = <int, DateTime>{}.obs;
  final incomingRequestCount = 0.obs;
  final replyingMessage = Rxn<MessageModel>();
  final messageReactions = <String, List<String>>{}.obs;

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

  int get currentUserId => storageService.currentUserId;

  @override
  void onInit() {
    super.onInit();
    messageInputController.addListener(_onInputTextChanged);
    _ensureUserProfile();
    loadChats();
    _initWebSocket();
  }

  Future<void> _ensureUserProfile() async {
    if (storageService.currentUserId == 0 && storageService.isLoggedIn) {
      try {
        final response = await repository.apiClient.get(ApiEndpoints.me);
        final responseData = response.data;
        final data = responseData is Map && responseData['data'] != null
            ? responseData['data']
            : responseData;
        if (data is Map) {
          final user = UserModel.fromJson(Map<String, dynamic>.from(data));
          await storageService.saveUserProfile(user.toJson());
          LoggerService.i('ChatController resolved user profile, currentUserId = ${user.id}', tag: 'ChatController');
        }
      } catch (e) {
        LoggerService.w('ChatController could not fetch user profile: $e', tag: 'ChatController');
      }
    }
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
      final eventType = event['type'] as String?;
      final msgData = event['data'] ?? event;

      // Handle read receipt event broadcast from server
      if (eventType == 'read_messages') {
        if (msgData is Map) {
          final chatId = msgData['chat_id'] is int
              ? msgData['chat_id'] as int
              : int.tryParse('${msgData['chat_id']}');
          final readerId = msgData['user_id'] is int
              ? msgData['user_id'] as int
              : int.tryParse('${msgData['user_id']}');

          LoggerService.i(
            'Processing read_messages: chatId=$chatId, readerId=$readerId, currentUserId=$currentUserId, activeChatId=${activeChat.value?.id}',
            tag: 'ChatController',
          );

          // Update chat list item if applicable
          if (chatId != null) {
            final chatIndex = chats.indexWhere((c) => c.id == chatId);
            if (chatIndex != -1) {
              final c = chats[chatIndex];
              if (readerId == currentUserId) {
                chats[chatIndex] = c.copyWith(unreadCount: 0);
              } else if (c.lastMessage != null && !c.lastMessage!.isRead) {
                chats[chatIndex] = c.copyWith(
                  lastMessage: c.lastMessage!.copyWith(isRead: true),
                );
              }
            }
          }

          // If active chat is open, immediately mark sent messages as read (double checkmark)
          if (chatId != null && activeChat.value?.id == chatId) {
            final updated = messages.map((m) {
              final isSentByMe = m.senderId == currentUserId || (readerId != null && m.senderId != readerId);
              if (isSentByMe && !m.isRead) {
                return m.copyWith(isRead: true);
              }
              return m;
            }).toList();
            messages.assignAll(updated);
            messages.refresh();
            LoggerService.i('Marked ${updated.where((m) => m.isRead).length} messages as read for chatId=$chatId', tag: 'ChatController');
          }
        }
        return;
      }

      if (msgData is Map) {
        final chatId = msgData['chat_id'] is int
            ? msgData['chat_id'] as int
            : int.tryParse('${msgData['chat_id']}');
        if (chatId != null && activeChat.value?.id == chatId) {
          final newMsg = MessageModel.fromJson(Map<String, dynamic>.from(msgData));
          final newId = newMsg.id;

          // If incoming message is from opponent while chat is active, automatically mark as read
          if (newMsg.senderId != currentUserId && newMsg.senderId != 0) {
            markMessagesAsRead(chatId);
          }

          // Avoid duplicate insertion or replace optimistic local message
          final existingIndex = messages.indexWhere((m) {
            if (newId.isNotEmpty && m.id.isNotEmpty && m.id == newId) return true;
            if (m.content == newMsg.content &&
                m.senderId == newMsg.senderId &&
                (m.id.isEmpty || m.id == newId)) {
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

          if (existingIndex >= 0) {
            messages[existingIndex] = newMsg;
          } else {
            messages.insert(0, newMsg);
            _scrollToBottom();
          }

          if (newMsg.senderId != currentUserId) {
            onlineUsers.add(newMsg.senderId);
            userLastSeen[newMsg.senderId] = DateTime.now();
          }
        }
      }
    });

    _typingSub = wsService.onTyping.listen((event) {
      final data = event['data'] as Map<String, dynamic>?;
      if (data != null) {
        final chatId = data['chat_id'] as int?;
        final senderId = data['user_id'] as int?;
        if (senderId != null && senderId != currentUserId) {
          onlineUsers.add(senderId);
          userLastSeen[senderId] = DateTime.now();
        }
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
          final timestampStr = event['timestamp'] as String? ?? data?['last_seen'] as String?;
          final offlineTime = timestampStr != null
              ? DateTime.tryParse(timestampStr) ?? DateTime.now()
              : DateTime.now();
          userLastSeen[userId] = offlineTime;
          if (activeChat.value?.userId == userId) {
            activeChat.value = activeChat.value?.copyWith(lastSeen: offlineTime);
          }
        }
      }
    });
  }

  Future<void> loadChats() async {
    try {
      isLoadingChats.value = true;
      final result = await repository.getChats(search: searchQuery.value);
      chats.assignAll(result);

      for (final chat in result) {
        if (chat.userId != null && chat.lastSeen != null) {
          userLastSeen[chat.userId!] = chat.lastSeen!;
        }
      }

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

    if (chat.userId != null) {
      if (chat.lastSeen != null) {
        userLastSeen.putIfAbsent(chat.userId!, () => chat.lastSeen!);
      }
      final latestLastSeen = userLastSeen[chat.userId!] ?? chat.lastSeen;
      activeChat.value = chat.copyWith(lastSeen: latestLastSeen);
    } else {
      activeChat.value = chat;
    }

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

      // Automatically mark as read when entering the chat
      if (result.isNotEmpty) {
        markMessagesAsRead(chatId);
      }
    } catch (e) {
      LoggerService.e('Failed to load messages: $e', tag: 'ChatController');
    } finally {
      isLoadingMessages.value = false;
    }
  }

  Future<void> markMessagesAsRead(int chatId) async {
    try {
      await repository.markAsRead(chatId);
    } catch (e) {
      LoggerService.w('Failed to mark messages as read: $e', tag: 'ChatController');
    }
  }

  void notifyTyping() {
    final chat = activeChat.value;
    if (chat != null) {
      wsService.sendTyping(chat.id);
    }
  }

  void setReply(MessageModel message) {
    replyingMessage.value = message;
    AppHaptics.medium();
  }

  void clearReply() {
    replyingMessage.value = null;
    AppHaptics.light();
  }

  void toggleReaction(String messageId, String emoji) {
    AppHaptics.light();
    final list = List<String>.from(messageReactions[messageId] ?? []);
    if (list.contains(emoji)) {
      list.remove(emoji);
    } else {
      list.add(emoji);
    }
    if (list.isEmpty) {
      messageReactions.remove(messageId);
    } else {
      messageReactions[messageId] = list;
    }
  }

  Future<void> deleteMessage(MessageModel message) async {
    final chat = activeChat.value;
    if (chat == null) return;
    try {
      AppHaptics.heavy();
      final success = await repository.deleteMessage(message.id, chat.id);
      if (success) {
        messages.removeWhere((m) => m.id == message.id);
        SnackbarService.success('Pesan berhasil dihapus');
      } else {
        SnackbarService.error('Gagal menghapus pesan');
      }
    } catch (e) {
      SnackbarService.error('Terjadi kesalahan saat menghapus pesan');
    }
  }

  Future<void> deleteChat(ChatRoomModel chat) async {
    try {
      AppHaptics.heavy();
      final success = await repository.deleteChat(chat.id);
      if (success) {
        chats.removeWhere((c) => c.id == chat.id);
        if (activeChat.value?.id == chat.id) {
          activeChat.value = null;
        }
        SnackbarService.success('Obrolan berhasil dihapus');
      } else {
        SnackbarService.error('Gagal menghapus obrolan');
      }
    } catch (e) {
      SnackbarService.error('Terjadi kesalahan saat menghapus obrolan');
    }
  }

  Future<void> sendMessage({String type = 'text', String? customContent}) async {
    final text = customContent ?? messageInputController.text.trim();
    final chat = activeChat.value;

    if (text.isEmpty || chat == null) return;

    final currentReply = replyingMessage.value;
    replyingMessage.value = null;

    try {
      AppHaptics.light();
      isSendingMessage.value = true;
      if (customContent == null) {
        messageInputController.clear();
      }

      final rawSent = await repository.sendMessage(
        chatId: chat.id,
        content: text,
        messageType: type,
        currentUserId: currentUserId,
      );
      final sentMessage = rawSent.copyWith(replyTo: currentReply);

      final isDuplicate = messages.any((m) {
        if (sentMessage.id.isNotEmpty && m.id.isNotEmpty && m.id == sentMessage.id) return true;
        if (m.content == sentMessage.content &&
            m.senderId == sentMessage.senderId &&
            m.createdAt == sentMessage.createdAt) {
          return true;
        }
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
      loadChats();
    } catch (e) {
      LoggerService.e('Failed to send message: $e', tag: 'ChatController');
      SnackbarService.error('Gagal mengirim pesan.');
    } finally {
      isSendingMessage.value = false;
    }
  }

  // Voice Note Recording Flow
  Future<void> startVoiceRecording() async {
    final granted = await PermissionService.requestMicrophone(
      reason: 'merekam pesan suara',
    );
    if (!granted) return;
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
    if (source == ImageSource.camera) {
      final granted = await PermissionService.requestCamera(
        reason: 'mengambil foto langsung dari kamera',
      );
      if (!granted) return;
    }

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

    final ext = path.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif'].contains(ext);

    try {
      isUploadingMedia.value = true;
      final fileUrl = await uploadService.uploadFile(filePath: path);
      if (fileUrl != null) {
        await sendMessage(type: isImage ? 'image' : 'file', customContent: fileUrl);
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
      if (messageScrollController.hasClients &&
          messageScrollController.position.hasContentDimensions &&
          messageScrollController.offset > 10.0) {
        messageScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'Offline';

    final now = DateTime.now();
    final local = lastSeen.toLocal();
    final timeStr =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    final diff = now.difference(local);
    if (diff.inMinutes < 1) {
      return 'Terakhir online baru saja';
    }

    final isToday = now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;
    if (isToday) {
      return 'Terakhir online $timeStr';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == local.year &&
        yesterday.month == local.month &&
        yesterday.day == local.day;
    if (isYesterday) {
      return 'Terakhir online kemarin $timeStr';
    }

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final monthStr = months[local.month - 1];

    if (now.year == local.year) {
      return 'Terakhir online ${local.day} $monthStr $timeStr';
    }

    return 'Terakhir online ${local.day} $monthStr ${local.year} $timeStr';
  }

  String getChatStatusText(ChatRoomModel chat) {
    if (chat.type == 'group') return 'Grup';
    final isOnline = chat.userId != null && onlineUsers.contains(chat.userId);
    if (isOnline) return 'Online';

    final dt = chat.userId != null
        ? (userLastSeen[chat.userId] ?? chat.lastSeen)
        : chat.lastSeen;
    return formatLastSeen(dt);
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
