/// Supabase Direct Service - Complete Backend Replacement
/// Implements all business logic from Python backend directly in Dart
/// Uses Supabase Flutter SDK instead of manual REST API calls
/// Features:
/// - Admin authentication (register, login, password hashing)
/// - Subject management (CRUD)
/// - Question management (CRUD)
/// - Quiz room management
/// - Player quiz logic
/// - Scoring and leaderboard

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import '../config/app_config.dart';
import 'admin_auth_service.dart';

class SupabaseDirectService {
  // Get singleton instance of Supabase client
  static SupabaseClient get _supabase => Supabase.instance.client;

  // Fallback HTTP client for REST API if needed
  static final _client = http.Client();
  static String get _baseUrl => '${AppConfig.supabaseUrl}/rest/v1';
  static String get _anonKey => AppConfig.supabaseAnonKey;

  // Default headers for fallback HTTP requests
  static Map<String, String> _getHeaders({String? authToken}) => {
    'apikey': _anonKey,
    'Authorization': 'Bearer ${authToken ?? _anonKey}',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  // ============================================
  // AUTHENTICATION LOGIC (from auth.py)
  // ============================================

  /// Hash password using bcrypt-like algorithm
  /// For demo purposes, we'll use SHA256 (production should use bcrypt)
  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Verify password - supports both SHA256 and bcrypt formats
  static bool verifyPassword(String plainPassword, String hashedPassword) {
    // Try SHA256 first (default for this app)
    final sha256Hash = sha256.convert(utf8.encode(plainPassword)).toString();
    if (sha256Hash == hashedPassword) {
      return true;
    }
    
    // If SHA256 doesn't match and hash looks like bcrypt (starts with $2), 
    // it means database has bcrypt but app uses SHA256
    // This is a mismatch - we'll return false and user will need to reset password
    return false;
  }

  /// Register new admin
  static Future<Map<String, dynamic>> adminRegister({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Check if email already exists
      final existing = await _supabase
          .from('admins')
          .select('admin_id')
          .eq('email', email);

      if (existing.isNotEmpty) {
        throw Exception('Email already registered');
      }

      // Create new admin
      final hashedPassword = hashPassword(password);
      final response = await _supabase.from('admins').insert({
        'email': email,
        'password_hash': hashedPassword,
        'full_name': fullName,
      }).select();

      return response[0];
    } catch (e) {
      throw Exception('Registration error: $e');
    }
  }

  /// Admin login
  static Future<Map<String, dynamic>> adminLogin({
    required String email,
    required String password,
  }) async {
    try {
      // Get admin by email
      final response = await _supabase
          .from('admins')
          .select()
          .eq('email', email);

      if (response.isEmpty) {
        throw Exception('Could not validate credentials');
      }

      final admin = response[0] as Map<String, dynamic>;

      // DEBUG: print received plain password length and stored hash (temporary)
      print('DEBUG supabase_direct_service.adminLogin: received password length=' + password.length.toString());
      print('DEBUG supabase_direct_service.adminLogin: stored password_hash=' + (admin['password_hash'] as String));

      // Verify password
      if (!verifyPassword(password, admin['password_hash'] as String)) {
        throw Exception('Could not validate credentials');
      }

      // Create JWT token (simplified - in production use proper JWT library)
      final token = _createToken(admin['admin_id'] as int);

      // Store in AdminAuthService for all future operations
      final adminAuthService = AdminAuthService();
      adminAuthService.setAdminLoggedIn(
        adminId: admin['admin_id'].toString(),
        email: admin['email'] as String,
        fullName: admin['full_name'] as String?,
        token: token,
      );

      return {
        'admin': admin,
        'token': token,
      };
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  /// Create JWT token (simplified version)
  static String _createToken(int adminId) {
    // In production, use proper JWT library
    // This is a placeholder that encodes admin_id
    final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
    final payload = base64Url.encode(utf8.encode('{"sub":"$adminId","iat":${DateTime.now().millisecondsSinceEpoch ~/ 1000}}'));
    // Signature would be HMAC(header.payload, secret)
    // For demo, we'll create a simple signature
    final signature = base64Url.encode(sha256.convert(utf8.encode('$header.$payload')).bytes);
    return '$header.$payload.$signature';
  }

  // ============================================
  // SUBJECT MANAGEMENT (from subjects.py)
  // ============================================

  /// Create subject (for current logged-in admin)
  static Future<Map<String, dynamic>> createSubject({
    required String subjectName,
    String? description,
  }) async {
    try {
      final adminAuth = AdminAuthService();
      if (!adminAuth.isLoggedIn()) {
        throw Exception('Admin not logged in');
      }

      final adminId = adminAuth.adminIdAsInt;
      if (adminId == null) {
        throw Exception('Invalid admin ID');
      }
      // Check existing via SDK
      final existing = await _supabase
          .from('subjects')
          .select()
          .eq('admin_id', adminId)
          .eq('subject_name', subjectName);

      if (existing.isNotEmpty) {
        throw Exception('Subject already exists');
      }

      final res = await _supabase.from('subjects').insert({
        'admin_id': adminId,
        'subject_name': subjectName,
        'description': description,
      }).select();

      if (res is List && res.isNotEmpty) {
        return res[0] as Map<String, dynamic>;
      }
      throw Exception('Failed to create subject: empty response');
    } catch (e) {
      throw Exception('Create subject error: $e');
    }
  }

  /// Get all subjects for current logged-in admin
  static Future<List<Map<String, dynamic>>> getSubjects() async {
    try {
      final adminAuth = AdminAuthService();
      if (!adminAuth.isLoggedIn()) {
        throw Exception('Admin not logged in');
      }

      final adminId = adminAuth.adminIdAsInt;
      if (adminId == null) {
        throw Exception('Invalid admin ID');
      }
        // Select subjects with nested question_sets (only id) so we can compute counts
        // Note: the question_sets primary key is `set_id` (not `question_set_id`).
        final res = await _supabase
          .from('subjects')
          .select('*, question_sets(set_id)')
          .eq('admin_id', adminId)
          .order('subject_id', ascending: false);

      final List<dynamic> data = res as List<dynamic>;
      // Convert each subject and add a convenient `question_set_count` property
      final List<Map<String, dynamic>> out = data.map<Map<String, dynamic>>((item) {
        final Map<String, dynamic> subj = Map<String, dynamic>.from(item as Map);
        final List<dynamic> sets = subj['question_sets'] as List<dynamic>? ?? [];
        subj['question_set_count'] = sets.length;
        return subj;
      }).toList();

      return out;
    } catch (e) {
      throw Exception('Get subjects error: $e');
    }
  }

  /// Get subject details with question sets
  static Future<Map<String, dynamic>> getSubjectDetail(int subjectId) async {
    try {
      // Ensure admin owns the subject
      final adminAuth = AdminAuthService();
      if (!adminAuth.isLoggedIn()) throw Exception('Admin not logged in');
      final adminId = adminAuth.adminIdAsInt;
      if (adminId == null) throw Exception('Invalid admin ID');

      // Get subject filtered by admin
      final subjects = await _supabase.from('subjects').select().eq('subject_id', subjectId).eq('admin_id', adminId);
      if (subjects.isEmpty) {
        throw Exception('Subject not found');
      }
      final subject = subjects[0] as Map<String, dynamic>;

      // Get question sets and nested questions via SDK
      final sets = await _supabase.from('question_sets').select('*, questions(*)').eq('subject_id', subjectId);
      List<dynamic> questionSets = [];
      if (sets is List) {
        questionSets = sets.map((setItem) {
          final set = Map<String, dynamic>.from(setItem as Map);
          final questionsRaw = set['questions'] as List<dynamic>? ?? [];
          set['questions'] = questionsRaw.map((q) {
            final question = q as Map<String, dynamic>;
            return {
              'question_id': question['question_id'],
              'question_text': question['question_text'],
              'difficulty': question['difficulty'],
              'options': [
                question['option_a'],
                question['option_b'],
                question['option_c'],
                question['option_d'],
              ],
              'correct_answer_index': _convertAnswerToIndex(question['correct_answer']),
            };
          }).toList();
          return set;
        }).toList();
      }

      subject['question_sets'] = questionSets;
      return subject;
    } catch (e) {
      throw Exception('Get subject detail error: $e');
    }
  }

  /// Update subject
  static Future<Map<String, dynamic>> updateSubject({
    required int subjectId,
    String? subjectName,
    String? description,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (subjectName != null) updateData['subject_name'] = subjectName;
      if (description != null) updateData['description'] = description;

      final res = await _supabase.from('subjects').update(updateData).eq('subject_id', subjectId).select();
      if (res is List && res.isNotEmpty) {
        return res[0] as Map<String, dynamic>;
      }
      throw Exception('Failed to update subject: empty response');
    } catch (e) {
      throw Exception('Update subject error: $e');
    }
  }

  /// Delete subject
  static Future<void> deleteSubject(int subjectId) async {
    try {
      await _supabase.from('subjects').delete().eq('subject_id', subjectId).select();
      // Deletion successful if request didn't throw. If needed, validate response.
    } catch (e) {
      throw Exception('Delete subject error: $e');
    }
  }

  // ============================================
  // QUESTION SET MANAGEMENT
  // ============================================

  /// Create question set
  static Future<Map<String, dynamic>> createQuestionSet({
    required int subjectId,
    required String setName,
    String? description,
  }) async {
    final adminId = AdminAuthService.instance.adminIdAsInt;
    if (adminId == null) {
      throw Exception('Admin not logged in');
    }

    try {
      final payload = {
        'subject_id': subjectId,
        'admin_id': adminId,
        'set_name': setName,
        'description': description,
        'total_questions': 0,
      };

      final res = await _supabase.from('question_sets').insert(payload).select();
      if (res is List && res.isNotEmpty) {
        return res[0] as Map<String, dynamic>;
      }
      throw Exception('Failed to create question set: empty response');
    } catch (e) {
      throw Exception('Create question set error: $e');
    }
  }

  /// Get question sets for subject
  static Future<List<Map<String, dynamic>>> getQuestionSets(int subjectId) async {
    try {
      // Filter question sets by the logged-in admin to enforce isolation
      final adminAuth = AdminAuthService();
      if (!adminAuth.isLoggedIn()) throw Exception('Admin not logged in');
      final adminId = adminAuth.adminIdAsInt;
      if (adminId == null) throw Exception('Invalid admin ID');

      final res = await _supabase.from('question_sets').select().eq('subject_id', subjectId).eq('admin_id', adminId).order('set_id', ascending: false);
      final List<dynamic> data = res as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Get question sets error: $e');
    }
  }

  // ============================================
  // QUESTION MANAGEMENT (from questions.py)
  // ============================================

  /// Create question (for current logged-in admin)
  static Future<Map<String, dynamic>> createQuestion({
    required String questionText,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required String correctAnswer,
    String difficulty = 'medium',
    int? setId,
    String? category,
  }) async {
    try {
      final adminAuth = AdminAuthService();
      if (!adminAuth.isLoggedIn()) {
        throw Exception('Admin not logged in');
      }

      final adminId = adminAuth.adminIdAsInt;
      if (adminId == null) {
        throw Exception('Invalid admin ID');
      }

      final payload = {
        'admin_id': adminId,
        'question_text': questionText,
        'option_a': optionA,
        'option_b': optionB,
        'option_c': optionC,
        'option_d': optionD,
        'correct_answer': correctAnswer,
        'difficulty': difficulty,
      };
      if (setId != null) payload['set_id'] = setId;
      if (category != null) payload['category'] = category;

      final res = await _supabase.from('questions').insert(payload).select();
      if (res is List && res.isNotEmpty) {
        if (setId != null) {
          await _updateQuestionSetCount(setId);
        }
        return res[0] as Map<String, dynamic>;
      }
      throw Exception('Failed to create question: empty response');
    } catch (e) {
      throw Exception('Create question error: $e');
    }
  }

  /// Get questions
  static Future<List<Map<String, dynamic>>> getQuestions({
    int? setId,
    int? adminId,
    String? difficulty,
    int limit = 50,
  }) async {
    try {
      // Use SDK for queries; apply filters before ordering/limiting
      dynamic query = _supabase.from('questions').select();
      if (setId != null) query = query.eq('set_id', setId);
      if (adminId != null) query = query.eq('admin_id', adminId);
      if (difficulty != null) query = query.eq('difficulty', difficulty);
      query = query.order('question_id', ascending: false).limit(limit);
      final res = await query;
      final List<dynamic> data = res as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Get questions error: $e');
    }
  }

  /// Delete question
  static Future<void> deleteQuestion(int questionId) async {
    try {
      await _supabase.from('questions').delete().eq('question_id', questionId).select();
    } catch (e) {
      throw Exception('Delete question error: $e');
    }
  }

  // ============================================
  // QUIZ ROOM MANAGEMENT (from rooms.py)
  // ============================================

  /// Generate room code
  static String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Create quiz room (for current logged-in admin)
  static Future<Map<String, dynamic>> createQuizRoom({
    required String roomName,
    required String theme,
    String? description,
    int totalQuestions = 20,
    int timeLimitPerQuestion = 30,
    int maxParticipants = 50,
    List<int>? questionIds,
  }) async {
    try {
      final adminAuth = AdminAuthService();
      if (!adminAuth.isLoggedIn()) {
        throw Exception('Admin not logged in');
      }

      final adminId = adminAuth.adminIdAsInt;
      if (adminId == null) {
        throw Exception('Invalid admin ID');
      }

      // Try inserting via Supabase SDK and handle possible room_code collisions
      int attempts = 0;
      while (attempts < 6) {
        attempts += 1;
        final roomCode = _generateRoomCode();
        final payload = {
          'admin_id': adminId,
          'room_code': roomCode,
          'room_name': roomName,
          'theme': theme,
          'description': description,
          'status': 'draft',
          'total_questions': totalQuestions,
          'time_limit_per_question': timeLimitPerQuestion,
          'max_participants': maxParticipants,
        };

        final res = await _supabase.from('quiz_rooms').insert(payload).select();
        if (res == null) {
          // Unexpected null response
          throw Exception('Failed to create room: empty response');
        }

        // If insert succeeded, PostgREST returns a List-like response
        if (res is List && res.isNotEmpty) {
          final created = res[0] as Map<String, dynamic>;
          // If caller provided question IDs, attach them to the room
          try {
            if (questionIds != null && questionIds.isNotEmpty) {
              final createdRoomId = created['room_id'] is int
                  ? created['room_id'] as int
                  : int.tryParse('${created['room_id']}') ?? 0;
              if (createdRoomId > 0) {
                await addQuestionsToRoom(roomId: createdRoomId, questionIds: questionIds);
              }
            }
          } catch (_) {
            // non-fatal: return created room even if attaching questions failed
          }
          return created;
        }

        // Otherwise, check for errors via client REST fallback
        // We'll attempt again if there's a duplicate room_code
      }
      throw Exception('Failed to create room after multiple attempts (code collisions)');
    } catch (e) {
      throw Exception('Create room error: $e');
    }
  }

  /// Get quiz rooms for current logged-in admin
  static Future<List<Map<String, dynamic>>> getQuizRooms({
    String? status,
  }) async {
    try {
      final adminAuth = AdminAuthService();
      if (!adminAuth.isLoggedIn()) {
        throw Exception('Admin not logged in');
      }

      final adminId = adminAuth.adminIdAsInt;
      if (adminId == null) {
        throw Exception('Invalid admin ID');
      }

      final queryParams = {
        'admin_id': 'eq.$adminId',
        'order': 'created_at.desc',
      };
      if (status != null) {
        queryParams['status'] = 'eq.$status';
      }

      // Use SDK: filter first, then order
      dynamic q = _supabase.from('quiz_rooms').select().eq('admin_id', adminId);
      if (status != null) q = q.eq('status', status);
      q = q.order('created_at', ascending: false);
      final res = await q;
      final List<dynamic> data = res as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Get rooms error: $e');
    }
  }

  /// Get room by code
  static Future<Map<String, dynamic>> getRoomByCode(String roomCode) async {
    try {
      final res = await _supabase.from('quiz_rooms').select().eq('room_code', roomCode);
      if (res is List && res.isNotEmpty) {
        return res[0] as Map<String, dynamic>;
      }
      throw Exception('Room not found');
    } catch (e) {
      throw Exception('Get room error: $e');
    }
  }

  /// Get admin dashboard stats (questions count, active rooms, total players)
  static Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final adminAuth = AdminAuthService();
      if (!adminAuth.isLoggedIn()) throw Exception('Admin not logged in');
      final adminId = adminAuth.adminIdAsInt;
      if (adminId == null) throw Exception('Invalid admin ID');

      // Total questions authored by this admin
      final questionsRes = await _supabase.from('questions').select().eq('admin_id', adminId);
      final int totalQuestions = (questionsRes is List) ? (questionsRes as List).length : 0;

      // Active rooms
      final activeRoomsRes = await _supabase.from('quiz_rooms').select().eq('admin_id', adminId).eq('status', 'active');
      final int activeRooms = (activeRoomsRes is List) ? (activeRoomsRes as List).length : 0;

      // Total players across this admin's rooms
      final roomsRes = await _supabase.from('quiz_rooms').select('room_id').eq('admin_id', adminId);
      int totalPlayers = 0;
      if (roomsRes is List && roomsRes.isNotEmpty) {
        final roomIds = (roomsRes as List<dynamic>).map((r) => (r as Map)['room_id']).toList();
        if (roomIds.isNotEmpty) {
          final participantsRes = await _supabase.from('participants').select().in_('room_id', roomIds);
          totalPlayers = (participantsRes is List) ? (participantsRes as List).length : 0;
        }
      }

      return {
        'total_questions': totalQuestions,
        'active_rooms': activeRooms,
        'total_players': totalPlayers,
      };
    } catch (e) {
      throw Exception('Get admin stats error: $e');
    }
  }

  /// Start quiz room
  static Future<Map<String, dynamic>> startQuizRoom(int roomId) async {
    try {
      final res = await _supabase.from('quiz_rooms').update({
        'status': 'active',
        'started_at': DateTime.now().toIso8601String(),
      }).eq('room_id', roomId).select();
      if (res is List && res.isNotEmpty) return res[0] as Map<String, dynamic>;
      throw Exception('Failed to start room: empty response');
    } catch (e) {
      throw Exception('Start room error: $e');
    }
  }

  /// Finish quiz room
  static Future<Map<String, dynamic>> finishQuizRoom(int roomId) async {
    try {
      final res = await _supabase.from('quiz_rooms').update({
        'status': 'finished',
        'finished_at': DateTime.now().toIso8601String(),
      }).eq('room_id', roomId).select();

      if (res is List && res.isNotEmpty) return res[0] as Map<String, dynamic>;
      throw Exception('Failed to finish room: empty response');
    } catch (e) {
      throw Exception('Finish room error: $e');
    }
  }

  /// Add questions to room
  static Future<void> addQuestionsToRoom({
    required int roomId,
    required List<int> questionIds,
  }) async {
    try {
      // Use batch insert via Supabase SDK for better error handling
      final rows = List.generate(questionIds.length, (i) {
        return {
          'room_id': roomId,
          'question_id': questionIds[i],
          'question_order': i + 1,
        };
      });

      final res = await _supabase.from('room_questions').insert(rows).select();
      // If res is a list, insertion succeeded; otherwise an exception will be thrown
      if (res == null) {
        throw Exception('Failed to add questions to room: empty response');
      }
    } catch (e) {
      throw Exception('Add questions to room error: $e');
    }
  }

  /// Get room questions
  static Future<List<Map<String, dynamic>>> getRoomQuestions(int roomId) async {
    try {
      final res = await _supabase.from('room_questions').select('*,questions(*)').eq('room_id', roomId).order('question_order', ascending: true);
      final List<dynamic> data = res as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Get room questions error: $e');
    }
  }

  // ============================================
  // PLAYER LOGIC (from player.py)
  // ============================================

  /// Join quiz room (create participant)
  static Future<Map<String, dynamic>> joinQuizRoom({
    required int roomId,
    required String nickname,
  }) async {
    try {
      // Get room to check max_participants
      final rooms = await _supabase.from('quiz_rooms').select().eq('room_id', roomId);
      if (rooms.isNotEmpty) {
        final room = rooms[0] as Map<String, dynamic>;
        final maxParticipants = room['max_participants'] as int? ?? 50;

        // Count current participants via SDK
        final participants = await _supabase.from('participants').select().eq('room_id', roomId);
        final int currentCount = (participants as List<dynamic>).length;

        if (currentCount >= maxParticipants) {
          throw Exception('Room is full');
        }
      }

      // Create participant via SDK
      final sessionToken = _generateSessionToken();
      final payload = {
        'room_id': roomId,
        'nickname': nickname,
        'session_token': sessionToken,
        'position': 0,
        'total_correct': 0,
        'total_answered': 0,
      };

      final res = await _supabase.from('participants').insert(payload).select();
      if (res is List && res.isNotEmpty) {
        return res[0] as Map<String, dynamic>;
      }
      throw Exception('Failed to join room: empty response');
    } catch (e) {
      throw Exception('Join room error: $e');
    }
  }

  /// Generate session token
  static String _generateSessionToken() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(100000).toString();
  }

