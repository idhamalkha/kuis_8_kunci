/// API Service - HTTP Client for all API calls

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'dart:convert';

import '../config/app_config.dart';
import 'supabase_service.dart';
import 'supabase_direct_service.dart';
import '../models/api_models.dart';

class ApiService {
  final logger = Logger();
  String? _sessionToken;
  String? _adminToken;

  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();

  // ============================================
  // AUTHENTICATION
  // ============================================

  Future<AdminLoginResponse> adminLogin({
    required String email,
    required String password,
  }) async {
    try {
      // Use Supabase REST API directly
      if (AppConfig.useSupabase && AppConfig.hasSupabaseCredentials) {
        // Use SupabaseDirectService which handles password hashing and token creation
        final resp = await SupabaseDirectService.adminLogin(email: email, password: password);
        final admin = resp['admin'] as Map<String, dynamic>;
        final token = resp['token'] as String;
        final adminResponse = AdminLoginResponse(
          accessToken: token,
          tokenType: 'Bearer',
          adminId: admin['admin_id'] as int,
          email: admin['email'] as String,
          fullName: admin['full_name'] as String?,
        );
        _adminToken = adminResponse.accessToken;
        logger.i('Admin login successful (supabase): ${admin['email']}');
        return adminResponse;
      }

      // Fallback to local Python backend
      final response = await http.post(
        Uri.parse('${AppConfig.fullApiUrl}/auth/admin/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(milliseconds: AppConfig.connectTimeout));

      if (response.statusCode == 200) {
        final data = AdminLoginResponse.fromJson(jsonDecode(response.body));
        _adminToken = data.accessToken;
        logger.i('Admin login successful (Local Backend)');
        return data;
      } else {
        throw Exception('Login failed: ${response.body}');
      }
    } catch (e) {
      logger.e('Admin login error: $e');
      rethrow;
    }
  }

  // ============================================
  // PLAYER JOIN & ROOM
  // ============================================

  Future<PlayerJoinResponse> joinRoom({
    required String roomCode,
    required String nickname,
  }) async {
    if (AppConfig.useSupabase) {
      try {
        final room = await SupabaseService.getRoomByCode(roomCode);
        if (room == null) throw Exception('Room not found');
        final Map<String, dynamic>? participant = await SupabaseService.joinRoom({
          'room_id': room['room_id'],
          'nickname': nickname,
        });

        if (participant == null) throw Exception('Failed to join room');

        // Build PlayerJoinResponse-like object
        final resp = PlayerJoinResponse(
          participantId: (participant['participant_id'] is int) ? participant['participant_id'] as int : int.tryParse('${participant['participant_id']}') ?? 0,
          roomId: (participant['room_id'] is int) ? participant['room_id'] as int : int.tryParse('${participant['room_id']}') ?? 0,
          roomName: room['room_name'] as String? ?? '',
          theme: room['theme'] as String? ?? '',
          sessionToken: participant['session_token'] as String? ?? '',
          totalQuestions: (room['total_questions'] is int) ? room['total_questions'] as int : int.tryParse('${room['total_questions']}') ?? 20,
          timeLimitPerQuestion: (room['time_limit_per_question'] is int) ? room['time_limit_per_question'] as int : int.tryParse('${room['time_limit_per_question']}') ?? 30,
        );
        _sessionToken = resp.sessionToken;
        return resp;
      } catch (e) {
        logger.e('Join room error (supabase): $e');
        rethrow;
      }
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.fullApiUrl}/player/rooms/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'room_code': roomCode,
          'nickname': nickname,
        }),
      ).timeout(const Duration(milliseconds: AppConfig.connectTimeout));

