import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/services/snackbar_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../models/message_model.dart';

class MessageReactionDialog {
  MessageReactionDialog._();

  static const List<String> quickEmojis = ['❤️', '👍', '😂', '😮', '😢', '🔥'];

  static void show({
    required BuildContext context,
    required MessageModel message,
    required bool isMe,
    required Function(String emoji) onReact,
    required VoidCallback onReply,
    VoidCallback? onDelete,
  }) {
    AppHaptics.medium();

    Get.dialog(
      GestureDetector(
        onTap: () => Get.back(),
        behavior: HitTestBehavior.opaque,
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Frosted glass background
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),

              Center(
                child: Container(
                  width: MediaQuery.sizeOf(context).width * 0.85,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.borderLight, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Emoji Reaction Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: quickEmojis.map((emoji) {
                            return GestureDetector(
                              onTap: () {
                                AppHaptics.light();
                                Get.back();
                                onReact(emoji);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.transparent,
                                ),
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Preview of message
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: const Border(
                            left: BorderSide(color: AppColors.primary, width: 3),
                          ),
                        ),
                        child: Text(
                          message.content.startsWith('http')
                              ? '[Media / Lampiran]'
                              : message.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Action Items List
                      _buildActionItem(
                        icon: Icons.reply_rounded,
                        label: 'Balas Pesan',
                        color: AppColors.primaryLight,
                        onTap: () {
                          AppHaptics.light();
                          Get.back();
                          onReply();
                        },
                      ),
                      const Divider(height: 1, color: AppColors.border),

                      if (message.messageType == 'text') ...[
                        _buildActionItem(
                          icon: Icons.copy_rounded,
                          label: 'Salin Teks',
                          color: AppColors.textPrimary,
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: message.content));
                            AppHaptics.light();
                            Get.back();
                            SnackbarService.success('Teks berhasil disalin ke clipboard');
                          },
                        ),
                        const Divider(height: 1, color: AppColors.border),
                      ],

                      if (isMe && onDelete != null) ...[
                        _buildActionItem(
                          icon: Icons.delete_outline_rounded,
                          label: 'Hapus Pesan',
                          color: AppColors.error,
                          onTap: () {
                            AppHaptics.heavy();
                            Get.back();
                            onDelete();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierColor: Colors.transparent,
    );
  }

  static Widget _buildActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
