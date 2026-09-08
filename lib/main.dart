import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'core/constants/app_constants.dart';
import 'core/network/api_client.dart';
import 'core/services/fcm_service.dart';
import 'core/services/logger_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_pages.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env configuration
  try {
    await dotenv.load(fileName: '.env');
    LoggerService.i('.env loaded successfully', tag: 'Bootstrap');
  } catch (e) {
    LoggerService.w('.env could not be loaded, using defaults: $e', tag: 'Bootstrap');
  }

  LoggerService.i('Initializing ChatApp core services...', tag: 'Bootstrap');

  // Initialize and inject global services
  final storageService = await StorageService().init();
  Get.put<StorageService>(storageService, permanent: true);

  final apiClient = ApiClient(storageService: storageService);
  Get.put<ApiClient>(apiClient, permanent: true);

  final fcmService = await FcmService(
    storageService: storageService,
    apiClient: apiClient,
  ).init();
  Get.put<FcmService>(fcmService, permanent: true);

  LoggerService.i('Core services initialized. Starting app.', tag: 'Bootstrap');

  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      defaultTransition: Transition.fadeIn,
    );
  }
}
