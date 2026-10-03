import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';

class MediaViewerDialog extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final String? title;
  final String? subtitle;

  const MediaViewerDialog({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.title,
    this.subtitle,
  });

  static void show({
    required BuildContext context,
    required String imageUrl,
    required String heroTag,
    String? title,
    String? subtitle,
  }) {
    AppHaptics.light();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, anim1, anim2) {
          return MediaViewerDialog(
            imageUrl: imageUrl,
            heroTag: heroTag,
            title: title,
            subtitle: subtitle,
          );
        },
        transitionsBuilder: (context, anim1, anim2, child) {
          return FadeTransition(opacity: anim1, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transformationController = TransformationController();

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.92),
      body: Stack(
        children: [
          // Background blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: const SizedBox.expand(),
          ),

          // Pinch-to-zoom interactive viewer
          Center(
            child: GestureDetector(
              onDoubleTapDown: (details) {
                if (transformationController.value.isIdentity()) {
                  final position = details.localPosition;
                  final zoomed = Matrix4.diagonal3Values(2.5, 2.5, 1.0)..setTranslationRaw(-position.dx * 1.5, -position.dy * 1.5, 0.0);
                  transformationController.value = zoomed;
                  AppHaptics.selection();
                } else {
                  transformationController.value = Matrix4.identity();
                  AppHaptics.selection();
                }
              },
              child: InteractiveViewer(
                transformationController: transformationController,
                minScale: 0.8,
                maxScale: 4.5,
                clipBehavior: Clip.none,
                child: Hero(
                  tag: heroTag,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1)
                              : null,
                          color: AppColors.primary,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top action bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Back / Close button
                  GestureDetector(
                    onTap: () {
                      AppHaptics.light();
                      Get.back();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Title / Subtitle
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null && title!.isNotEmpty)
                          Text(
                            title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Reset zoom action button
                  IconButton(
                    icon: const Icon(Icons.zoom_out_map_rounded, color: Colors.white70),
                    tooltip: 'Reset Zoom',
                    onPressed: () {
                      transformationController.value = Matrix4.identity();
                      AppHaptics.selection();
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom helper hint
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'Cubit untuk memperbesar • Ketuk dua kali untuk zoom',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
