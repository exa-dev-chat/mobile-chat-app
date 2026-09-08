import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Brand Colors
  static const Color primary = Color(0xFF6366F1); // Indigo 500
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color secondary = Color(0xFF8B5CF6); // Violet 500
  static const Color accent = Color(0xFF06B6D4); // Cyan 500

  // Dark Theme Background & Surfaces
  static const Color background = Color(0xFF0A0F1D); // Deep Midnight Slate
  static const Color surface = Color(0xFF131B2E); // Sleek Surface Card
  static const Color surfaceVariant = Color(0xFF1E293B); // Slate 800
  static const Color surfaceHighlight = Color(0xFF334155); // Slate 700

  // Borders & Dividers
  static const Color border = Color(0xFF1E293B);
  static const Color borderLight = Color(0xFF334155);

  // Status & Feedback Colors
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color error = Color(0xFFF43F5E); // Rose 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color info = Color(0xFF0EA5E9); // Sky 500

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  static const Color textDisabled = Color(0xFF475569);

  // Chat Specific
  static const Color myMessageBubble = Color(0xFF4F46E5);
  static const Color otherMessageBubble = Color(0xFF1E293B);
  static const Color onlineIndicator = Color(0xFF10B981);
  static const Color offlineIndicator = Color(0xFF64748B);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF131B2E), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
