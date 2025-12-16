/// Storage Service - Local Data Persistence

import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

import '../config/app_config.dart';

class StorageService {
  final logger = Logger();
  late SharedPreferences _prefs;

  static final StorageService _instance = StorageService._internal();

  factory StorageService() {
    return _instance;
  }

  StorageService._internal();

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      logger.i('Storage service initialized');
    } catch (e) {
      logger.e('Error initializing storage: $e');
      rethrow;
    }
  }

  // ============================================
  // SESSION MANAGEMENT
  // ============================================

  Future<void> saveSessionToken(String token) async {
    try {
      await _prefs.setString(AppConfig.sessionTokenKey, token);
      logger.i('Session token saved');
    } catch (e) {
      logger.e('Error saving session token: $e');
    }
  }

  String? getSessionToken() {
    try {
      return _prefs.getString(AppConfig.sessionTokenKey);
    } catch (e) {
      logger.e('Error getting session token: $e');
      return null;
    }
  }

  Future<void> clearSessionToken() async {
    try {
      await _prefs.remove(AppConfig.sessionTokenKey);
      logger.i('Session token cleared');
    } catch (e) {
      logger.e('Error clearing session token: $e');
    }
  }

  // ============================================
  // ROOM INFORMATION
  // ============================================

  Future<void> saveRoomCode(String roomCode) async {
    try {
      await _prefs.setString(AppConfig.roomCodeKey, roomCode);
      logger.i('Room code saved');
    } catch (e) {
      logger.e('Error saving room code: $e');
    }
  }

  String? getRoomCode() {
    try {
      return _prefs.getString(AppConfig.roomCodeKey);
    } catch (e) {
      logger.e('Error getting room code: $e');
      return null;
    }
  }

  Future<void> clearRoomCode() async {
    try {
      await _prefs.remove(AppConfig.roomCodeKey);
      logger.i('Room code cleared');
    } catch (e) {
      logger.e('Error clearing room code: $e');
    }
  }

  // ============================================
  // PLAYER INFORMATION
  // ============================================

  Future<void> saveNickname(String nickname) async {
    try {
      await _prefs.setString(AppConfig.nicknameKey, nickname);
      logger.i('Nickname saved: $nickname');
    } catch (e) {
      logger.e('Error saving nickname: $e');
    }
  }

  String? getNickname() {
    try {
      return _prefs.getString(AppConfig.nicknameKey);
    } catch (e) {
      logger.e('Error getting nickname: $e');
      return null;
    }
  }

  Future<void> clearNickname() async {
    try {
      await _prefs.remove(AppConfig.nicknameKey);
      logger.i('Nickname cleared');
    } catch (e) {
      logger.e('Error clearing nickname: $e');
    }
  }

  // ============================================
  // ADMIN TOKEN
  // ============================================

  Future<void> saveAdminToken(String token) async {
    try {
      await _prefs.setString(AppConfig.adminTokenKey, token);
      logger.i('Admin token saved');
    } catch (e) {
      logger.e('Error saving admin token: $e');
    }
  }

  String? getAdminToken() {
    try {
      return _prefs.getString(AppConfig.adminTokenKey);
    } catch (e) {
      logger.e('Error getting admin token: $e');
      return null;
    }
  }

  Future<void> clearAdminToken() async {
    try {
      await _prefs.remove(AppConfig.adminTokenKey);
      logger.i('Admin token cleared');
    } catch (e) {
      logger.e('Error clearing admin token: $e');
    }
  }

  // ============================================
  // BATCH OPERATIONS
  // ============================================

  Future<void> clearAll() async {
    try {
      await _prefs.clear();
      logger.i('All storage cleared');
    } catch (e) {
      logger.e('Error clearing storage: $e');
    }
  }

  Future<void> clearPlayerSession() async {
    try {
      await clearSessionToken();
      await clearRoomCode();
      await clearNickname();
      logger.i('Player session cleared');
    } catch (e) {
      logger.e('Error clearing player session: $e');
    }
  }
}