  /// Select character for participant
  static Future<Map<String, dynamic>> selectCharacter({
    required int participantId,
    required String character,
  }) async {
    try {
      final res = await _supabase.from('participants').update({
        'selected_character': character,
      }).eq('participant_id', participantId).select();

      if (res is List && res.isNotEmpty) return res[0] as Map<String, dynamic>;
      throw Exception('Failed to select character: empty response');
    } catch (e) {
      throw Exception('Select character error: $e');
    }
  }

  /// Submit answer
  static Future<Map<String, dynamic>> submitAnswer({
    required int participantId,
    required int questionId,
    required int roomId,
    required String answer,
    int timeTaken = 0,
  }) async {
    try {
      // Get question to verify answer via SDK
      final qRes = await _supabase.from('questions').select().eq('question_id', questionId);
      if (qRes is! List || qRes.isEmpty) throw Exception('Question not found');
      final question = qRes[0] as Map<String, dynamic>;
      final correctAnswer = question['correct_answer'] as String;
      final isCorrect = answer.toUpperCase() == correctAnswer;

      // Record attempt via SDK (use selected_answer field to match history mapping)
      final attemptPayload = {
        'participant_id': participantId,
        'question_id': questionId,
        'room_id': roomId,
        'selected_answer': answer,
        'is_correct': isCorrect,
        'time_taken': timeTaken,
      };

      final attemptRes = await _supabase.from('attempts').insert(attemptPayload).select();
      if (attemptRes is! List || attemptRes.isEmpty) throw Exception('Failed to submit attempt');
      
      // Update participant stats (do not increment total_time here except at finish)
      try {
        // Fetch current participant
        final partRes = await _supabase.from('participants').select().eq('participant_id', participantId);
        if (partRes is List && partRes.isNotEmpty) {
          final participant = Map<String, dynamic>.from(partRes[0] as Map);
          final currentCorrect = (participant['total_correct'] as int?) ?? 0;
          final currentAnswered = (participant['total_answered'] as int?) ?? 0;

          final newAnswered = currentAnswered + 1;

          final updateData = <String, dynamic>{'total_answered': newAnswered};
          if (isCorrect) {
            updateData['total_correct'] = currentCorrect + 1;
          }
          // ensure started_at is set
          if (participant['started_at'] == null) {
            updateData['started_at'] = DateTime.now().toIso8601String();
          }

          await _supabase.from('participants').update(updateData).eq('participant_id', participantId).select();

          // Check if participant has finished (answered all questions)
          final roomsRes = await _supabase.from('quiz_rooms').select().eq('room_id', roomId);
          final room = (roomsRes is List && roomsRes.isNotEmpty) ? roomsRes[0] as Map<String, dynamic> : null;
          final int totalQuestions = (room != null && room['total_questions'] != null)
              ? (room['total_questions'] is int ? room['total_questions'] as int : int.tryParse(room['total_questions'].toString() ?? '') ?? 0)
              : 0;

          if (totalQuestions > 0 && newAnswered >= totalQuestions) {
            // compute authoritative total time from attempts
            final attemptsResAll = await _supabase.from('attempts').select().eq('participant_id', participantId).eq('room_id', roomId);
            int sumTime = 0;
            if (attemptsResAll is List) {
              for (final a in attemptsResAll) {
                final amap = Map<String, dynamic>.from(a as Map);
                final int t = (amap['time_taken'] is int) ? amap['time_taken'] as int : int.tryParse(amap['time_taken']?.toString() ?? '') ?? 0;
                sumTime += t;
              }
            }

            final finalUpdate = {
              'total_time_taken': sumTime,
              'finished_at': DateTime.now().toIso8601String(),
            };

            await _supabase.from('participants').update(finalUpdate).eq('participant_id', participantId).select();
          }
        }
      } catch (_) {
        // non-fatal if participant update fails
      }

      return {
        'is_correct': isCorrect,
        'correct_answer': correctAnswer,
        'attempt': (attemptRes[0] as Map<String, dynamic>),
      };
    } catch (e) {
      throw Exception('Submit answer error: $e');
    }
  }

