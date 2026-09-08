import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../routes/app_routes.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../../chat/controllers/chat_controller.dart';

class AuthController extends GetxController {
  final AuthRepository repository;
  final StorageService storageService;

  AuthController({
    required this.repository,
    required this.storageService,
  });

  // Text Controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // Forgot Password Controllers
  final forgotEmailController = TextEditingController();
  final otpCodeController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmNewPasswordController = TextEditingController();

  // Reactive State
  final isLoading = false.obs;
  final isGoogleLoading = false.obs;
  final isPasswordVisible = false.obs;
  final isConfirmPasswordVisible = false.obs;
  final isOtpSent = false.obs;
  final otpVerified = false.obs;
  final isNewPasswordVisible = false.obs;
  final isConfirmNewPasswordVisible = false.obs;
  final currentUser = Rxn<UserModel>();

  @override
  void onInit() {
    super.onInit();
    _loadStoredUser();
  }

  @override
  void onReady() {
    super.onReady();
    if (storageService.isLoggedIn) {
      LoggerService.i('AuthController: user already authenticated, redirecting to chats', tag: 'AuthController');
      Get.offAllNamed(Routes.chats);
    }
  }

  void _loadStoredUser() {
    final profile = storageService.userProfile;
    if (profile != null) {
      currentUser.value = UserModel.fromJson(profile);
    }
  }

