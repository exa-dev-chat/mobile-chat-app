import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'ChatApp';
  static const String appVersion = '1.0.0';

  // Assets
  static const String appIcon = 'assets/images/app_icon.jpg';
  static const String loginBanner = 'assets/images/login.png';

  // Base API URL
  // Priority: 1. .env (API_BASE_URL) -> 2. Platform default (10.0.2.2 on Android, localhost on others)
  static String get defaultBaseUrl {
    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000';
      }
    } catch (_) {
      // Platform check may fail on unsupported environments
    }
    return 'http://localhost:8000';
  }

  // Base WebSocket URL
  // Priority: 1. .env (WS_BASE_URL) -> 2. derived from defaultBaseUrl
  static String get defaultWsUrl {
    final envWs = dotenv.env['WS_BASE_URL'];
    if (envWs != null && envWs.isNotEmpty) {
      return envWs;
    }
    final httpBase = defaultBaseUrl;
    final wsBase = httpBase.startsWith('https://')
        ? httpBase.replaceFirst('https://', 'wss://')
        : httpBase.replaceFirst('http://', 'ws://');
    return '$wsBase/ws';
  }

  // Network Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);

  // Network Retry Configuration
  static const int maxNetworkRetries = 3;
  static const Duration initialRetryDelay = Duration(milliseconds: 1000);

  // Anti-Spam Snackbar Configuration
  static const Duration snackbarDebounceWindow = Duration(milliseconds: 2500);
  static const Duration snackbarMinInterval = Duration(milliseconds: 400);

  // Storage Keys
  static const String storageKeyAccessToken = 'access_token';
  static const String storageKeyRefreshToken = 'refresh_token';
  static const String storageKeyUser = 'user_data';
  static const String storageKeyTheme = 'theme_mode';

  // Responsive Breakpoints
  static const double breakpointMobile = 768.0;
  static const double breakpointTablet = 1024.0;
  static const double maxAuthCardWidth = 440.0;
  static const double maxChatMasterWidth = 380.0;

  // Coturn WebRTC (STUN / TURN) Configuration matching FE
  // Priority: 1. .env -> 2. --dart-define -> 3. default fallback
  static String get stunUrl =>
      dotenv.env['STUN_URL'] ??
      const String.fromEnvironment(
        'STUN_URL',
        defaultValue: 'stun:coturn.eka-dev.cloud:3478',
      );

  static String get turnUrl =>
      dotenv.env['TURN_URL'] ??
      const String.fromEnvironment(
        'TURN_URL',
        defaultValue: 'turn:coturn.eka-dev.cloud:3478',
      );

  static String get turnUsername =>
      dotenv.env['TURN_USERNAME'] ??
      const String.fromEnvironment(
        'TURN_USERNAME',
        defaultValue: 'usertelepon',
      );

  static String get turnCredential =>
      dotenv.env['TURN_CREDENTIAL'] ??
      const String.fromEnvironment(
        'TURN_CREDENTIAL',
        defaultValue: 'dce515b5a03df3f8a7e322fad08e34014818c149d1b3f326009c49e6069c48e3',
      );

  // Google OAuth Configuration
  static String get googleServerClientId =>
      dotenv.env['GOOGLE_SERVER_CLIENT_ID'] ??
      const String.fromEnvironment(
        'GOOGLE_SERVER_CLIENT_ID',
        defaultValue: '897905079551-spocso10fecnvk87ops09hsefjehnmai.apps.googleusercontent.com',
      );
}
