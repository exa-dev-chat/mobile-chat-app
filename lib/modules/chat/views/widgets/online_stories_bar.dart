import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../models/chat_room_model.dart';

class OnlineStoriesBar extends StatelessWidget {
  final List<ChatRoomModel> chats;
  final Set<int> onlineUserIds;
  final String? myAvatarUrl;
  final String myName;
  final ValueChanged<ChatRoomModel> onChatSelected;
  final VoidCallback onMyStatusTap;

  const OnlineStoriesBar({
    super.key,
    required this.chats,
    required this.onlineUserIds,
    this.myAvatarUrl,
    required this.myName,
    required this.onChatSelected,
    required this.onMyStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    // Filter private chats where the opponent is online or present
    final directChats = chats.where((c) => c.type == 'private' && c.userId != null).toList();

    // Sort online users first
    directChats.sort((a, b) {
      final aOnline = onlineUserIds.contains(a.userId);
      final bOnline = onlineUserIds.contains(b.userId);
      if (aOnline && !bOnline) return -1;
      if (!aOnline && bOnline) return 1;
      return 0;
    });

    if (directChats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: directChats.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            // My Profile / Status Item
            return _buildMyStatusItem();
          }

          final chat = directChats[index - 1];
          final isOnline = chat.userId != null && onlineUserIds.contains(chat.userId);
          return _buildContactStoryItem(chat, isOnline);
        },
      ),
    );
  }

  Widget _buildMyStatusItem() {
    final initial = myName.isNotEmpty ? myName[0].toUpperCase() : 'S';

    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        onMyStatusTap();
      },
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: myAvatarUrl != null && myAvatarUrl!.isNotEmpty && myAvatarUrl!.startsWith('http')
                        ? Image.network(myAvatarUrl!, fit: BoxFit.cover)
                        : Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                    child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Profil Saya',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactStoryItem(ChatRoomModel chat, bool isOnline) {
    final name = chat.name ?? 'Kontak';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'K';

    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        onChatSelected(chat);
      },
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Glowing gradient ring if online
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isOnline
                        ? const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF06B6D4), Color(0xFF6366F1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [AppColors.surfaceVariant, AppColors.borderLight],
                          ),
                    boxShadow: isOnline
                        ? [
                            BoxShadow(
                              color: AppColors.onlineIndicator.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  padding: const EdgeInsets.all(2.5),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: chat.avatar != null && chat.avatar!.isNotEmpty && chat.avatar!.startsWith('http')
                        ? Image.network(chat.avatar!, fit: BoxFit.cover)
                        : Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                          ),
                  ),
                ),
                // Glowing dot
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.onlineIndicator,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isOnline ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: isOnline ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
