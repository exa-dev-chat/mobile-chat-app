import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import 'chat_detail_view.dart';
import 'widgets/chat_item_tile.dart';

class ChatListView extends GetView<ChatController> {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isWide(context);

    if (isWide) {
      // Split Master-Detail view for tablet and desktop
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            // Left Column: Chat List Sidebar
            SizedBox(
              width: 360,
              child: _buildChatListColumn(context, isWide: true),
            ),
            // Vertical Divider
            Container(width: 1, color: AppColors.border),
            // Right Column: Active Conversation Pane
            Expanded(
              child: Obx(() {
                if (controller.activeChat.value == null) {
                  return _buildEmptyDetailPlaceholder();
                }
                return const ChatDetailView(isEmbedded: true);
              }),
            ),
          ],
        ),
      );
    }

    // Standard single-column view for mobile screens
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        tooltip: 'Permintaan Obrolan',
        onPressed: () => Get.toNamed(Routes.chatRequests),
        child: const Icon(Icons.person_add_rounded, size: 24),
      ),
      body: SafeArea(
        child: _buildChatListColumn(context, isWide: false),
      ),
    );
  }

  Widget _buildChatListColumn(BuildContext context, {required bool isWide}) {
    final authController = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;

    return Column(
      children: [
        // App Bar / Top Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              // User Avatar (tappable to open Profile)
              GestureDetector(
                onTap: () => Get.toNamed(Routes.profile),
                child: Obx(() {
                  final user = authController?.currentUser.value;
                  final avatarUrl = user?.avatarUrl;
                  if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
                    return CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(avatarUrl),
                    );
                  }
                  final name = user?.name ?? '';
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                  return Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Obrolan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              // Chat Requests Button with Badge
              Obx(() {
                final count = controller.incomingRequestCount.value;
                return IconButton(
                  icon: Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    backgroundColor: AppColors.error,
                    child: const Icon(Icons.person_add_outlined, color: AppColors.textSecondary),
                  ),
                  tooltip: 'Permintaan Obrolan',
                  onPressed: () => Get.toNamed(Routes.chatRequests),
                );
              }),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
                tooltip: 'Muat ulang',
                onPressed: () => controller.loadChats(),
              ),
              IconButton(
                icon: const Icon(Icons.account_circle_outlined, color: AppColors.textSecondary),
                tooltip: 'Profil Saya',
                onPressed: () => Get.toNamed(Routes.profile),
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: controller.searchController,
            onChanged: controller.onSearchChanged,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Cari obrolan atau kontak...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: Obx(
                () => controller.searchQuery.value.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          controller.searchController.clear();
                          controller.onSearchChanged('');
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Chat List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => controller.loadChats(),
            color: AppColors.primary,
            child: Obx(() {
              if (controller.isLoadingChats.value && controller.chats.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                );
              }

              if (controller.chats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.forum_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum ada obrolan',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Mulai pesan baru untuk melihat obrolan di sini',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                itemCount: controller.chats.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final chat = controller.chats[index];
                  final isSelected = isWide && controller.activeChat.value?.id == chat.id;

                  return ChatItemTile(
                    chat: chat,
                    isSelected: isSelected,
                    isOnline: chat.userId != null && controller.onlineUsers.contains(chat.userId),
                    onTap: () => controller.selectChat(chat, isWideScreen: isWide),
                  );
                },
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyDetailPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                AppConstants.appIcon,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Pilih Obrolan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih salah satu percakapan dari daftar di sebelah kiri.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
