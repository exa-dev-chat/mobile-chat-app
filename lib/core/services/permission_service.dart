import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';
import 'logger_service.dart';
import 'snackbar_service.dart';

class PermissionService {
  /// Request microphone permission for voice notes and voice calls.
  static Future<bool> requestMicrophone({String reason = 'merekam pesan suara atau melakukan panggilan'}) async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;

    final result = await Permission.microphone.request();
    if (result.isGranted) {
      LoggerService.i('Microphone permission granted', tag: 'PermissionService');
      return true;
    }

    if (result.isPermanentlyDenied) {
      _showSettingsDialog(
        title: 'Izin Mikrofon Dibutuhkan',
        message: 'Akses mikrofon ditolak atau belum aktif di iOS. Silakan aktifkan di Pengaturan Aplikasi.',
      );
    } else {
      SnackbarService.warning('Izin mikrofon diperlukan untuk $reason.');
    }
    return false;
  }

  /// Request camera permission for video calls or capturing photos.
  static Future<bool> requestCamera({String reason = 'panggilan video atau mengambil foto'}) async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    final result = await Permission.camera.request();
    if (result.isGranted) {
      LoggerService.i('Camera permission granted', tag: 'PermissionService');
      return true;
    }

    if (result.isPermanentlyDenied) {
      _showSettingsDialog(
        title: 'Izin Kamera Dibutuhkan',
        message: 'Akses kamera ditolak atau belum aktif di iOS. Silakan aktifkan di Pengaturan Aplikasi.',
      );
    } else {
      SnackbarService.warning('Izin kamera diperlukan untuk $reason.');
    }
    return false;
  }

  /// Request audio/video call permissions.
  static Future<bool> requestCallPermissions({required bool isVideo}) async {
    final permissions = <Permission>[Permission.microphone];
    if (isVideo) {
      permissions.add(Permission.camera);
    }

    final statuses = await permissions.request();
    final allGranted = statuses.values.every((s) => s.isGranted);

    if (!allGranted) {
      final permanentlyDenied = statuses.values.any((s) => s.isPermanentlyDenied);
      if (permanentlyDenied) {
        _showSettingsDialog(
          title: isVideo ? 'Izin Kamera & Mikrofon' : 'Izin Mikrofon',
          message: isVideo
              ? 'Aplikasi memerlukan izin kamera dan mikrofon untuk video call. Silakan aktifkan di Pengaturan Aplikasi.'
              : 'Aplikasi memerlukan izin mikrofon untuk panggilan suara. Silakan aktifkan di Pengaturan Aplikasi.',
        );
      } else {
        SnackbarService.warning(
          isVideo
              ? 'Izin kamera dan mikrofon diperlukan untuk video call.'
              : 'Izin mikrofon diperlukan untuk panggilan suara.',
        );
      }
      return false;
    }
    return true;
  }

  /// Request photo library permission for uploading media attachments.
  static Future<bool> requestPhotos() async {
    final status = await Permission.photos.status;
    if (status.isGranted || status.isLimited) return true;

    if (status.isPermanentlyDenied) {
      _showSettingsDialog(
        title: 'Izin Galeri Foto',
        message: 'Aplikasi memerlukan akses galeri foto untuk memilih lampiran media.',
      );
      return false;
    }

    final result = await Permission.photos.request();
    if (result.isGranted || result.isLimited) return true;

    if (result.isPermanentlyDenied) {
      _showSettingsDialog(
        title: 'Izin Galeri Ditolak',
        message: 'Akses galeri foto ditolak permanen. Silakan aktifkan di Pengaturan.',
      );
    }
    return false;
  }

  static void _showSettingsDialog({required String title, required String message}) {
    if (Get.isDialogOpen ?? false) return;

    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Get.back();
              openAppSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }
}