      if (response.statusCode == 200) {
        final data = PlayerJoinResponse.fromJson(jsonDecode(response.body));
        _sessionToken = data.sessionToken;
        logger.i('Player joined room: ${data.roomName}');
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Room not found');
      } else if (response.statusCode == 409) {
        // Parse error message from backend
        try {
          final errorData = jsonDecode(response.body);
          final detail = errorData['detail'] ?? 'Room is full or not active';
          throw Exception(detail);
        } catch (e) {
          throw Exception('Room is full or not active');
        }
      } else {
        throw Exception('Failed to join room: ${response.body}');
      }
    } catch (e) {
      logger.e('Join room error: $e');
      rethrow;
    }
  }

  Future<RoomInfo> getRoomInfo(String roomCode) async {
    if (AppConfig.useSupabase) {
      try {
        final room = await SupabaseService.getRoomByCode(roomCode);
        if (room == null) throw Exception('Room not found');
        return RoomInfo(
          roomId: room['room_id'] as int,
          roomCode: roomCode,
          roomName: room['room_name'] as String? ?? '',
          theme: room['theme'] as String? ?? '',
          status: room['status'] as String? ?? 'pending',
          totalQuestions: room['total_questions'] as int? ?? 20,
          currentParticipants: room['current_participants'] as int? ?? 0,
          maxParticipants: room['max_participants'] as int? ?? 50,
        );
      } catch (e) {
        logger.e('Get room info error (supabase): $e');
        rethrow;
      }
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.fullApiUrl}/player/rooms/$roomCode'),
      ).timeout(const Duration(milliseconds: AppConfig.connectTimeout));

      if (response.statusCode == 200) {
        final data = RoomInfo.fromJson(jsonDecode(response.body));
        logger.i('Got room info: ${data.roomName}');
        return data;
      } else {
        throw Exception('Failed to get room info: ${response.body}');
      }
    } catch (e) {
      logger.e('Get room info error: $e');
      rethrow;
    }
  }

  // ============================================
  // QUIZ QUESTIONS
  // ============================================

  Future<QuestionLoadResponse> startQuiz(String sessionToken, int roomId, {String? selectedCharacter}) async {
    if (AppConfig.useSupabase) {
      try {
        final resp = await SupabaseService.startQuizViaFunction(roomId, sessionToken, character: selectedCharacter);
        final rawQuiz = resp['quiz_session'];
        final quizSession = (rawQuiz is Map<String, dynamic>)
            ? rawQuiz
            : (rawQuiz is Map ? Map<String, dynamic>.from(rawQuiz as Map) : <String, dynamic>{});

        int parseInt(dynamic v, [int fallback = 0]) {
          if (v == null) return fallback;
          if (v is int) return v;
          return int.tryParse(v.toString()) ?? fallback;
        }

        return QuestionLoadResponse(
          questionNumber: parseInt(quizSession['current_question']),
          totalQuestions: parseInt(quizSession['total_questions']),
          question: quizSession['question'] != null ? Question.fromJson(Map<String, dynamic>.from(quizSession['question'] as Map)) : null,
          timeLimit: parseInt(quizSession['time_limit']),
        );
      } catch (e) {
        logger.e('Start quiz error (supabase fn): $e');
        rethrow;
      }
    }

    try {
      final queryParams = {'token': sessionToken};
      if (selectedCharacter != null) {
        queryParams['character'] = selectedCharacter;
      }
      
      final response = await http.get(
        Uri.parse('${AppConfig.fullApiUrl}/player/quiz/$roomId/start')
            .replace(queryParameters: queryParams),
        headers: _getHeaders(),
      ).timeout(const Duration(milliseconds: AppConfig.receiveTimeout));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final quizSession = json['quiz_session'] as Map<String, dynamic>;
        final questionLoadResponse = QuestionLoadResponse(
          questionNumber: quizSession['current_question'] as int,
          totalQuestions: quizSession['total_questions'] as int,
          question: quizSession['question'] != null
              ? Question.fromJson(quizSession['question'] as Map<String, dynamic>)
              : null,
          timeLimit: quizSession['time_limit'] as int,
        );
        logger.i('Quiz started with character: $selectedCharacter');
        return questionLoadResponse;
      } else {
        throw Exception('Failed to start quiz: ${response.body}');
      }
    } catch (e) {
      logger.e('Start quiz error: $e');
      rethrow;
    }
  }

  Future<QuestionLoadResponse> getQuestion(
    int roomId,
    int questionNumber,
  ) async {
    if (AppConfig.useSupabase) {
      try {
        final resp = await SupabaseService.getQuestionViaFunction(roomId, questionNumber);
        final rawQuiz = resp['quiz_session'];
        final quizSession = (rawQuiz is Map<String, dynamic>)
            ? rawQuiz
            : (rawQuiz is Map ? Map<String, dynamic>.from(rawQuiz as Map) : <String, dynamic>{});

        int parseInt(dynamic v, [int fallback = 0]) {
          if (v == null) return fallback;
          if (v is int) return v;
          return int.tryParse(v.toString()) ?? fallback;
        }

        return QuestionLoadResponse(
          questionNumber: parseInt(quizSession['current_question']),
          totalQuestions: parseInt(quizSession['total_questions']),
          question: quizSession['question'] != null ? Question.fromJson(Map<String, dynamic>.from(quizSession['question'] as Map)) : null,
          timeLimit: parseInt(quizSession['time_limit']),
        );
      } catch (e) {
        logger.e('Get question error (supabase fn): $e');
        rethrow;
      }
    }

    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.fullApiUrl}/player/quiz/$roomId/question/$questionNumber',
        ),
        headers: _getHeaders(),
      ).timeout(const Duration(milliseconds: AppConfig.receiveTimeout));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        logger.i('Question API response:');
        logger.i(decoded);
        final data = QuestionLoadResponse.fromJson(decoded);
        logger.i('Got question $questionNumber');
        return data;
      } else {
        throw Exception('Failed to get question: ${response.body}');
      }
    } catch (e) {
      logger.e('Get question error: $e');
      rethrow;
    }
  }

  // ============================================
  // ANSWER SUBMISSION
  // ============================================

  Future<AnswerSubmitResponse> submitAnswer({
    required int roomId,
    required String sessionToken,
    required AnswerSubmitRequest request,
  }) async {
    if (AppConfig.useSupabase) {
      try {
        final payload = {
          'room_id': roomId,
          'session_token': sessionToken,
          'question_id': request.questionId,
          'selected_answer': request.selectedAnswer,
          'time_taken': request.timeTaken,
          'question_number': request.questionNumber,
        };
        final resp = await SupabaseService.submitAnswerViaFunction(payload);
        final Map<String, dynamic> data = Map<String, dynamic>.from(resp);
        return AnswerSubmitResponse.fromJson(data);
      } catch (e) {
        logger.e('Submit answer error (supabase fn): $e');
        rethrow;
      }
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.fullApiUrl}/player/quiz/$roomId/answer')
            .replace(queryParameters: {'token': sessionToken}),
        headers: _getHeaders(),
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(milliseconds: AppConfig.connectTimeout));

      if (response.statusCode == 200) {
        final data = AnswerSubmitResponse.fromJson(jsonDecode(response.body));
        logger.i('Answer submitted: ${data.isCorrect ? 'Correct' : 'Wrong'}');
        return data;
      } else {
        throw Exception('Failed to submit answer: ${response.body}');
      }
    } catch (e) {
      logger.e('Submit answer error: $e');
      rethrow;
    }
  }

  // ============================================
  // LEADERBOARD & RESULTS
  // ============================================

  Future<LeaderboardResponse> getLeaderboard(int roomId, String sessionToken) async {
    if (AppConfig.useSupabase) {
      try {
        final resp = await SupabaseService.getLeaderboardViaFunction(roomId, sessionToken: sessionToken);
        // Normalize response to a Map<String,dynamic> conservatively
        final Map<String, dynamic> asMap = (resp is Map)
            ? Map<String, dynamic>.from(resp as Map)
            : {'leaderboard': []};
        return LeaderboardResponse.fromJson(asMap);
      } catch (e) {
        logger.e('Get leaderboard error (supabase fn): $e');
        rethrow;
      }
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.fullApiUrl}/player/quiz/$roomId/leaderboard')
            .replace(queryParameters: {'token': sessionToken}),
        headers: _getHeaders(),
      ).timeout(const Duration(milliseconds: AppConfig.receiveTimeout));

      if (response.statusCode == 200) {
        final data = LeaderboardResponse.fromJson(jsonDecode(response.body));
        logger.i('Got leaderboard with ${data.leaderboard.length} entries');
        return data;
      } else {
        throw Exception('Failed to get leaderboard: ${response.body}');
      }
    } catch (e) {
      logger.e('Get leaderboard error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getResults(int roomId, String sessionToken) async {
    // Prefer Supabase SDK path when configured to avoid depending on local backend
    if (AppConfig.useSupabase) {
      try {
        // Get room meta
        final room = await SupabaseService.getRoom(roomId);

        // Get current participant by session token
        final parts = await supabase
            .from('participants')
            .select()
            .eq('session_token', sessionToken)
            .maybeSingle();
        if (parts == null) throw Exception('Session not found');
        final participant = Map<String, dynamic>.from(parts as Map);

        if ((participant['room_id'] is int && participant['room_id'] as int != roomId) ||
            (participant['room_id'] is String && int.tryParse(participant['room_id']) != roomId)) {
          throw Exception('You are not in this room');
        }

        // Get ordered participants (leaderboard)
        final res = await supabase
            .from('participants')
            .select()
            .eq('room_id', roomId)
            .order('total_correct', ascending: false)
            .order('total_time_taken', ascending: true)
            .order('position', ascending: false);

        final participants = res as List<dynamic>;

        // Find rank and build final leaderboard list including total_time_taken
        final leaderboardFinal = <Map<String, dynamic>>[];
        int userRank = participants.length;
        for (var i = 0; i < participants.length; i++) {
          final p = Map<String, dynamic>.from(participants[i] as Map);
          final int totalTimeVal = p['total_time_taken'] is int
              ? p['total_time_taken'] as int
              : int.tryParse(p['total_time_taken']?.toString() ?? '') ?? 0;
          final entry = {
            'rank': i + 1,
            'nickname': p['nickname']?.toString() ?? '',
            'position': p['position'] is int ? p['position'] as int : int.tryParse(p['position']?.toString() ?? '') ?? 0,
            'total_correct': p['total_correct'] is int ? p['total_correct'] as int : int.tryParse(p['total_correct']?.toString() ?? '') ?? 0,
            'total_time_taken': totalTimeVal,
            'total_answered': p['total_answered'] is int ? p['total_answered'] as int : int.tryParse(p['total_answered']?.toString() ?? '') ?? 0,
          };
          if (p['participant_id'] == participant['participant_id']) {
            userRank = i + 1;
          }
          leaderboardFinal.add(entry);
        }

        final int participantTotalTime = participant['total_time_taken'] is int
            ? participant['total_time_taken'] as int
            : int.tryParse(participant['total_time_taken']?.toString() ?? '') ?? 0;

        final int totalAnswered = participant['total_answered'] is int
            ? participant['total_answered'] as int
            : int.tryParse(participant['total_answered']?.toString() ?? '') ?? 0;
        final int totalCorrect = participant['total_correct'] is int
            ? participant['total_correct'] as int
            : int.tryParse(participant['total_correct']?.toString() ?? '') ?? 0;

        final double accuracy = totalAnswered > 0 ? (totalCorrect / totalAnswered * 100.0) : 0.0;

        return {
          'room_id': roomId,
          'room_name': room?['room_name'],
          'theme': room?['theme'],
          'participant': {
            'nickname': participant['nickname']?.toString() ?? '',
            'rank': userRank,
            'position': participant['position'] is int ? participant['position'] as int : int.tryParse(participant['position']?.toString() ?? '') ?? 0,
            'character_level': participant['character_level'] is int ? participant['character_level'] as int : int.tryParse(participant['character_level']?.toString() ?? '') ?? 0,
            'total_correct': totalCorrect,
            'total_answered': totalAnswered,
            'accuracy': '${accuracy.toStringAsFixed(1)}%',
            'total_time_taken': participantTotalTime,
            'time_spent': participantTotalTime.toString() + 's'
          },
          'leaderboard_final': leaderboardFinal,
        };
      } catch (e) {
        logger.e('Get results error (supabase): $e');
        rethrow;
      }
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.fullApiUrl}/player/quiz/$roomId/results')
            .replace(queryParameters: {'token': sessionToken}),
        headers: _getHeaders(),
      ).timeout(const Duration(milliseconds: AppConfig.receiveTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('Got results');
        return data;
      } else {
        throw Exception('Failed to get results: ${response.body}');
      }
    } catch (e) {
      logger.e('Get results error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getHistory(int roomId) async {
    // Prefer Supabase path when configured
    if (AppConfig.useSupabase) {
      try {
        if (_sessionToken == null) throw Exception('No session token available');
        // Resolve participant by session token
        final parts = await supabase
          .from('participants')
            .select()
            .eq('session_token', _sessionToken)
            .maybeSingle();
        if (parts == null) throw Exception('Session not found');
        final participant = Map<String, dynamic>.from(parts as Map);
        final participantId = participant['participant_id'] is int
            ? participant['participant_id'] as int
            : int.tryParse(participant['participant_id']?.toString() ?? '') ?? 0;

        final history = await SupabaseDirectService.getAnswerHistory(participantId: participantId, roomId: roomId);
        return history;
      } catch (e) {
        logger.e('Get history error (supabase): $e');
        rethrow;
      }
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.fullApiUrl}/player/quiz/$roomId/history'),
        headers: _getHeaders(),
      ).timeout(const Duration(milliseconds: AppConfig.receiveTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('Got history');
        return data;
      } else {
        throw Exception('Failed to get history: ${response.body}');
      }
    } catch (e) {
      logger.e('Get history error: $e');
      rethrow;
    }
  }

  // ============================================
  // ADMIN OPERATIONS
  // ============================================

  Future<List<dynamic>> getRooms() async {
    if (AppConfig.useSupabase) {
      try {
        final res = await SupabaseService.listRooms();
        logger.i('Fetched ${res.length} rooms (supabase)');
        return res;
      } catch (e) {
        logger.e('Get rooms error (supabase): $e');
        rethrow;
      }
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.fullApiUrl}/admin/rooms'),
        headers: _getHeaders(),
      ).timeout(const Duration(milliseconds: AppConfig.connectTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('Fetched ${data.length} rooms');
        return data is List ? data : [];
      } else {
        throw Exception('Failed to fetch rooms: ${response.body}');
      }
    } catch (e) {
      logger.e('Get rooms error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getRoomDetails(int roomId) async {
    if (AppConfig.useSupabase) {
      try {
        final room = await SupabaseService.getRoom(roomId);
        if (room == null) throw Exception('Room not found');
        return room;
      } catch (e) {
        logger.e('Get room details error (supabase): $e');
        rethrow;
      }
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.fullApiUrl}/admin/rooms/$roomId'),
        headers: _getHeaders(),
      ).timeout(const Duration(milliseconds: AppConfig.connectTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('Fetched room details');
        return data;
      } else {
        throw Exception('Failed to fetch room details: ${response.body}');
      }
    } catch (e) {
      logger.e('Get room details error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAdminStats() async {
    // Prefer Supabase direct implementation when enabled
    if (AppConfig.useSupabase) {
      try {
        final stats = await SupabaseDirectService.getAdminStats();
        return stats;
      } catch (e) {
        logger.e('Get admin stats error (supabase): $e');
        rethrow;
      }
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.fullApiUrl}/admin/stats'),
        headers: _getHeaders(),
      ).timeout(const Duration(milliseconds: AppConfig.connectTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('Got admin stats');
        return data;
      } else {
        throw Exception('Failed to get stats: ${response.body}');
      }
    } catch (e) {
      logger.e('Get admin stats error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createRoom({
    required String roomName,
    required String theme,
    required int totalQuestions,
    required int timeLimitPerQuestion,
    required List<int> questionIds,
  }) async {
    if (AppConfig.useSupabase) {
      try {
        final room = {
          'room_name': roomName,
          'theme': theme,
          'total_questions': totalQuestions,
          'time_limit_per_question': timeLimitPerQuestion,
          // generate simple code
          'room_code': DateTime.now().millisecondsSinceEpoch.toString().substring(8),
          'status': 'draft',
        };
        final created = await SupabaseService.createRoom(room);
        // attach question_ids into room_questions if provided
        try {
          final createdRoom = created ?? {};
          final createdId = createdRoom['room_id'] is int
              ? createdRoom['room_id'] as int
              : int.tryParse('${createdRoom['room_id']}') ?? 0;
          if (createdId > 0 && questionIds.isNotEmpty) {
            await SupabaseService.attachQuestionsToRoom(createdId, questionIds);
          }
        } catch (e) {
          logger.w('Attach questions to room failed: $e');
        }

        return created ?? {};
      } catch (e) {
        logger.e('Create room error (supabase): $e');
        rethrow;
      }
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.fullApiUrl}/admin/rooms'),
        headers: _getHeaders(),
        body: jsonEncode({
          'room_name': roomName,
          'theme': theme,
          'total_questions': totalQuestions,
          'time_limit_per_question': timeLimitPerQuestion,
          'question_ids': questionIds,
        }),
      ).timeout(const Duration(milliseconds: AppConfig.connectTimeout));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('Room created with code: ${data['room_code']}');
        return data;
      } else {
        throw Exception('Failed to create room: ${response.body}');
      }
    } catch (e) {
      logger.e('Create room error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> startRoom(int roomId) async {
    if (AppConfig.useSupabase) {
      try {
        final updated = await SupabaseService.updateRoomStatus(roomId, 'active');
        return updated ?? {};
      } catch (e) {
        logger.e('Start room error (supabase): $e');
        rethrow;
      }
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.fullApiUrl}/admin/rooms/$roomId/start'),
        headers: _getHeaders(),
      ).timeout(const Duration(milliseconds: AppConfig.connectTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('Room started');
        return data;
      } else {
        throw Exception('Failed to start room: ${response.body}');
      }
    } catch (e) {
      logger.e('Start room error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> finishRoom(int roomId) async {
    if (AppConfig.useSupabase) {
      try {
        final updated = await SupabaseService.updateRoomStatus(roomId, 'finished');
        return updated ?? {};
      } catch (e) {
        logger.e('Finish room error (supabase): $e');
        rethrow;
      }
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.fullApiUrl}/admin/rooms/$roomId/finish'),
        headers: _getHeaders(),
      ).timeout(const Duration(milliseconds: AppConfig.connectTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('Room finished');
        return data;
      } else {
        throw Exception('Failed to finish room: ${response.body}');
      }
    } catch (e) {
      logger.e('Finish room error: $e');
      rethrow;
    }
  }

  // ============================================
  // SUBJECT AND QUESTION SET MANAGEMENT
  // ============================================

  Future<Map<String, dynamic>> createSubject({
    required String subjectName,
    required String? description,
  }) async {
    if (AppConfig.useSupabase) {
      try {
        final created = await SupabaseService.createSubject({
          'admin_id': 1, // TODO: set appropriate admin_id from auth
          'subject_name': subjectName,
          'description': description,
        });
        return created ?? {};
      } catch (e) {
        logger.e('Create subject error (supabase): $e');
        rethrow;
      }
    }

    try {
      final uri = Uri.parse('${AppConfig.fullApiUrl}/admin/subjects').replace(
        queryParameters: {
          'subject_name': subjectName,
          if (description != null && description.isNotEmpty) 'description': description,
        },
      );
      
      final response = await http.post(
        uri,
        headers: _getHeaders(),
      ).timeout(const Duration(milliseconds: AppConfig.connectTimeout));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('Subject created: $subjectName');
        return data;
      } else {
        throw Exception('Failed to create subject: ${response.body}');
      }
    } catch (e) {
      logger.e('Create subject error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getSubjects() async {
    if (AppConfig.useSupabase) {
      try {
        final res = await SupabaseService.getSubjects();
        return res;
      } catch (e) {
        logger.e('Get subjects error (supabase): $e');
        rethrow;
      }
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.fullApiUrl}/admin/subjects'),
        headers: _getHeaders(),
      ).timeout(const Duration(milliseconds: AppConfig.receiveTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('Got subjects list');
        return data is List ? data : (data['subjects'] ?? []);
      } else {
        throw Exception('Failed to get subjects: ${response.body}');
      }
    } catch (e) {
      logger.e('Get subjects error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSubjectDetail(int subjectId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.fullApiUrl}/admin/subjects/$subjectId'),
        headers: _getHeaders(),
      ).timeout(const Duration(milliseconds: AppConfig.receiveTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('Got subject detail');
        return data;
      } else {
        throw Exception('Failed to get subject: ${response.body}');
      }
    } catch (e) {
      logger.e('Get subject detail error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createQuestionSet({
    required int subjectId,
    required String setName,
    required String? description,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.fullApiUrl}/admin/subjects/$subjectId/question-sets').replace(
        queryParameters: {
          'set_name': setName,
          if (description != null && description.isNotEmpty) 'description': description,
        },
      );
      
      final response = await http.post(
        uri,
        headers: _getHeaders(),
      ).timeout(const Duration(milliseconds: AppConfig.connectTimeout));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('Question set created: $setName');
        return data;
      } else {
        throw Exception('Failed to create question set: ${response.body}');
      }
    } catch (e) {
      logger.e('Create question set error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createQuestion({
    required String question,
    required List<String> options,
    required int correctAnswerIndex,
    required String difficulty,
    int? setId,
  }) async {
    try {
      String _indexToLetter(int idx) {
        const letters = ['A', 'B', 'C', 'D'];
        if (idx >= 0 && idx < letters.length) return letters[idx];
        return 'A';
      }

      final uri = Uri.parse('${AppConfig.fullApiUrl}/admin/questions').replace(
        queryParameters: {
          'question_text': question,
          'correct_answer': _indexToLetter(correctAnswerIndex),
          'difficulty': difficulty,
          if (setId != null) 'set_id': setId.toString(),
        },
      );

      final response = await http.post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode(options),
      ).timeout(const Duration(milliseconds: AppConfig.connectTimeout));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        logger.i('Question created successfully');
        return data;
      } else {
        throw Exception('Failed to create question: ${response.body}');
      }
    } catch (e) {
      logger.e('Create question error: $e');
      rethrow;
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  Future<Map<String, dynamic>> deleteQuestion(int questionId) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.fullApiUrl}/admin/questions/$questionId'),
        headers: _getHeaders(),
      ).timeout(const Duration(milliseconds: AppConfig.connectTimeout));

      if (response.statusCode == 200) {
        logger.i('Question deleted successfully');
        return jsonDecode(response.body);
      } else {
        throw Exception('Delete failed: ${response.body}');
      }
    } catch (e) {
      logger.e('Delete question error: $e');
      throw Exception(e.toString());
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (_sessionToken != null) {
      headers['Authorization'] = 'Bearer $_sessionToken';
    } else if (_adminToken != null) {
      headers['Authorization'] = 'Bearer $_adminToken';
    }
    return headers;
  }

  void setSessionToken(String token) {
    _sessionToken = token;
  }

  void setAdminToken(String token) {
    _adminToken = token;
  }

  void clearTokens() {
    _sessionToken = null;
    _adminToken = null;
  }

  void clearAdminToken() {
    _adminToken = null;
  }

  String? getSessionToken() => _sessionToken;
  String? getAdminToken() => _adminToken;
}
