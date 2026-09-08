import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/storage_service.dart';
import '../app_routes.dart';

/// GuestMiddleware blocks authenticated users (who already have an active token)
/// from visiting login or register screens, redirecting them straight to chats.
class GuestMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    final storageService = Get.find<StorageService>();
    if (storageService.isLoggedIn) {
      LoggerService.i(
        'GuestMiddleware: User is already authenticated. Redirecting from $route to ${Routes.chats}',
        tag: 'GuestMiddleware',
      );
      return const RouteSettings(name: Routes.chats);
    }
    return null;
  }
}

/// AuthMiddleware blocks unauthenticated users from accessing protected screens
/// (such as chat list and chat detail), redirecting them to the login screen.
class AuthMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    final storageService = Get.find<StorageService>();
    if (!storageService.isLoggedIn) {
      LoggerService.i(
        'AuthMiddleware: User is not authenticated. Redirecting from $route to ${Routes.login}',
        tag: 'AuthMiddleware',
      );
      return const RouteSettings(name: Routes.login);
    }
    return null;
  }
}
