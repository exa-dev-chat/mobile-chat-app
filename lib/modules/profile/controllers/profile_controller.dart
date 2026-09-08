import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/services/storage_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/models/user_model.dart';
import '../repositories/profile_repository.dart';

class ProfileController extends GetxController {
  final ProfileRepository repository;
  final StorageService storageService;

  ProfileController({
    required this.repository,
    required this.storageService,
  });

  final user = Rxn<UserModel>();
  final isLoading = false.obs;
  final isSaving = false.obs;

  final selectedAvatarPath = ''.obs;
  final nameController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  @override
  void onClose() {
    nameController.dispose();
    super.onClose();
  }

  Future<void> loadProfile() async {
    isLoading.value = true;
    try {
      // First load from local storage
      final localProfile = storageService.userProfile;
      if (localProfile != null) {
        user.value = UserModel.fromJson(localProfile);
        nameController.text = user.value?.name ?? '';
      }

      // Then fetch fresh data from backend
      final freshProfile = await repository.getProfile();
      user.value = freshProfile;
      nameController.text = freshProfile.name;
      await storageService.saveUserProfile(freshProfile.toJson());
    } catch (e) {
      LoggerService.e('Error loading profile', error: e, tag: 'ProfileController');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        selectedAvatarPath.value = pickedFile.path;
      }
    } catch (e) {
      LoggerService.e('Error picking image', error: e, tag: 'ProfileController');
      SnackbarService.error('Gagal memilih gambar.');
    }
  }

  Future<void> saveProfile() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      SnackbarService.warning('Nama tidak boleh kosong.');
      return;
    }

    isSaving.value = true;
    try {
      final res = await repository.updateProfile(
        name: name,
        avatarFilePath: selectedAvatarPath.value.isNotEmpty ? selectedAvatarPath.value : null,
      );

      final newAvatarUrl = (res['avatar_url'] as String?) ?? user.value?.avatarUrl;

      final updatedUser = UserModel(
        id: user.value?.id ?? 0,
        email: user.value?.email ?? '',
        name: name,
        isActive: user.value?.isActive ?? true,
        avatarUrl: newAvatarUrl,
        createdAt: user.value?.createdAt,
      );

      user.value = updatedUser;
      await storageService.saveUserProfile(updatedUser.toJson());

      // Update AuthController if present
      if (Get.isRegistered<AuthController>()) {
        Get.find<AuthController>().currentUser.value = updatedUser;
      }

      selectedAvatarPath.value = '';
      SnackbarService.success('Profil berhasil diperbarui!');
      Get.back();
    } catch (e) {
      LoggerService.e('Error updating profile', error: e, tag: 'ProfileController');
      SnackbarService.error('Gagal memperbarui profil.');
    } finally {
      isSaving.value = false;
    }
  }

  void logout() {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Keluar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun ini?',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Get.back();
              if (Get.isRegistered<AuthController>()) {
                Get.find<AuthController>().logout();
              }
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}