  /// Get participant stats
  static Future<Map<String, dynamic>> getParticipantStats(int participantId) async {
    try {
      final res = await _supabase.from('participants').select().eq('participant_id', participantId);
      if (res is List && res.isNotEmpty) return res[0] as Map<String, dynamic>;
      throw Exception('Participant not found');
    } catch (e) {
      throw Exception('Get participant stats error: $e');
    }
  }

  /// Get leaderboard for room
  static Future<List<Map<String, dynamic>>> getLeaderboard(int roomId) async {
    try {
      final res = await _supabase.from('participants').select().eq('room_id', roomId).order('total_correct', ascending: false).order('total_time_taken', ascending: true);
      final List<dynamic> data = res as List<dynamic>;
      final leaderboard = data.asMap().entries.map((entry) {
        final participant = Map<String, dynamic>.from(entry.value as Map);
        participant['position'] = entry.key + 1;
        return participant;
      }).toList();
      return leaderboard.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Get leaderboard error: $e');
    }
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  // ============================================
  // ADDITIONAL HELPER METHODS
  // ============================================

  /// Get room info before joining
  static Future<Map<String, dynamic>> getRoomInfo(String roomCode) async {
    try {
      // Ensure admin is logged in and owns the room
      final adminAuth = AdminAuthService();
      if (!adminAuth.isLoggedIn()) throw Exception('Admin not logged in');
      final adminId = adminAuth.adminIdAsInt;
      if (adminId == null) throw Exception('Invalid admin ID');

      final roomsRes = await _supabase.from('quiz_rooms').select().eq('room_code', roomCode).eq('admin_id', adminId);
      if (roomsRes is! List || roomsRes.isEmpty) throw Exception('Room not found');
      final room = roomsRes[0] as Map<String, dynamic>;

      // Load participants for this room and annotate useful fields for the admin UI
      final participantsRes = await _supabase
          .from('participants')
          .select()
          .eq('room_id', room['room_id'])
          .order('total_correct', ascending: false)
          .order('total_time_taken', ascending: true);

      List<Map<String, dynamic>> participants = [];
      if (participantsRes is List) {
        participants = (participantsRes as List<dynamic>).map((p) {
          final part = Map<String, dynamic>.from(p as Map);
          final int totalAnswered = (part['total_answered'] as int?) ?? 0;
          final int totalQuestions = (room['total_questions'] as int?) ?? 0;
          final bool isAnswered = (part['finished_at'] != null) || totalAnswered >= totalQuestions;
          part['is_answered'] = isAnswered;
          part['max_score'] = totalQuestions;
          return part;
        }).toList();
      }

      final int currentParticipants = participants.length;

      return {
        'room_id': room['room_id'],
        'room_code': room['room_code'],
        'room_name': room['room_name'],
        'theme': room['theme'],
        'description': room['description'],
        'status': room['status'],
        'total_questions': room['total_questions'],
        'current_participants': currentParticipants,
        'max_participants': room['max_participants'],
        'participants': participants,
      };
    } catch (e) {
      throw Exception('Get room info error: $e');
    }
  }

  /// Start quiz - load first question
  static Future<Map<String, dynamic>> startQuiz({
    required int roomId,
    required int participantId,
    required String character,
  }) async {
    try {
      // Update participant selected character
      await selectCharacter(
        participantId: participantId,
        character: character,
      );
      // Get first question (order 1) via SDK
      final rq = await _supabase.from('room_questions').select('*,questions(*)').eq('room_id', roomId).eq('question_order', 1);
      if (rq is! List || rq.isEmpty) throw Exception('Quiz questions not found');
      final roomQuestion = rq[0] as Map<String, dynamic>;
      final question = roomQuestion['questions'] as Map<String, dynamic>;

      // Get room details
      final roomsRes = await _supabase.from('quiz_rooms').select().eq('room_id', roomId);
      final room = (roomsRes is List && roomsRes.isNotEmpty) ? roomsRes[0] as Map<String, dynamic> : null;
      if (room == null) throw Exception('Room not found');

      return {
        'quiz_session': {
          'room_id': roomId,
          'total_questions': room['total_questions'],
          'current_question': 1,
          'question': {
            'question_id': question['question_id'],
            'question_text': question['question_text'],
            'option_a': question['option_a'],
            'option_b': question['option_b'],
            'option_c': question['option_c'],
            'option_d': question['option_d'],
          },
          'time_limit': room['time_limit_per_question'],
          'status': 'playing',
        }
      };
    } catch (e) {
      throw Exception('Start quiz error: $e');
    }
  }

  /// Get specific question by number
  static Future<Map<String, dynamic>> getQuestion({
    required int roomId,
    required int questionNumber,
  }) async {
    try {
      final roomsRes = await _supabase.from('quiz_rooms').select().eq('room_id', roomId);
      if (roomsRes is! List || roomsRes.isEmpty) throw Exception('Room not found');
      final room = roomsRes[0] as Map<String, dynamic>;

      final rq = await _supabase.from('room_questions').select('*,questions(*)').eq('room_id', roomId).eq('question_order', questionNumber);
      if (rq is! List || rq.isEmpty) throw Exception('Question not found');
      final roomQuestion = rq[0] as Map<String, dynamic>;
      final question = roomQuestion['questions'] as Map<String, dynamic>;

      return {
        'question_number': questionNumber,
        'total_questions': room['total_questions'],
        'question': {
          'question_id': question['question_id'],
          'question_text': question['question_text'],
          'option_a': question['option_a'],
          'option_b': question['option_b'],
          'option_c': question['option_c'],
          'option_d': question['option_d'],
        },
        'time_limit': room['time_limit_per_question'],
      };
    } catch (e) {
      throw Exception('Get question error: $e');
    }
  }

  /// Get participant's answer history
  static Future<Map<String, dynamic>> getAnswerHistory({
    required int participantId,
    required int roomId,
  }) async {
    try {
      final partRes = await _supabase.from('participants').select().eq('participant_id', participantId);
      if (partRes is! List || partRes.isEmpty) throw Exception('Participant not found');
      final participant = partRes[0] as Map<String, dynamic>;

      final roomsRes = await _supabase.from('quiz_rooms').select().eq('room_id', roomId);
      if (roomsRes is! List || roomsRes.isEmpty) throw Exception('Room not found');
      final room = roomsRes[0] as Map<String, dynamic>;

      final attemptsRes = await _supabase.from('attempts').select('*,questions(*)').eq('participant_id', participantId).eq('room_id', roomId).order('created_at', ascending: true);
      List<Map<String, dynamic>> attemptsData = [];
      if (attemptsRes is List) {
        attemptsData = (attemptsRes as List<dynamic>).asMap().entries.map((entry) {
          final attempt = Map<String, dynamic>.from(entry.value as Map);
          final question = attempt['questions'] as Map<String, dynamic>;
          return {
            'question_number': entry.key + 1,
            'question_id': question['question_id'],
            'question_text': question['question_text'],
            'selected_answer': attempt['selected_answer'],
            'correct_answer': question['correct_answer'],
            'is_correct': attempt['is_correct'],
            'time_taken': attempt['time_taken'],
          };
        }).toList();
      }

      return {
        'nickname': participant['nickname'],
        'room_id': roomId,
        'room_name': room['room_name'],
        'attempts': attemptsData,
      };
    } catch (e) {
      throw Exception('Get answer history error: $e');
    }
  }

  /// Get quiz results
  static Future<Map<String, dynamic>> getQuizResults({
    required int participantId,
    required int roomId,
  }) async {
    try {
      final partRes = await _supabase.from('participants').select().eq('participant_id', participantId);
      if (partRes is! List || partRes.isEmpty) throw Exception('Participant not found');
      final participant = partRes[0] as Map<String, dynamic>;

      final roomsRes = await _supabase.from('quiz_rooms').select().eq('room_id', roomId);
      if (roomsRes is! List || roomsRes.isEmpty) throw Exception('Room not found');
      final room = roomsRes[0] as Map<String, dynamic>;

      final leaderboard = await getLeaderboard(roomId);
      final userRank = leaderboard.indexWhere((p) => p['participant_id'] == participantId) + 1;

      final accuracy = (participant['total_answered'] ?? 0) > 0
          ? ((participant['total_correct'] ?? 0) / (participant['total_answered'] ?? 1) * 100)
          : 0.0;

      return {
        'room_id': roomId,
        'room_name': room['room_name'],
        'theme': room['theme'],
        'participant': {
          'nickname': participant['nickname'],
          'rank': userRank,
          'position': participant['position'],
          'character_level': participant['character_level'],
          'total_correct': participant['total_correct'],
          'total_answered': participant['total_answered'],
          'accuracy': '${accuracy.toStringAsFixed(1)}%',
          'selected_character': participant['selected_character'],
        },
        'leaderboard_final': leaderboard
            .asMap()
            .entries
            .map((entry) {
              final p = entry.value;
              return {
                'rank': entry.key + 1,
                'nickname': p['nickname'],
                'position': p['position'],
                'total_correct': p['total_correct'],
                'selected_character': p['selected_character'],
              };
            })
            .toList(),
      };
    } catch (e) {
      throw Exception('Get quiz results error: $e');
    }
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  /// Convert answer letter to index (A=0, B=1, C=2, D=3)
  static int _convertAnswerToIndex(String answer) {
    return answer.toUpperCase().codeUnitAt(0) - 'A'.codeUnitAt(0);
  }

  /// Update question set total question count
  static Future<void> _updateQuestionSetCount(int setId) async {
    try {
      final res = await _supabase.from('questions').select().eq('set_id', setId);
      final int count = (res is List) ? res.length : 0;
      await _supabase.from('question_sets').update({'total_questions': count}).eq('set_id', setId).select();
    } catch (e) {
      // Silent fail for count updates
    }
  }

  // ============================================
  // ROOM STATUS METHODS
  // ============================================

  /// Start a quiz room (mark as started)
  static Future<void> startRoom(int roomId) async {
    final adminId = AdminAuthService.instance.adminId;
    if (adminId == null) {
      throw Exception('Admin not logged in');
    }

    try {
      final res = await _supabase.from('quiz_rooms').update({'status': 'active', 'started_at': DateTime.now().toIso8601String()}).eq('room_id', roomId).eq('admin_id', int.parse(adminId)).select();
      if (res is! List || res.isEmpty) throw Exception('Failed to start room');
    } catch (e) {
      throw Exception('Failed to start room: ${e.toString()}');
    }
  }

  /// Finish a quiz room (mark as finished)
  static Future<void> finishRoom(int roomId) async {
    final adminId = AdminAuthService.instance.adminId;
    if (adminId == null) {
      throw Exception('Admin not logged in');
    }

    try {
      // DB uses `finished_at` timestamp column (not `ended_at`).
      final res = await _supabase.from('quiz_rooms').update({'status': 'finished', 'finished_at': DateTime.now().toIso8601String()}).eq('room_id', roomId).eq('admin_id', int.parse(adminId)).select();
      if (res is! List || res.isEmpty) throw Exception('Failed to finish room');
    } catch (e) {
      throw Exception('Failed to finish room: ${e.toString()}');
    }
  }
}
