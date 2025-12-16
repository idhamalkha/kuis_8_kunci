/// Supabase REST API Service for Flutter
/// Alternative to supabase_flutter package using HTTP REST API directly
/// This approach is simpler and doesn't require Supabase client initialization

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

class SupabaseRestService {
  static final _client = http.Client();
  
  // Base URL for Supabase REST API
  static String get _baseUrl => '${AppConfig.supabaseUrl}/rest/v1';
  
  // API Key (using service key for server-side access, anon key for client-side)
  static String get _apiKey => AppConfig.supabaseServiceKey;
  
  // Default headers for all requests
  static Map<String, String> get _headers => {
    'apikey': _apiKey,
    'Authorization': 'Bearer $_apiKey',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  // Remove server-managed fields and normalize some values before inserts
  static Map<String, dynamic> _sanitizeForInsert(Map<String, dynamic> payload, {String? table}) {
    final copy = Map<String, dynamic>.from(payload);
    // Remove only the primary key field for the given table
    if (table != null) {
      switch (table) {
        case 'admins':
          copy.remove('admin_id');
          break;
        case 'subjects':
          copy.remove('subject_id');
          break;
        case 'question_sets':
          copy.remove('set_id');
          break;
        case 'questions':
          copy.remove('question_id');
          break;
        case 'quiz_rooms':
          copy.remove('room_id');
          break;
        case 'room_questions':
          copy.remove('room_question_id');
          break;
        case 'participants':
          copy.remove('participant_id');
          break;
        case 'attempts':
          copy.remove('attempt_id');
          break;
        default:
          break;
      }
    }

    // Remove timestamp fields if present
    copy.remove('created_at');
    copy.remove('updated_at');

    // Ensure correct_answer (questions) is a single uppercase char A-D
    if (copy.containsKey('correct_answer') && copy['correct_answer'] != null) {
      var ca = copy['correct_answer'].toString().trim();
      // If numeric index provided (0..3), convert to letter
      final numeric = int.tryParse(ca);
      if (numeric != null) {
        const letters = ['A', 'B', 'C', 'D'];
        if (numeric >= 0 && numeric < letters.length) {
          ca = letters[numeric];
        } else {
          ca = letters[0];
        }
      } else {
        // If longer string, try to find first occurrence of A-D
        final match = RegExp(r'[A-Da-d]').firstMatch(ca);
        if (match != null) {
          ca = match.group(0)!.toUpperCase();
        } else if (ca.isNotEmpty) {
          // fallback to first char uppercase but ensure it's A-D, else default to 'A'
          ca = ca[0].toUpperCase();
          if (!'ABCD'.contains(ca)) ca = 'A';
        } else {
          ca = 'A';
        }
      }
      copy['correct_answer'] = ca;
    }

    // Ensure selected_answer (attempts) is a single uppercase char A-D or null
    if (copy.containsKey('selected_answer') && copy['selected_answer'] != null) {
      var sa = copy['selected_answer'].toString().trim();
      final numericSa = int.tryParse(sa);
      if (numericSa != null) {
        const letters = ['A', 'B', 'C', 'D'];
        sa = (numericSa >= 0 && numericSa < letters.length) ? letters[numericSa] : letters[0];
      } else {
        final match = RegExp(r'[A-Da-d]').firstMatch(sa);
        if (match != null) sa = match.group(0)!.toUpperCase();
        else if (sa.isNotEmpty) {
          sa = sa[0].toUpperCase();
          if (!'ABCD'.contains(sa)) sa = 'A';
        } else {
          sa = '';
        }
      }
      copy['selected_answer'] = sa;
    }

    return copy;
  }

  // ============================================
  // ADMIN ENDPOINTS
  // ============================================

  /// Get all subjects for admin
  static Future<List<Map<String, dynamic>>> getSubjects() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/subjects'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch subjects: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get all questions for admin
  static Future<List<Map<String, dynamic>>> getQuestions({
    int? limit,
    int? offset,
    String? difficulty,
  }) async {
    try {
      String url = '$_baseUrl/questions?select=*';
      
      if (difficulty != null) {
        url += '&difficulty=eq.$difficulty';
      }
      if (limit != null) {
        url += '&limit=$limit';
      }
      if (offset != null) {
        url += '&offset=$offset';
      }
      
      final response = await _client.get(
        Uri.parse(url),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch questions: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Create question
  static Future<Map<String, dynamic>> createQuestion(Map<String, dynamic> question) async {
    try {
      final body = _sanitizeForInsert(question, table: 'questions');
      final response = await _client.post(
        Uri.parse('$_baseUrl/questions'),
        headers: _headers,
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.first as Map<String, dynamic>;
      } else {
        throw Exception('Failed to create question: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get all quiz rooms for admin
  static Future<List<Map<String, dynamic>>> getQuizRooms({String? status}) async {
    try {
      String url = '$_baseUrl/quiz_rooms?select=*';
      
      if (status != null) {
        url += '&status=eq.$status';
      }
      
      final response = await _client.get(
        Uri.parse(url),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch rooms: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Create quiz room
  static Future<Map<String, dynamic>> createQuizRoom(Map<String, dynamic> room) async {
    try {
      final body = _sanitizeForInsert(room, table: 'quiz_rooms');
      final response = await _client.post(
        Uri.parse('$_baseUrl/quiz_rooms'),
        headers: _headers,
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.first as Map<String, dynamic>;
      } else {
        throw Exception('Failed to create room: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Start quiz room (change status to active)
  static Future<Map<String, dynamic>> startRoom(int roomId) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      
      final response = await _client.patch(
        Uri.parse('$_baseUrl/quiz_rooms?room_id=eq.$roomId'),
        headers: _headers,
        body: jsonEncode({
          'status': 'active',
          'started_at': now,
        }),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.first as Map<String, dynamic>;
      } else {
        throw Exception('Failed to start room: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Finish quiz room (change status to finished)
  static Future<Map<String, dynamic>> finishRoom(int roomId) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      
      final response = await _client.patch(
        Uri.parse('$_baseUrl/quiz_rooms?room_id=eq.$roomId'),
        headers: _headers,
        body: jsonEncode({
          'status': 'finished',
          'finished_at': now,
        }),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.first as Map<String, dynamic>;
      } else {
        throw Exception('Failed to finish room: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // PLAYER ENDPOINTS
  // ============================================

  /// Join room by room code
  static Future<Map<String, dynamic>> joinRoom({
    required String roomCode,
    required String nickname,
    String? selectedCharacter,
  }) async {
    try {
      // First, get room by code
      final roomResponse = await _client.get(
        Uri.parse('$_baseUrl/quiz_rooms?room_code=eq.$roomCode'),
        headers: _headers,
      );
      
      if (roomResponse.statusCode != 200) {
        throw Exception('Room not found');
      }
      
      final List<dynamic> rooms = jsonDecode(roomResponse.body);
      if (rooms.isEmpty) {
        throw Exception('Room not found');
      }
      
      final roomId = rooms.first['room_id'] as int;
      
      // Create participant
      final participantData = _sanitizeForInsert({
        'room_id': roomId,
        'nickname': nickname,
        'selected_character': selectedCharacter ?? 'Monkey',
        'total_correct': 0,
        'total_answered': 0,
        'total_time_taken': 0,
      }, table: 'participants');
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/participants'),
        headers: _headers,
        body: jsonEncode(participantData),
      );
      
      if (response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.first as Map<String, dynamic>;
      } else {
        throw Exception('Failed to join room: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get questions for room (ordered by question_order)
  static Future<List<Map<String, dynamic>>> getQuestionsForRoom(int roomId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/room_questions?room_id=eq.$roomId&select=*,question:questions(*)&order=question_order'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch questions: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Submit answer for question
  static Future<Map<String, dynamic>> submitAnswer({
    required int participantId,
    required int questionId,
    required int roomId,
    required String? selectedAnswer,
    required int timeTaken,
  }) async {
    try {
      // Get question to check correct answer
      final questionResponse = await _client.get(
        Uri.parse('$_baseUrl/questions?question_id=eq.$questionId'),
        headers: _headers,
      );
      
      if (questionResponse.statusCode != 200) {
        throw Exception('Question not found');
      }
      
      final List<dynamic> questions = jsonDecode(questionResponse.body);
      if (questions.isEmpty) {
        throw Exception('Question not found');
      }
      
      final correctAnswer = questions.first['correct_answer'] as String?;
      final isCorrect = selectedAnswer != null && selectedAnswer == correctAnswer;
      
      // Create attempt record
      final attemptData = _sanitizeForInsert({
        'participant_id': participantId,
        'room_id': roomId,
        'question_id': questionId,
        'selected_answer': selectedAnswer,
        'is_correct': isCorrect,
        'time_taken': timeTaken,
      }, table: 'attempts');
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/attempts'),
        headers: _headers,
        body: jsonEncode(attemptData),
      );
      
      if (response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        // Also return correctness for feedback
        return {
          ...data.first as Map<String, dynamic>,
          'correct_answer': correctAnswer,
          'is_correct': isCorrect,
        };
      } else {
        throw Exception('Failed to submit answer: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get leaderboard for room
  static Future<List<Map<String, dynamic>>> getLeaderboard(int roomId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/participants?room_id=eq.$roomId&select=*'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        // Calculate score for each participant
        List<Map<String, dynamic>> leaderboard = [];
        
        for (final participant in data.cast<Map<String, dynamic>>()) {
          final totalCorrect = (participant['total_correct'] ?? 0) as int;
          final score = totalCorrect * 10;
          
          leaderboard.add({
            ...participant,
            'score': score,
            'rank': 0, // Will be assigned after sorting
          });
        }
        
        // Sort by score DESC, time_taken ASC
        leaderboard.sort((a, b) {
          final scoreCompare = (b['score'] as int).compareTo(a['score'] as int);
          if (scoreCompare != 0) return scoreCompare;
          return (a['total_time_taken'] as int).compareTo(b['total_time_taken'] as int);
        });
        
        // Assign ranks
        for (int i = 0; i < leaderboard.length; i++) {
          leaderboard[i]['rank'] = i + 1;
        }
        
        return leaderboard;
      } else {
        throw Exception('Failed to fetch leaderboard: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get participant's attempts
  static Future<List<Map<String, dynamic>>> getParticipantAttempts(int participantId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/attempts?participant_id=eq.$participantId&select=*,question:questions(*)'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch attempts: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get final results for participant
  static Future<Map<String, dynamic>> getResults(int participantId) async {
    try {
      // Get participant
      final participantResponse = await _client.get(
        Uri.parse('$_baseUrl/participants?participant_id=eq.$participantId'),
        headers: _headers,
      );
      
      if (participantResponse.statusCode != 200) {
        throw Exception('Participant not found');
      }
      
      final List<dynamic> participants = jsonDecode(participantResponse.body);
      if (participants.isEmpty) {
        throw Exception('Participant not found');
      }
      
      final participant = participants.first as Map<String, dynamic>;
      final roomId = participant['room_id'] as int;
      final totalCorrect = (participant['total_correct'] ?? 0) as int;
      final totalAnswered = (participant['total_answered'] ?? 0) as int;
      
      // Get attempts
      final attempts = await getParticipantAttempts(participantId);
      
      // Get leaderboard
      final leaderboard = await getLeaderboard(roomId);
      
      // Find rank
      final rank = leaderboard.firstWhere(
        (p) => p['participant_id'] == participantId,
        orElse: () => {'rank': 0},
      )['rank'] as int;
      
      return {
        'participant_id': participantId,
        'nickname': participant['nickname'],
        'character': participant['selected_character'],
        'total_correct': totalCorrect,
        'total_answered': totalAnswered,
        'accuracy_percentage': totalAnswered > 0 ? (totalCorrect / totalAnswered * 100).toStringAsFixed(1) : '0.0',
        'score': totalCorrect * 10,
        'rank': rank,
        'total_participants': leaderboard.length,
        'attempts': attempts,
      };
    } catch (e) {
      rethrow;
    }
  }
}
