import 'package:flutter/services.dart';
import 'dart:io' show Platform, Socket;
import '../config/app_config.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class BackendService {
  static const platform = MethodChannel('com.example.quiz_app/backend');
  static final bool _isAndroid = !kIsWeb && Platform.isAndroid;
  // Note: native runtime state is queried via `isBackendRunning()`; no local backing field required.

  /// Start the backend server (Android only)
  static Future<void> startBackend() async {
    // If the app uses Supabase, do not attempt to start local Python backend
    // (we've migrated server logic to Supabase). Also skip on non-Android.
    if (!_isAndroid || (AppConfig.useSupabase)) return;

    try {
      final result = await platform.invokeMethod<String>('startBackend');
      debugPrint('[Backend] native start result: $result');

      // Wait for the backend to accept connections
      final ready = await waitForBackend(timeout: const Duration(seconds: 10));
      if (ready) {
        debugPrint('[Backend] Backend is ready and running on localhost');
      } else {
        debugPrint('[Backend] Backend did not become ready after native start');
      }
    } on PlatformException catch (e) {
      debugPrint('[Backend Error] ${e.message}');
    }
  }

  /// Stop the backend server (Android only)
  static Future<void> stopBackend() async {
    if (!_isAndroid || (AppConfig.useSupabase)) return;

    try {
      final result = await platform.invokeMethod<String>('stopBackend');
      debugPrint('[Backend] $result');
    } on PlatformException catch (e) {
      debugPrint('[Backend Error] ${e.message}');
    }
  }

  /// Check if backend is running (Android only)
  static Future<bool> isBackendRunning() async {
    if (!_isAndroid || (AppConfig.useSupabase)) return false;

    try {
      final result = await platform.invokeMethod<bool>('isBackendRunning') ?? false;
      return result;
    } on PlatformException {
      return false;
    }
  }

  /// Wait for backend to be ready (poll for 30 seconds)
  static Future<bool> waitForBackend({Duration timeout = const Duration(seconds: 30)}) async {
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < timeout) {
      try {
        // Try to connect to local backend
        final socket = await Socket.connect('127.0.0.1', 8000, timeout: const Duration(seconds: 1));
        await socket.close();
        debugPrint('[Backend] Connected successfully!');
        return true;
      } catch (e) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    return false;
  }
}
