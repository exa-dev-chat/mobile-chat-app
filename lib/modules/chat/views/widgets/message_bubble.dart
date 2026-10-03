import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../call/models/call_log_model.dart';
import '../../models/message_model.dart';
import 'call_log_bubble.dart';
import 'media_viewer_dialog.dart';
import 'message_reaction_dialog.dart';
import 'voice_note_player.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool isGroup;
  final List<String> reactions;
  final VoidCallback? onReply;
  final Function(String emoji)? onReact;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isGroup = false,
    this.reactions = const [],
    this.onReply,
    this.onReact,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (isCallLog(message.content)) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: CallLogBubble(
          message: message,
          isMe: isMe,
        ),
      );
    }

    final heroTag = 'img_msg_${message.id}_${message.createdAt}';

    return Dismissible(
      key: ValueKey('dismiss_msg_${message.id}_${message.createdAt}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        if (onReply != null) {
          AppHaptics.medium();
          onReply!();
        }
        return false; // Never dismiss, only trigger swipe-to-reply action
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.25),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: const Icon(Icons.reply_rounded, color: AppColors.primaryLight, size: 20),
        ),
      ),
      child: GestureDetector(
        onLongPress: () {
          MessageReactionDialog.show(
            context: context,
            message: message,
            isMe: isMe,
            onReact: (emoji) => onReact?.call(emoji),
            onReply: () => onReply?.call(),
            onDelete: onDelete,
          );
        },
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.76,
                ),
                margin: EdgeInsets.only(
                  top: 4,
                  bottom: reactions.isNotEmpty ? 12 : 4,
                  left: 16,
                  right: 16,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.myMessageBubble : AppColors.otherMessageBubble,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  border: Border.all(
                    color: isMe ? AppColors.primaryLight.withValues(alpha: 0.35) : AppColors.border,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Group sender name
                    if (isGroup && !isMe && message.senderName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.senderName!,
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    // Quoted reply header
                    if (message.replyTo != null) _buildReplyQuote(message.replyTo!),

                    // Content body according to messageType
                    _buildMessageContent(context, heroTag),

                    const SizedBox(height: 4),

                    // Timestamp & Read Receipt Checkmarks
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.createdAt != null)
                          Text(
                            _formatTime(message.createdAt!),
                            style: TextStyle(
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.75)
                                  : AppColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                            size: 14,
                            color: message.isRead ? AppColors.accent : Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Floating Reactions Badge
              if (reactions.isNotEmpty)
                Positioned(
                  bottom: 2,
                  right: isMe ? 22 : null,
                  left: isMe ? null : 22,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: reactions.take(3).map((emoji) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Text(emoji, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyQuote(MessageModel quoted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white70 : AppColors.primaryLight,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quoted.senderName ?? 'Pesan',
            style: TextStyle(
              color: isMe ? Colors.white : AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            quoted.content.startsWith('http') ? '[Media / Berkas]' : quoted.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isMe ? Colors.white70 : AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, String heroTag) {
    if (message.messageType == 'audio') {
      return VoiceNotePlayer(
        audioUrl: message.content,
        isMe: isMe,
      );
    }

    if (message.messageType == 'image') {
      return GestureDetector(
        onTap: () {
          MediaViewerDialog.show(
            context: context,
            imageUrl: message.content,
            heroTag: heroTag,
            title: message.senderName ?? 'Foto',
            subtitle: message.createdAt != null ? _formatTime(message.createdAt!) : null,
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Hero(
            tag: heroTag,
            child: Image.network(
              message.content,
              width: 220,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: 220,
                  height: 150,
                  color: AppColors.surfaceVariant,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                width: 220,
                height: 120,
                color: AppColors.surfaceVariant,
                child: const Center(
                  child: Icon(Icons.broken_image_rounded, color: AppColors.textMuted),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (message.messageType == 'file') {
      final fileName = message.content.split('/').last.split('?').first;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isMe ? Colors.white.withValues(alpha: 0.2) : AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.attach_file_rounded, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              fileName.isNotEmpty ? fileName : 'Lampiran Berkas',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      message.content,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        height: 1.35,
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
