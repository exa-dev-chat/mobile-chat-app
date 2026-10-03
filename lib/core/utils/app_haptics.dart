import 'package:flutter/services.dart';

/// Centralized Haptic Feedback utility for tactile native mobile sensations.
class AppHaptics {
  AppHaptics._();

  /// Subtle click for standard button taps, reactions, or item selections
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Medium pop for long-press, gestures, and swipe-to-reply triggers
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Strong vibration for important events, delete confirmation, or errors
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// Tactile tick for audio scrubbing, sliders, or scrolling picker items
  static void selection() {
    HapticFeedback.selectionClick();
  }
}
