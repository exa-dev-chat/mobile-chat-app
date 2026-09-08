import 'package:get/get.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/upload_service.dart';
import '../../../core/services/voice_recorder_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../call/controllers/call_controller.dart';
import '../controllers/chat_controller.dart';
import '../repositories/chat_repository.dart';

class ChatBinding extends Bindings {
  @override
  void dependencies() {
    // Auth dependencies
    if (!Get.isRegistered<AuthRepository>()) {
      Get.lazyPut<AuthRepository>(
        () => AuthRepository(apiClient: Get.find<ApiClient>()),
      );
    }
    if (!Get.isRegistered<AuthController>()) {
      Get.lazyPut<AuthController>(
        () => AuthController(
          repository: Get.find<AuthRepository>(),
          storageService: Get.find<StorageService>(),
        ),
      );
    }

    // WebSocket & Signaling (Persistent to listen for calls & presence)
    if (!Get.isRegistered<WebSocketService>()) {
      Get.put<WebSocketService>(
        WebSocketService(storageService: Get.find<StorageService>()),
        permanent: true,
      );
    }

    // Call Controller (Listens for incoming calls across screens)
    if (!Get.isRegistered<CallController>()) {
      Get.put<CallController>(
        CallController(wsService: Get.find<WebSocketService>()),
        permanent: true,
      );
    }

    // Upload & Voice Recorder Services
    if (!Get.isRegistered<UploadService>()) {
      Get.lazyPut<UploadService>(
        () => UploadService(apiClient: Get.find<ApiClient>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<VoiceRecorderService>()) {
      Get.lazyPut<VoiceRecorderService>(
        () => VoiceRecorderService(),
        fenix: true,
      );
    }

    // Chat dependencies
    if (!Get.isRegistered<ChatRepository>()) {
      Get.lazyPut<ChatRepository>(
        () => ChatRepository(apiClient: Get.find<ApiClient>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<ChatController>()) {
      Get.put<ChatController>(
        ChatController(
          repository: Get.find<ChatRepository>(),
          storageService: Get.find<StorageService>(),
          wsService: Get.find<WebSocketService>(),
          uploadService: Get.find<UploadService>(),
          voiceRecorderService: Get.find<VoiceRecorderService>(),
        ),
        permanent: true,
      );
    }
  }
}
