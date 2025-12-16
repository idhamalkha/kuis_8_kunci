import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// App Configuration
class AppConfig {
  // API Base URL - detect platform and use local backend on Android
  static String get apiBaseUrl {
    // If a runtime override is set, use it
    if (_overrideApiBaseUrl != null && _overrideApiBaseUrl!.isNotEmpty) {
      return _overrideApiBaseUrl!;
    }

    // Web platform doesn't support Platform.isAndroid
    if (!kIsWeb && Platform.isAndroid) {
      // Default to local backend on Android (when running a native backend)
      return 'http://127.0.0.1:8000';
    }

    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8000',
    );
  }

  static const String apiVersion = '/api/v1';

  static String get fullApiUrl => '$apiBaseUrl$apiVersion';

  // WebSocket URL
  static String get wsBaseUrl => fullApiUrl.replaceFirst('http', 'ws');

  // Runtime override for API base URL (can be set if local backend is unavailable)
  static String? _overrideApiBaseUrl;

  static void setApiBaseUrlOverride(String? url) {
    _overrideApiBaseUrl = url;
  }

  // Use Supabase instead of local Python backend when true
  // Set to `true` to use direct Supabase (no backend hosting needed)
  static bool useSupabase = true;

  // Supabase configuration (can be provided at build time with --dart-define)
  static String get supabaseUrl => const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kijibpnmaxbubuzpajuj.supabase.co',
  );

  // For client-side access, using REST API with service key (for demo)
  // In production, generate JWT tokens server-side or use proper Supabase Auth
  static String get supabaseServiceKey => const String.fromEnvironment(
    'SUPABASE_SERVICE_KEY',
    defaultValue: 'sb_secret_hh9t9GgMC2Fd0seWNn5Hwg_oJvLr_xz',
  );

  static String get supabaseAnonKey => const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_3Zad8iXdVQ9ta1sHB_FpLA_vZdsgaDy',
  );

  static bool get hasSupabaseCredentials => supabaseUrl.isNotEmpty && (supabaseAnonKey.isNotEmpty || supabaseServiceKey.isNotEmpty);

  // Timeouts
  static const int connectTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds

  // App Info
  static const String appName = 'Kuis 8 Kunci';
  static const String appVersion = '1.0.0';

  // Quiz Settings
  static const int totalQuestions = 20;
  static const int defaultTimePerQuestion = 30; // seconds

  // Themes for characters
  static const List<String> availableThemes = [
    'tree',
    'mountain',
    'ladder',
    'tower',
    'planet'
  ];

  // Storage Keys
  static const String sessionTokenKey = 'session_token';
  static const String roomCodeKey = 'room_code';
  static const String nicknameKey = 'nickname';
  static const String adminTokenKey = 'admin_token';
}
