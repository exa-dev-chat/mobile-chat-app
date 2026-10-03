import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';
import 'edit_profile_view.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Profil Saya',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.primaryLight),
            tooltip: 'Edit Profil',
            onPressed: () => Get.to(() => const EditProfileView()),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.user.value == null) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final user = controller.user.value;
        final name = user?.name ?? 'Pengguna';
        final email = user?.email ?? '';
        final avatarUrl = user?.avatarUrl;

        return RefreshIndicator(
          onRefresh: () => controller.loadProfile(),
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Profile Card Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          _buildAvatar(avatarUrl, name, radius: 48),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.onlineIndicator,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface, width: 3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, color: AppColors.success, size: 8),
                                SizedBox(width: 6),
                                Text(
                                  'Aktif & Terhubung',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: (user?.isEmailVerified ?? false)
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: (user?.isEmailVerified ?? false)
                                    ? AppColors.primary.withValues(alpha: 0.3)
                                    : AppColors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  (user?.isEmailVerified ?? false) ? Icons.verified_user_rounded : Icons.info_outline_rounded,
                                  color: (user?.isEmailVerified ?? false) ? AppColors.primaryLight : AppColors.warning,
                                  size: 13,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  (user?.isEmailVerified ?? false) ? 'Email Terverifikasi' : 'Email Belum Diverifikasi',
                                  style: TextStyle(
                                    color: (user?.isEmailVerified ?? false) ? AppColors.primaryLight : AppColors.warning,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Security & Linked Accounts Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Keamanan & Akun Tertaut',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Kelola metode masuk dan status verifikasi akun Anda.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),

                      // Email Verification Row (if unverified)
                      if (!(user?.isEmailVerified ?? false)) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.mark_email_unread_outlined, color: AppColors.warning, size: 22),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Verifikasi Email Anda',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _showVerifyEmailDialog(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Verifikasi'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Google Account Row
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'G',
                                style: TextStyle(
                                  color: Color(0xFF4285F4),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Google',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    (user?.isGoogleLinked ?? false) ? 'Terhubung' : 'Belum terhubung',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: (user?.isGoogleLinked ?? false) ? AppColors.success : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (user?.isGoogleLinked ?? false)
                              OutlinedButton(
                                onPressed: () async {
                                  if (Get.isRegistered<AuthController>()) {
                                    await Get.find<AuthController>().unlinkGoogleAccount();
                                    controller.loadProfile();
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                                  foregroundColor: AppColors.error,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Putuskan', style: TextStyle(fontSize: 12)),
                              )
                            else
                              ElevatedButton(
                                onPressed: () async {
                                  if (Get.isRegistered<AuthController>()) {
                                    await Get.find<AuthController>().linkGoogleAccount();
                                    controller.loadProfile();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Hubungkan', style: TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Apple ID Row
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.apple, color: Colors.black, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Apple ID',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    (user?.isAppleLinked ?? false) ? 'Terhubung' : 'Belum terhubung',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: (user?.isAppleLinked ?? false) ? AppColors.success : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (user?.isAppleLinked ?? false)
                              OutlinedButton(
                                onPressed: () async {
                                  if (Get.isRegistered<AuthController>()) {
                                    await Get.find<AuthController>().unlinkAppleAccount();
                                    controller.loadProfile();
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                                  foregroundColor: AppColors.error,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Putuskan', style: TextStyle(fontSize: 12)),
                              )
                            else
                              ElevatedButton(
                                onPressed: () async {
                                  if (Get.isRegistered<AuthController>()) {
                                    await Get.find<AuthController>().linkAppleAccount();
                                    controller.loadProfile();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Hubungkan', style: TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Settings & Actions Menu
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        icon: Icons.edit_outlined,
                        iconColor: AppColors.primary,
                        title: 'Ubah Data Profil',
                        subtitle: 'Nama dan foto profil Anda',
                        onTap: () => Get.to(() => const EditProfileView()),
                      ),
                      const Divider(height: 1, color: AppColors.border, indent: 64),
                      _buildMenuItem(
                        icon: Icons.person_add_outlined,
                        iconColor: AppColors.secondary,
                        title: 'Permintaan Obrolan',
                        subtitle: 'Kelola kontak dan permintaan pertemanan',
                        onTap: () => Get.toNamed(Routes.chatRequests),
                      ),
                      const Divider(height: 1, color: AppColors.border, indent: 64),
                      _buildMenuItem(
                        icon: Icons.notifications_none_rounded,
                        iconColor: AppColors.accent,
                        title: 'Pemberitahuan & Panggilan',
                        subtitle: 'Notifikasi WebRTC dan pesan baru aktif',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Logout Button Card
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _buildMenuItem(
                    icon: Icons.logout_rounded,
                    iconColor: AppColors.error,
                    title: 'Keluar Akun',
                    subtitle: 'Keluar dari sesi saat ini di perangkat ini',
                    textColor: AppColors.error,
                    onTap: () => controller.logout(),
                  ),
                ),

                const SizedBox(height: 32),
                const Text(
                  'ChatApp Mobile v1.0.0',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 22),
      onTap: onTap,
    );
  }

  Widget _buildAvatar(String? avatarUrl, String name, {double radius = 32}) {
    if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryDark,
      child: Text(
        initial,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.75),
      ),
    );
  }

  void _showVerifyEmailDialog(BuildContext context) {
    final otpController = TextEditingController();
    final authCtrl = Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    if (authCtrl == null) return;

    // Send OTP initially
    authCtrl.sendEmailVerificationOtp();

    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mark_email_read_outlined, color: AppColors.primaryLight, size: 40),
              const SizedBox(height: 14),
              const Text(
                'Verifikasi Alamat Email',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Kode verifikasi 6-digit telah dikirimkan ke ${controller.user.value?.email ?? "email Anda"}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(color: Colors.white, letterSpacing: 4, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '123456',
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final code = otpController.text.trim();
                        if (code.length != 6) {
                          return;
                        }
                        final ok = await authCtrl.verifyEmailOtp(code);
                        if (ok) {
                          Get.back();
                          controller.loadProfile();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Verifikasi'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => authCtrl.sendEmailVerificationOtp(),
                child: const Text(
                  'Kirim Ulang Kode',
                  style: TextStyle(color: AppColors.primaryLight, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
