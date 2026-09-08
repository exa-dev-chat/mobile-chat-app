import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

enum ScreenType { mobile, tablet, desktop }

class Responsive {
  Responsive._();

  static ScreenType getScreenType(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    if (width >= AppConstants.breakpointTablet) {
      return ScreenType.desktop;
    } else if (width >= AppConstants.breakpointMobile) {
      return ScreenType.tablet;
    }
    return ScreenType.mobile;
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppConstants.breakpointMobile;

  static bool isTablet(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    return width >= AppConstants.breakpointMobile &&
        width < AppConstants.breakpointTablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppConstants.breakpointTablet;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppConstants.breakpointMobile;

  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  static T value<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }
}

/// Widget for rendering different layouts based on screen size
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppConstants.breakpointTablet) {
          return desktop ?? tablet ?? mobile;
        }
        if (constraints.maxWidth >= AppConstants.breakpointMobile) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }
}

/// Widget for constraining card/content width on tablet/desktop (e.g. login, register forms)
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = AppConstants.maxAuthCardWidth,
    this.padding = const EdgeInsets.all(24.0),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
