import 'package:get/get.dart';
import '../../../core/network/api_client.dart';
import '../controllers/chat_request_controller.dart';
import '../repositories/chat_request_repository.dart';

class ChatRequestBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChatRequestRepository>(
      () => ChatRequestRepository(apiClient: Get.find<ApiClient>()),
    );
    Get.lazyPut<ChatRequestController>(
      () => ChatRequestController(repository: Get.find<ChatRequestRepository>()),
    );
  }
}
