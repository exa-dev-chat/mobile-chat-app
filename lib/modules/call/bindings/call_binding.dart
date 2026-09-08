import 'package:get/get.dart';
import '../../../core/services/websocket_service.dart';
import '../controllers/call_controller.dart';

class CallBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CallController>(
      () => CallController(wsService: Get.find<WebSocketService>()),
    );
  }
}
