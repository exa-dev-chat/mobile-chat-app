import 'package:get/get.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../controllers/profile_controller.dart';
import '../repositories/profile_repository.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileRepository>(
      () => ProfileRepository(apiClient: Get.find<ApiClient>()),
    );
    Get.lazyPut<ProfileController>(
      () => ProfileController(
        repository: Get.find<ProfileRepository>(),
        storageService: Get.find<StorageService>(),
      ),
    );
  }
}
