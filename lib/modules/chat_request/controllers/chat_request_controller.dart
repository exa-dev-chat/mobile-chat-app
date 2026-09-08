import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/snackbar_service.dart';
import '../../chat/controllers/chat_controller.dart';
import '../models/chat_request_model.dart';
import '../repositories/chat_request_repository.dart';

class ChatRequestController extends GetxController with GetSingleTickerProviderStateMixin {
  final ChatRequestRepository repository;

  ChatRequestController({required this.repository});

  late TabController tabController;

  final incomingList = <ChatRequestIncoming>[].obs;
  final outgoingList = <ChatRequestOutgoing>[].obs;
  final counts = ChatRequestCount().obs;

  final isLoading = false.obs;
  final isSubmitting = false.obs;

  // Controllers for send tab
  final emailController = TextEditingController();
  final messageController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 3, vsync: this);
    refreshAll();
  }

  @override
  void onClose() {
    tabController.dispose();
    emailController.dispose();
    messageController.dispose();
    super.onClose();
  }

  Future<void> refreshAll() async {
    isLoading.value = true;
    try {
      await Future.wait([
        loadIncoming(),
        loadOutgoing(),
        loadCounts(),
      ]);
    } catch (e) {
      LoggerService.e('Failed to load chat requests', error: e, tag: 'ChatRequestController');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadIncoming() async {
    try {
      final items = await repository.getIncomingRequests();
      incomingList.assignAll(items);
    } catch (e) {
      LoggerService.e('Error fetching incoming chat requests', error: e, tag: 'ChatRequestController');
    }
  }

  Future<void> loadOutgoing() async {
    try {
      final items = await repository.getOutgoingRequests();
      outgoingList.assignAll(items);
    } catch (e) {
      LoggerService.e('Error fetching outgoing chat requests', error: e, tag: 'ChatRequestController');
    }
  }

  Future<void> loadCounts() async {
    try {
      final countData = await repository.getRequestCount();
      counts.value = countData;
    } catch (e) {
      LoggerService.e('Error fetching chat request counts', error: e, tag: 'ChatRequestController');
    }
  }

  Future<void> acceptRequest(int id) async {
    try {
      isSubmitting.value = true;
      final success = await repository.acceptRequest(id);
      if (success) {
        incomingList.removeWhere((item) => item.id == id);
        counts.value = ChatRequestCount(
          receivedCount: (counts.value.receivedCount - 1).clamp(0, 999),
          sentCount: counts.value.sentCount,
        );
        SnackbarService.success('Permintaan obrolan diterima! Obrolan baru telah dibuat.');
        
        // Refresh chat list if ChatController is registered
        if (Get.isRegistered<ChatController>()) {
          Get.find<ChatController>().loadChats();
        }
      } else {
        SnackbarService.error('Gagal menerima permintaan obrolan.');
      }
    } catch (e) {
      LoggerService.e('Error accepting chat request', error: e, tag: 'ChatRequestController');
      SnackbarService.error('Terjadi kesalahan saat menerima permintaan.');
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> rejectRequest(int id) async {
    try {
      isSubmitting.value = true;
      final success = await repository.rejectRequest(id);
      if (success) {
        incomingList.removeWhere((item) => item.id == id);
        counts.value = ChatRequestCount(
          receivedCount: (counts.value.receivedCount - 1).clamp(0, 999),
          sentCount: counts.value.sentCount,
        );
        SnackbarService.info('Permintaan obrolan ditolak.');
      } else {
        SnackbarService.error('Gagal menolak permintaan obrolan.');
      }
    } catch (e) {
      LoggerService.e('Error rejecting chat request', error: e, tag: 'ChatRequestController');
      SnackbarService.error('Terjadi kesalahan saat menolak permintaan.');
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> cancelRequest(int id) async {
    try {
      isSubmitting.value = true;
      final success = await repository.cancelRequest(id);
      if (success) {
        outgoingList.removeWhere((item) => item.id == id);
        counts.value = ChatRequestCount(
          receivedCount: counts.value.receivedCount,
          sentCount: (counts.value.sentCount - 1).clamp(0, 999),
        );
        SnackbarService.info('Permintaan obrolan berhasil dibatalkan.');
      } else {
        SnackbarService.error('Gagal membatalkan permintaan obrolan.');
      }
    } catch (e) {
      LoggerService.e('Error canceling chat request', error: e, tag: 'ChatRequestController');
      SnackbarService.error('Terjadi kesalahan saat membatalkan permintaan.');
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> sendRequest() async {
    final email = emailController.text.trim();
    final message = messageController.text.trim();

    if (email.isEmpty) {
      SnackbarService.warning('Silakan masukkan email penerima.');
      return;
    }

    if (!GetUtils.isEmail(email)) {
      SnackbarService.warning('Format email tidak valid.');
      return;
    }

    try {
      isSubmitting.value = true;
      final success = await repository.sendChatRequest(email: email, message: message);
      if (success) {
        SnackbarService.success('Permintaan obrolan berhasil dikirim!');
        emailController.clear();
        messageController.clear();
        await loadOutgoing();
        await loadCounts();
        tabController.animateTo(1); // Switch to outgoing/history tab
      } else {
        SnackbarService.error('Gagal mengirim permintaan obrolan. Periksa kembali email tujuan.');
      }
    } catch (e) {
      LoggerService.e('Error sending chat request', error: e, tag: 'ChatRequestController');
      SnackbarService.error('Gagal mengirim permintaan. Pastikan pengguna terdaftar.');
    } finally {
      isSubmitting.value = false;
    }
  }
}
