import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import 'logger_service.dart';

enum SnackbarType { success, error, warning, info }

class SnackbarService {
  SnackbarService._();

  // Anti-Spam state tracking
  static String? _lastMessage;
  static DateTime? _lastShowTime;

  /// Determine if a message should be suppressed due to spamming/flooding
  static bool _isSpam(String message) {
    final now = DateTime.now();

    // Check duplicate message within debounce window
    if (_lastMessage == message && _lastShowTime != null) {
      final elapsed = now.difference(_lastShowTime!);
      if (elapsed < AppConstants.snackbarDebounceWindow) {
        LoggerService.d(
          'Snackbar suppressed (duplicate spam detected): "$message"',
          tag: 'SnackbarService',
        );
        return true;
      }
    }

    // Check minimum interval between any snackbars to avoid visual stutter
    if (_lastShowTime != null) {
      final elapsed = now.difference(_lastShowTime!);
      if (elapsed < AppConstants.snackbarMinInterval) {
        LoggerService.d(
          'Snackbar suppressed (rate limit interval): "$message"',
          tag: 'SnackbarService',
        );
        return true;
      }
    }

    _lastMessage = message;
    _lastShowTime = now;
    return false;
  }

  /// Base method to show modern, anti-spam snackbar
  static void show({
    required String message,
    String? title,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    SnackPosition position = SnackPosition.TOP,
  }) {
    if (message.trim().isEmpty) return;
    if (_isSpam(message)) return;

    // Safety guard: ensure overlay context is available
    if (Get.overlayContext == null && Get.context == null) {
      LoggerService.d(
        'Snackbar skipped (no active overlay context): "$message"',
        tag: 'SnackbarService',
      );
      return;
    }

    // Dismiss any currently visible snackbar before displaying a new one
    try {
      if (Get.isSnackbarOpen) {
        Get.closeCurrentSnackbar();
      }
    } catch (_) {
      // Safe fallback if overlay is not active
    }

    Color accentColor;
    IconData iconData;
    String defaultTitle;

    switch (type) {
      case SnackbarType.success:
        accentColor = AppColors.success;
        iconData = Icons.check_circle_rounded;
        defaultTitle = 'Berhasil';
        break;
      case SnackbarType.error:
        accentColor = AppColors.error;
        iconData = Icons.error_rounded;
        defaultTitle = 'Terjadi Kesalahan';
        break;
      case SnackbarType.warning:
        accentColor = AppColors.warning;
        iconData = Icons.warning_rounded;
        defaultTitle = 'Peringatan';
        break;
      case SnackbarType.info:
        accentColor = AppColors.info;
        iconData = Icons.info_rounded;
        defaultTitle = 'Informasi';
        break;
    }

    Get.rawSnackbar(
      titleText: Text(
        title ?? defaultTitle,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      messageText: Text(
        message,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(iconData, color: accentColor, size: 20),
      ),
      snackPosition: position,
      backgroundColor: AppColors.surface,
      borderColor: accentColor.withValues(alpha: 0.4),
      borderWidth: 1,
      borderRadius: 14,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: duration,
      animationDuration: const Duration(milliseconds: 300),
      snackStyle: SnackStyle.FLOATING,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
      isDismissible: true,
      forwardAnimationCurve: Curves.easeOutBack,
      reverseAnimationCurve: Curves.easeInBack,
    );
  }

  /// Display a success notification
  static void success(String message, {String? title, Duration? duration}) {
    show(
      message: message,
      title: title,
      type: SnackbarType.success,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// Display an error notification
  static void error(String message, {String? title, Duration? duration}) {
    show(
      message: message,
      title: title,
      type: SnackbarType.error,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Display a warning notification
  static void warning(String message, {String? title, Duration? duration}) {
    show(
      message: message,
      title: title,
      type: SnackbarType.warning,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// Display an informational notification
  static void info(String message, {String? title, Duration? duration}) {
    show(
      message: message,
      title: title,
      type: SnackbarType.info,
      duration: duration ?? const Duration(seconds: 3),
    );
  }
}
