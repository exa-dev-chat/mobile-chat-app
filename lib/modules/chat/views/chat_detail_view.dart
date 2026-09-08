import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/voice_player_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../call/models/call_session_model.dart';
import '../controllers/chat_controller.dart';
import 'widgets/message_bubble.dart';

class ChatDetailView extends GetView<ChatController> {
  final bool isEmbedded;

  const ChatDetailView({
    super.key,
    this.isEmbedded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final chat = controller.activeChat.value;

      if (chat == null) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: isEmbedded
              ? null
              : AppBar(
                  backgroundColor: AppColors.surface,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Get.back(),
                  ),
                ),
          body: const Center(
            child: Text(
              'Pilih obrolan untuk memulai percakapan',
              style: TextStyle(color: AppColors.textMuted, fontSize: 15),
            ),
          ),
        );
      }

      final title = chat.name ?? (chat.type == 'group' ? 'Grup Obrolan' : 'Direct Chat');

      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            FocusManager.instance.primaryFocus?.unfocus();
            if (controller.voiceRecorderService.isRecording.value) {
              controller.cancelVoiceRecording();
            }
            if (Get.isRegistered<VoicePlayerService>()) {
              Get.find<VoicePlayerService>().stop();
            }
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            leading: isEmbedded
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Get.back();
                    },
                  ),
            title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceVariant,
                child: Text(
                  title.isNotEmpty ? title[0].toUpperCase() : 'C',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Obx(() {
                      if (controller.isOtherUserTyping.value) {
                        return const Text(
                          'sedang mengetik...',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.accent,
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      }
                      if (chat.type == 'group') {
                        return const Text(
                          'Grup',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        );
                      }
                      final isOnline = chat.userId != null &&
                          controller.onlineUsers.contains(chat.userId);
                      return Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline
                              ? AppColors.onlineIndicator
                              : AppColors.textMuted,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Voice Call Action
            IconButton(
              icon: const Icon(Icons.call_outlined, color: AppColors.textPrimary, size: 22),
              tooltip: 'Panggilan Suara',
              onPressed: () => controller.startCall(CallType.audio),
            ),
            // Video Call Action
            IconButton(
              icon: const Icon(Icons.videocam_outlined, color: AppColors.textPrimary, size: 24),
              tooltip: 'Panggilan Video',
              onPressed: () => controller.startCall(CallType.video),
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: AppColors.border, height: 1),
          ),
        ),
        body: Column(
          children: [
            // Uploading progress banner
            Obx(() {
              if (controller.isUploadingMedia.value) {
                return Container(
                  width: double.infinity,
                  color: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Mengunggah media...',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),

            // Message List
            Expanded(
              child: Obx(() {
                if (controller.isLoadingMessages.value) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  );
                }

                final messages = controller.messages;
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada pesan. Mulai kirim salam!',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                    ),
                  );
                }

                return ListView.builder(
                  controller: controller.messageScrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  physics: const BouncingScrollPhysics(),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == controller.currentUserId;
                    return MessageBubble(message: msg, isMe: isMe);
                  },
                );
              }),
            ),

            // Message Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Obx(() {
                  // Voice recording in progress
                  if (controller.voiceRecorderService.isRecording.value) {
                    return _buildVoiceRecordingBar();
                  }

                  // Normal text / attachment input bar
                  return _buildTextInputBar(context);
                }),
              ),
            ),
          ],
        ),
      ),
    );
  });
  }

  Widget _buildVoiceRecordingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          // Pulsing recording red indicator
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          // Timer
          Text(
            controller.voiceRecorderService.formattedDuration,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          // Cancel Button
          TextButton(
            onPressed: () => controller.cancelVoiceRecording(),
            child: const Text('Batal', style: TextStyle(color: AppColors.error, fontSize: 14)),
          ),
          const SizedBox(width: 4),
          // Send Voice Note Button
          FloatingActionButton.small(
            heroTag: 'btn_send_vn',
            backgroundColor: AppColors.primary,
            elevation: 2,
            onPressed: () => controller.stopAndSendVoiceNote(),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInputBar(BuildContext context) {
    return Row(
      children: [
        // Media Attachment Button
        IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.textSecondary, size: 24),
          onPressed: () => _showAttachmentBottomSheet(context),
        ),

        // Text Field
        Expanded(
          child: TextField(
            controller: controller.messageInputController,
            textInputAction: TextInputAction.send,
            onChanged: (_) => controller.notifyTyping(),
            onSubmitted: (_) => controller.sendMessage(),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Tulis pesan...',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.primary, width: 1),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Mic or Send Action Button
        Obx(() {
          final hasText = controller.hasInputText.value;

          if (hasText) {
            return Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
              ),
              child: IconButton(
                icon: controller.isSendingMessage.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: controller.isSendingMessage.value ? null : () => controller.sendMessage(),
              ),
            );
          }

          // Voice Record Trigger Button
          return Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceVariant,
            ),
            child: IconButton(
              icon: const Icon(Icons.mic_rounded, color: AppColors.primaryLight, size: 22),
              tooltip: 'Rekam Pesan Suara',
              onPressed: () => controller.startVoiceRecording(),
            ),
          );
        }),
      ],
    );
  }

  void _showAttachmentBottomSheet(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(
                    icon: Icons.camera_alt_rounded,
                    color: Colors.pinkAccent,
                    label: 'Kamera',
                    onTap: () {
                      Get.back();
                      controller.pickAndSendImage(ImageSource.camera);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.photo_library_rounded,
                    color: Colors.purpleAccent,
                    label: 'Galeri',
                    onTap: () {
                      Get.back();
                      controller.pickAndSendImage(ImageSource.gallery);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.insert_drive_file_rounded,
                    color: Colors.blueAccent,
                    label: 'Dokumen',
                    onTap: () {
                      Get.back();
                      controller.pickAndSendFile();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