  void togglePasswordVisibility() {
    isPasswordVisible.toggle();
  }

  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordVisible.toggle();
  }

  void toggleNewPasswordVisibility() {
    isNewPasswordVisible.toggle();
  }

  void toggleConfirmNewPasswordVisibility() {
    isConfirmNewPasswordVisible.toggle();
  }

  void resetForgotPasswordFlow() {
    forgotEmailController.clear();
    otpCodeController.clear();
    newPasswordController.clear();
    confirmNewPasswordController.clear();
    isOtpSent.value = false;
    otpVerified.value = false;
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      SnackbarService.warning('Email dan kata sandi wajib diisi.');
      return;
    }

    if (!GetUtils.isEmail(email)) {
      SnackbarService.warning('Format email tidak valid.');
      return;
    }

    try {
      isLoading.value = true;
      LoggerService.i('Attempting login for: $email', tag: 'AuthController');

      final authResponse = await repository.login(
        email: email,
        password: password,
      );

      await storageService.saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
      );

      if (authResponse.user != null) {
        await storageService.saveUserProfile(authResponse.user!.toJson());
        currentUser.value = authResponse.user;
      }

      if (Get.isRegistered<FcmService>()) {
        FcmService.to.syncTokenWithBackend();
      }

      SnackbarService.success(
        'Selamat datang kembali${authResponse.user != null ? ', ${authResponse.user!.name}' : ''}!',
        title: 'Login Berhasil',
      );

      Get.offAllNamed(Routes.chats);
    } catch (e) {
      LoggerService.e('Login failed: $e', tag: 'AuthController');
      // ErrorInterceptor handles displaying error snackbar cleanly
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      isGoogleLoading.value = true;
      LoggerService.i('Initiating Google Sign-In flow', tag: 'AuthController');

      final serverClientId = AppConstants.googleServerClientId;
      LoggerService.i('Google Sign-In serverClientId: $serverClientId', tag: 'AuthController');

      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
      );

      // Sign out any previous session so account chooser dialog shows up
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final account = await googleSignIn.signIn();
      if (account == null) {
        LoggerService.i('Google Sign-In canceled by user', tag: 'AuthController');
        return;
      }

      final auth = await account.authentication;
      LoggerService.i(
        'Google Auth results: idToken=${auth.idToken != null ? "present (${auth.idToken!.length} chars)" : "null"}, '
        'serverAuthCode=${account.serverAuthCode != null ? "present" : "null"}, '
        'accessToken=${auth.accessToken != null ? "present" : "null"}',
        tag: 'AuthController',
      );

      final authCodeOrToken = auth.idToken ?? account.serverAuthCode;

      if (authCodeOrToken == null || authCodeOrToken.isEmpty) {
        LoggerService.e(
          'Failed to get Google ID token or auth code. Ensure serverClientId is configured and SHA-1 is added in Firebase/Google Console.',
          tag: 'AuthController',
        );
        SnackbarService.error('Gagal mendapatkan token otentikasi Google.');
        return;
      }

      LoggerService.i('Sending Google auth code/token to backend', tag: 'AuthController');
      final authResponse = await repository.loginWithGoogle(code: authCodeOrToken);

      await storageService.saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
      );

      if (authResponse.user != null) {
        await storageService.saveUserProfile(authResponse.user!.toJson());
        currentUser.value = authResponse.user;
      }

      if (Get.isRegistered<FcmService>()) {
        FcmService.to.syncTokenWithBackend();
      }

      SnackbarService.success(
        'Selamat datang kembali${authResponse.user != null ? ', ${authResponse.user!.name}' : ''}!',
        title: 'Login Google Berhasil',
      );

      Get.offAllNamed(Routes.chats);
    } catch (e) {
      LoggerService.e('Google Sign-In failed: $e', tag: 'AuthController');
      SnackbarService.error('Otentikasi Google gagal: $e');
    } finally {
      isGoogleLoading.value = false;
    }
  }

  Future<void> register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      SnackbarService.warning('Semua kolom formulir wajib diisi.');
      return;
    }

    if (!GetUtils.isEmail(email)) {
      SnackbarService.warning('Format email tidak valid.');
      return;
    }

    if (password.length < 6) {
      SnackbarService.warning('Kata sandi minimal 6 karakter.');
      return;
    }

    if (password != confirmPassword) {
      SnackbarService.warning('Konfirmasi kata sandi tidak cocok.');
      return;
    }

    try {
      isLoading.value = true;
      LoggerService.i('Attempting registration for: $email', tag: 'AuthController');

      final authResponse = await repository.register(
        email: email,
        name: name,
        password: password,
      );

      await storageService.saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
      );

      if (authResponse.user != null) {
        await storageService.saveUserProfile(authResponse.user!.toJson());
        currentUser.value = authResponse.user;
      }

      if (Get.isRegistered<FcmService>()) {
        FcmService.to.syncTokenWithBackend();
      }

      SnackbarService.success(
        'Akun Anda berhasil dibuat!',
        title: 'Pendaftaran Sukses',
      );

      Get.offAllNamed(Routes.chats);
    } catch (e) {
      LoggerService.e('Registration failed: $e', tag: 'AuthController');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      if (Get.isRegistered<FcmService>()) {
        await FcmService.to.removeTokenFromBackend();
      }
      final refreshToken = storageService.refreshToken;
      await repository.logout(refreshToken: refreshToken);
    } catch (e) {
      LoggerService.w('Logout remote call failed: $e', tag: 'AuthController');
    } finally {
      if (Get.isRegistered<ChatController>()) {
        Get.delete<ChatController>(force: true);
      }
      await storageService.clearAuth();
      currentUser.value = null;
      SnackbarService.info('Anda telah keluar dari aplikasi.');
      Get.offAllNamed(Routes.login);
    }
  }

  Future<void> sendForgotPasswordOtp() async {
    final email = forgotEmailController.text.trim();
    if (email.isEmpty) {
      SnackbarService.warning('Alamat email wajib diisi.');
      return;
    }
    if (!GetUtils.isEmail(email)) {
      SnackbarService.warning('Format email tidak valid.');
      return;
    }

    try {
      isLoading.value = true;
      final msg = await repository.forgotPassword(email: email);
      isOtpSent.value = true;
      SnackbarService.success(msg, title: 'Email Terkirim');
    } catch (e) {
      LoggerService.e('sendForgotPasswordOtp failed: $e', tag: 'AuthController');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> verifyOtp() async {
    final email = forgotEmailController.text.trim();
    final code = otpCodeController.text.trim();

    if (code.length != 6) {
      SnackbarService.warning('Kode OTP harus 6 digit.');
      return;
    }

    try {
      isLoading.value = true;
      await repository.verifyResetToken(email: email, code: code);
      otpVerified.value = true;
      SnackbarService.success('Kode verifikasi valid. Silakan buat kata sandi baru.', title: 'Verifikasi Berhasil');
    } catch (e) {
      LoggerService.e('verifyOtp failed: $e', tag: 'AuthController');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> submitNewPassword() async {
    final email = forgotEmailController.text.trim();
    final code = otpCodeController.text.trim();
    final newPassword = newPasswordController.text;
    final confirmPassword = confirmNewPasswordController.text;

    if (newPassword.length < 8) {
      SnackbarService.warning('Kata sandi minimal 8 karakter.');
      return;
    }

    if (newPassword != confirmPassword) {
      SnackbarService.warning('Konfirmasi kata sandi tidak cocok.');
      return;
    }

    try {
      isLoading.value = true;
      await repository.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );

      SnackbarService.success(
        'Kata sandi Anda berhasil diperbarui. Silakan masuk kembali.',
        title: 'Berhasil',
      );

      resetForgotPasswordFlow();
      Get.offAllNamed(Routes.login);
    } catch (e) {
      LoggerService.e('submitNewPassword failed: $e', tag: 'AuthController');
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    confirmPasswordController.dispose();
    forgotEmailController.dispose();
    otpCodeController.dispose();
    newPasswordController.dispose();
    confirmNewPasswordController.dispose();
    super.onClose();
  }
}
