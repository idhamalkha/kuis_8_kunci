import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_auth_service.dart';

/// Lightweight Supabase service to replace current Python backend logic.
/// Adapt function signatures and error handling to your app's needs.

final SupabaseClient supabase = Supabase.instance.client;

class SupabaseService {
  // Helper: normalize many possible response shapes to Map<String,dynamic>
  static Map<String, dynamic>? _mapFrom(dynamic res) {
    if (res == null) return null;
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    if (res is List && res.isNotEmpty) {
      final first = res[0];
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  // --- Rooms ---
  static Future<Map<String, dynamic>?> createRoom(Map<String, dynamic> room, {List<int>? questionIds}) async {
    try {
      final adminId = AdminAuthService.instance.adminIdAsInt;
      if (adminId != null && !room.containsKey('admin_id')) {
        room['admin_id'] = adminId;
      }
      final response = await supabase
          .from('quiz_rooms')
          .insert(room)
          .select();
      final created = _mapFrom(response);
      if (created != null && questionIds != null && questionIds.isNotEmpty) {
        try {
          final createdId = created['room_id'] is int ? created['room_id'] as int : int.tryParse('${created['room_id']}') ?? 0;
          if (createdId > 0) {
            await attachQuestionsToRoom(createdId, questionIds);
          }
        } catch (_) {}
      }
      return created;
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<dynamic>> listRooms({String? status}) async {
    try {
      var query = supabase.from('quiz_rooms').select();
      if (status != null) {
        final filtered = await query.eq('status', status);
        return filtered as List<dynamic>;
      }
      final res = await query;
      return res as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getRoom(int roomId) async {
    try {
      final res = await supabase
          .from('quiz_rooms')
          .select()
          .eq('room_id', roomId)
          .maybeSingle();
      return _mapFrom(res);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getRoomByCode(String roomCode) async {
    try {
      final res = await supabase
          .from('quiz_rooms')
          .select()
          .eq('room_code', roomCode)
          .maybeSingle();
      return _mapFrom(res);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> updateRoomStatus(int roomId, String status) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final patch = {
        'status': status,
        if (status == 'active') 'started_at': now,
        if (status == 'finished') 'finished_at': now,
      };

        final res = await supabase
          .from('quiz_rooms')
          .update(patch)
          .eq('room_id', roomId)
          .select()
          .maybeSingle();
        return _mapFrom(res);
    } catch (e) {
      rethrow;
    }
  }

  // --- Subjects & Questions (Admin) ---
  static Future<List<dynamic>> getSubjects() async {
    try {
      final res = await supabase.from('subjects').select().order('subject_id');
      return res as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> createSubject(Map<String, dynamic> subject) async {
    try {
      final adminId = AdminAuthService.instance.adminIdAsInt;
      if (adminId != null && !subject.containsKey('admin_id')) {
        subject['admin_id'] = adminId;
      }
      final res = await supabase.from('subjects').insert(subject).select();
      return _mapFrom(res);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getSubjectDetail(int subjectId) async {
    try {
        final res = await supabase
          .from('subjects')
          .select()
          .eq('subject_id', subjectId)
          .maybeSingle();
        return _mapFrom(res);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> createQuestion(Map<String, dynamic> question) async {
    try {
      final adminId = AdminAuthService.instance.adminIdAsInt;
      if (adminId != null && !question.containsKey('admin_id')) {
        question['admin_id'] = adminId;
      }
      final res = await supabase.from('questions').insert(question).select();
      return _mapFrom(res);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> updateQuestion(int questionId, Map<String, dynamic> patch) async {
    try {
        final res = await supabase
          .from('questions')
          .update(patch)
          .eq('question_id', questionId)
          .select()
          .maybeSingle();
        return _mapFrom(res);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> deleteQuestion(int questionId) async {
    try {
      await supabase.from('questions').delete().eq('question_id', questionId);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> attachQuestionsToRoom(int roomId, List<int> questionIds) async {
    try {
      // Insert into room_questions with order
      final batch = <Map<String, dynamic>>[];
      for (var i = 0; i < questionIds.length; i++) {
        batch.add({
          'room_id': roomId,
          'question_id': questionIds[i],
          'question_order': i + 1,
        });
      }
      await supabase.from('room_questions').insert(batch);
    } catch (e) {
      rethrow;
    }
  }

  // --- Participants ---
  static Future<Map<String, dynamic>?> joinRoom(Map<String, dynamic> participant) async {
    try {
      // participant must contain at least: room_id, nickname
      final res = await supabase.from('participants').insert(participant).select();
      return _mapFrom(res);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> updateParticipant(int participantId, Map<String, dynamic> patch) async {
    try {
        final res = await supabase
          .from('participants')
          .update(patch)
          .eq('participant_id', participantId)
          .select()
          .maybeSingle();
        return _mapFrom(res);
    } catch (e) {
      rethrow;
    }
  }

  // --- Questions & RoomQuestions ---
  static Future<List<dynamic>> fetchQuestionsForRoom(int roomId) async {
    try {
      // fetch mapping and join questions via RPC or client-side join
      final res = await supabase
          .from('room_questions')
          .select('*, question:questions(*)')
          .eq('room_id', roomId)
          .order('question_order');
      return res as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // --- Attempts ---
  static Future<Map<String, dynamic>?> recordAttempt(Map<String, dynamic> attempt) async {
    try {
      final res = await supabase.from('attempts').insert(attempt).select();
      return _mapFrom(res);
    } catch (e) {
      rethrow;
    }
  }

  // --- Realtime subscriptions ---
  // NOTE: Supabase realtime APIs and Channel names may change; adapt as needed.
  static RealtimeChannel subscribeToRoomEvents(String roomChannelId, void Function(dynamic) onEvent) {
    // Example: listen to changes on participants and attempts for a given room
    final channel = supabase.channel('room-$roomChannelId');

    channel
        .on(RealtimeListenTypes.postgresChanges, ChannelFilter(event: '*', schema: 'public', table: 'participants', filter: 'room_id=eq.$roomChannelId'), (payload, [ref]) {
          onEvent({'table': 'participants', 'payload': payload});
        })
        .on(RealtimeListenTypes.postgresChanges, ChannelFilter(event: '*', schema: 'public', table: 'attempts', filter: 'room_id=eq.$roomChannelId'), (payload, [ref]) {
          onEvent({'table': 'attempts', 'payload': payload});
        })
        .subscribe();

    return channel;
  }

  static Future<void> unsubscribeChannel(RealtimeChannel channel) async {
    await channel.unsubscribe();
  }

  // --- Utility helpers ---
  static String makeRoomChannelId(int roomId) => roomId.toString();

  // --- Functions (Edge Functions) ---
  static Future<Map<String, dynamic>> invokeFunction(String name, Map<String, dynamic> body) async {
    try {
      final res = await supabase.functions.invoke(name, body: body);
      // supabase.functions.invoke returns a FunctionResponse object
      // Need to extract data from the response
      
      // Get the data from FunctionResponse
      final data = res.data;
      
      // If data is already a Map, return it
      if (data is Map<String, dynamic>) {
        return data;
      }
      
      // If data is Map but not typed correctly, convert it
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      
      // If data is null or invalid, return empty map
      return {};
    } catch (e) {
      // Rethrow so callers can decide, but include the original error message
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> startQuizViaFunction(int roomId, String sessionToken, {String? character}) async {
    // SDK-only implementation: validate participant by session token, update selected_character
    // and return first question + room info
    try {
        // Find participant by session token
        final parts = await supabase
          .from('participants')
          .select('participant_id,room_id,selected_character,started_at')
          .eq('session_token', sessionToken)
          .maybeSingle();

        if (parts == null) throw Exception('Session not found');
        final participant = Map<String, dynamic>.from(parts as Map);
        final participantRoomId = participant['room_id'] is int
          ? participant['room_id'] as int
          : int.tryParse(participant['room_id']?.toString() ?? '') ?? -1;
        if (participantRoomId != roomId) throw Exception('You are not in this room');

      // Update selected_character if provided
      if (character != null) {
        await supabase
            .from('participants')
            .update({'selected_character': character})
            .eq('participant_id', participant['participant_id']);
      }

      // Ensure started_at is set when participant starts the quiz
      if (participant['started_at'] == null) {
        try {
          final nowIso = DateTime.now().toUtc().toIso8601String();
          await supabase
              .from('participants')
              .update({'started_at': nowIso})
              .eq('participant_id', participant['participant_id']);
        } catch (_) {}
      }

      // Get first room_question with its question
      final rq = await supabase
          .from('room_questions')
          .select('question:questions(*)')
          .eq('room_id', roomId)
          .eq('question_order', 1)
          .maybeSingle();

      if (rq == null) throw Exception('Quiz questions not found');

      // Get room meta
      final room = await supabase.from('quiz_rooms').select('room_id,room_name,total_questions,time_limit_per_question').eq('room_id', roomId).maybeSingle();
      final roomMap = room != null ? Map<String, dynamic>.from(room as Map) : null;

      final question = Map<String, dynamic>.from((rq as Map)['question'] as Map);

      return {
        'quiz_session': {
          'room_id': roomId,
          'total_questions': roomMap?['total_questions'] ?? 0,
          'current_question': 1,
          'question': {
            'question_id': question['question_id'],
            'question_text': question['question_text'],
            'option_a': question['option_a'],
            'option_b': question['option_b'],
            'option_c': question['option_c'],
            'option_d': question['option_d']
          },
          'time_limit': roomMap?['time_limit_per_question'],
          'status': 'playing'
        }
      };
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getQuestionViaFunction(int roomId, int questionNumber) async {
    try {
      // Validate participant via session stored in client may be required by caller; assume caller passes token separately
      final rq = await supabase
          .from('room_questions')
          .select('*, question:questions(*)')
          .eq('room_id', roomId)
          .eq('question_order', questionNumber)
          .maybeSingle();

      if (rq == null) throw Exception('Question not found');

      final room = await supabase.from('quiz_rooms').select('total_questions,time_limit_per_question').eq('room_id', roomId).maybeSingle();
      final roomMap = room != null ? Map<String, dynamic>.from(room as Map) : null;
      final question = Map<String, dynamic>.from((rq as Map)['question'] as Map);

      return {
        'quiz_session': {
          'room_id': roomId,
          'total_questions': roomMap?['total_questions'] ?? 0,
          'current_question': questionNumber,
          'question': {
            'question_id': question['question_id'],
            'question_text': question['question_text'],
            'option_a': question['option_a'],
            'option_b': question['option_b'],
            'option_c': question['option_c'],
            'option_d': question['option_d']
          },
          'time_limit': roomMap?['time_limit_per_question'],
          'status': 'playing'
        }
      };
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> submitAnswerViaFunction(Map<String, dynamic> payload) async {
    try {
      // Expected payload keys: room_id, session_token, question_id, question_number, selected_answer, time_taken
      final roomId = payload['room_id'] is int ? payload['room_id'] as int : int.tryParse(payload['room_id']?.toString() ?? '') ?? (throw Exception('Invalid room_id'));
      final sessionToken = payload['session_token']?.toString() ?? (throw Exception('Missing session_token'));

      // Find participant
        final pRes = await supabase.from('participants').select('participant_id,room_id,total_answered,total_correct,position,character_level,total_time_taken,started_at,finished_at').eq('session_token', sessionToken).maybeSingle();
        if (pRes == null) throw Exception('Session not found');
        final participant = Map<String, dynamic>.from(pRes as Map);
        final participantRoomId2 = participant['room_id'] is int
          ? participant['room_id'] as int
          : int.tryParse(participant['room_id']?.toString() ?? '') ?? -1;
        if (participantRoomId2 != roomId) throw Exception('You are not in this room');

      // Get question
      final qRes = await supabase.from('questions').select('question_id,correct_answer').eq('question_id', payload['question_id']).maybeSingle();
      if (qRes == null) throw Exception('Question not found');
      final question = Map<String, dynamic>.from(qRes as Map);

      // Normalize selected_answer to a single letter if needed
      var selected = payload['selected_answer'];
      if (selected is String && selected.length > 1) {
        // Try to map full option text to A/B/C/D by fetching the question options
        final fullQ = await supabase.from('questions').select('option_a,option_b,option_c,option_d').eq('question_id', payload['question_id']).maybeSingle();
        if (fullQ != null) {
          final fq = Map<String, dynamic>.from(fullQ as Map);
          if (selected == fq['option_a']) selected = 'A';
          else if (selected == fq['option_b']) selected = 'B';
          else if (selected == fq['option_c']) selected = 'C';
          else if (selected == fq['option_d']) selected = 'D';
        }
      }

      final isCorrect = (selected != null && question['correct_answer'] == selected);
      // Check if participant already has a correct attempt for this question
      bool alreadyHadCorrectForThisQuestion = false;
      try {
        final priorCorrect = await supabase
            .from('attempts')
            .select('attempt_id')
            .eq('participant_id', participant['participant_id'])
            .eq('question_id', payload['question_id'])
            .eq('is_correct', true)
            .limit(1)
            .maybeSingle();
        if (priorCorrect != null) {
          alreadyHadCorrectForThisQuestion = true;
        }
      } catch (_) {}
      // Debug: show what was selected and the correct answer, and whether we consider it correct
      try {
        print('[DEBUG] submitAnswerViaFunction - selected: $selected');
        print('[DEBUG] submitAnswerViaFunction - correct_answer: ${question['correct_answer']}');
        print('[DEBUG] submitAnswerViaFunction - isCorrect: $isCorrect');
      } catch (_) {}

      // Insert attempt
      final attemptRow = {
        'participant_id': participant['participant_id'],
        'room_id': roomId,
        'question_id': payload['question_id'],
        'selected_answer': selected,
        'is_correct': isCorrect,
        'time_taken': payload['time_taken']
      };

      final attemptRes = await supabase.from('attempts').insert(attemptRow).select();
      final attemptInserted = attemptRes != null ? Map<String, dynamic>.from((attemptRes is List && attemptRes.isNotEmpty) ? attemptRes[0] as Map : attemptRes as Map) : null;

      // Update participant aggregates. Parse numeric fields defensively so strings don't break updates.
      int parseInt(dynamic v, [int fallback = 0]) {
        if (v == null) return fallback;
        if (v is int) return v;
        return int.tryParse(v.toString()) ?? fallback;
      }

      final int timeTakenVal = parseInt(payload['time_taken']);
      final int currentTotalAnswered = parseInt(participant['total_answered']);
      final int currentPosition = parseInt(participant['position']);
      final int currentTotalCorrect = parseInt(participant['total_correct']);
      final int currentCharLevel = parseInt(participant['character_level']);
      final int currentTotalTime = parseInt(participant['total_time_taken']);

      final newTotalAnswered = currentTotalAnswered + 1;
      final updates = <String, dynamic>{'total_answered': newTotalAnswered};
        // Debug logs to help trace why total_time_taken may remain 0
        try {
          print('[DEBUG] submitAnswerViaFunction - participant BEFORE update: ${participant}');
          print('[DEBUG] submitAnswerViaFunction - timeTakenVal: $timeTakenVal');
          print('[DEBUG] submitAnswerViaFunction - updates BEFORE DB apply (initial): $updates');
        } catch (_) {}
      // Only count a correct answer once per participant per question. If the
      // participant already had a correct attempt for this question, do not
      // increment total_correct/position/character_level again.
      if (isCorrect && !alreadyHadCorrectForThisQuestion) {
        updates['position'] = currentPosition + 1;
        updates['total_correct'] = currentTotalCorrect + 1;
        updates['character_level'] = currentCharLevel + 1;
      }
        // Debug: show the final updates payload that will be written to the DB
        try {
          print('[DEBUG] submitAnswerViaFunction - updates AFTER build: $updates');
        } catch (_) {}

      // If participant didn't have started_at, set it now
      if (participant['started_at'] == null) {
        try {
          updates['started_at'] = DateTime.now().toUtc().toIso8601String();
        } catch (_) {}
      }

      // Check room total_questions to determine if participant finished
      try {
        final roomRes = await supabase.from('quiz_rooms').select('total_questions').eq('room_id', roomId).maybeSingle();
        if (roomRes != null) {
          final roomMap = Map<String, dynamic>.from(roomRes as Map);
          final int totalQuestions = roomMap['total_questions'] is int ? roomMap['total_questions'] as int : int.tryParse(roomMap['total_questions']?.toString() ?? '') ?? 0;
          if (totalQuestions > 0 && newTotalAnswered >= totalQuestions) {
            updates['finished_at'] = DateTime.now().toUtc().toIso8601String();
          }
        }
      } catch (_) {}

      // Use .select().maybeSingle() to get the refreshed participant back from the update
      final updatedRes = await supabase.from('participants').update(updates).eq('participant_id', participant['participant_id']).select().maybeSingle();
      var refP = updatedRes != null ? Map<String, dynamic>.from(updatedRes as Map) : participant;
      try {
        print('[DEBUG] submitAnswerViaFunction - refreshed participant AFTER first update: $refP');
      } catch (_) {}

      // If participant finished the quiz (answered >= total_questions), compute authoritative
      // total_time_taken by summing attempts.time_taken and persist it atomically.
      try {
        final roomRes = await supabase.from('quiz_rooms').select('total_questions').eq('room_id', roomId).maybeSingle();
        final roomMap = roomRes != null ? Map<String, dynamic>.from(roomRes as Map) : null;
        final int totalQuestions = roomMap != null && roomMap['total_questions'] != null
            ? (roomMap['total_questions'] is int ? roomMap['total_questions'] as int : int.tryParse(roomMap['total_questions']?.toString() ?? '') ?? 0)
            : 0;

          if (totalQuestions > 0 && newTotalAnswered >= totalQuestions) {
          // Compute authoritative total_time_taken using the earliest correct
          // attempt per question (fastest correct wins). Query all correct
          // attempts for this participant in the room and aggregate by
          // question_id taking the minimum time_taken per question.
          final attemptsRes = await supabase.from('attempts').select('question_id,time_taken,is_correct').eq('participant_id', participant['participant_id']).eq('room_id', roomId).eq('is_correct', true);
          int sumTime = 0;
          if (attemptsRes is List) {
            final Map<dynamic, int> earliestPerQuestion = {};
            for (final a in attemptsRes) {
              final am = Map<String, dynamic>.from(a as Map);
              final qid = am['question_id'];
              final tt = am['time_taken'];
              final tival = tt is int ? tt : (int.tryParse(tt?.toString() ?? '') ?? 0);
              if (qid == null) continue;
              if (!earliestPerQuestion.containsKey(qid) || earliestPerQuestion[qid]! > tival) {
                earliestPerQuestion[qid] = tival;
              }
            }
            for (final v in earliestPerQuestion.values) {
              sumTime += v;
            }
          }

          final nowIso = DateTime.now().toUtc().toIso8601String();
          final finalUpdate = await supabase.from('participants').update({'total_time_taken': sumTime, 'finished_at': nowIso}).eq('participant_id', participant['participant_id']).select().maybeSingle();
          if (finalUpdate != null) {
            refP = Map<String, dynamic>.from(finalUpdate as Map);
          }
          try {
            print('[DEBUG] submitAnswerViaFunction - computed sumTime: $sumTime');
            print('[DEBUG] submitAnswerViaFunction - refreshed participant AFTER final persist: $refP');
          } catch (_) {}
        }
      } catch (e) {
        try {
          print('[DEBUG] submitAnswerViaFunction - error computing/persisting final sum: $e');
        } catch (_) {}
      }

      // Get leaderboard preview
      final leadersRes = await supabase
          .from('participants')
          .select()
          .eq('room_id', roomId)
          .order('total_correct', ascending: false)
          .order('total_time_taken', ascending: true)
          .order('position', ascending: false)
          .limit(5);

      final leaders = leadersRes as List<dynamic>;

      final leaderboardPreview = <Map<String, dynamic>>[];
      for (var i = 0; i < leaders.length; i++) {
        final l = Map<String, dynamic>.from(leaders[i] as Map);
        final int positionVal = l['position'] is int ? l['position'] as int : int.tryParse(l['position']?.toString() ?? '') ?? 0;
        final int totalCorrectVal = l['total_correct'] is int ? l['total_correct'] as int : int.tryParse(l['total_correct']?.toString() ?? '') ?? 0;
        final int totalTimeVal = l['total_time_taken'] is int ? l['total_time_taken'] as int : int.tryParse(l['total_time_taken']?.toString() ?? '') ?? 0;
        final int totalAnsweredVal = l['total_answered'] is int ? l['total_answered'] as int : int.tryParse(l['total_answered']?.toString() ?? '') ?? 0;
        final int charLevelVal = l['character_level'] is int ? l['character_level'] as int : int.tryParse(l['character_level']?.toString() ?? '') ?? 0;
        
        // Normalize both IDs to int for comparison
        final lParticipantId = l['participant_id'] is int ? l['participant_id'] as int : int.tryParse(l['participant_id']?.toString() ?? '') ?? -1;
        final refParticipantId = refP['participant_id'] is int ? refP['participant_id'] as int : int.tryParse(refP['participant_id']?.toString() ?? '') ?? -1;
        final isCurrentUser = lParticipantId == refParticipantId && lParticipantId > 0;
        
        leaderboardPreview.add({
          'rank': i + 1,
          'nickname': l['nickname']?.toString() ?? '',
          'selected_character': l['selected_character']?.toString(),
          'position': positionVal,
          'total_correct': totalCorrectVal,
          'total_time_taken': totalTimeVal,
          'total_answered': totalAnsweredVal,
          'character_level': charLevelVal,
          'participant_id': lParticipantId,
          'current_user': isCurrentUser
        });
      }

      final resultMap = {
        'is_correct': isCorrect,
        'correct_answer': question['correct_answer'],
        'position_updated': refP['position'],
        'character_level': refP['character_level'],
        'next_question_number': payload['question_number'] != null ? ((payload['question_number'] is int ? payload['question_number'] as int : int.parse(payload['question_number'].toString())) + 1) : null,
        'message': isCorrect ? 'Correct! Your character moved forward.' : 'Wrong! Try next question.',
        // Include current participant id so frontend can always detect current user
        'current_participant_id': refP['participant_id'],
        'leaderboard_preview': leaderboardPreview
      };

      return {
        'attempt': attemptInserted ?? {},
        ...resultMap,
      };
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getLeaderboardViaFunction(int roomId, {String? sessionToken}) async {
    try {
      // Note: caller should provide participant session via other calls; this returns leaderboard for room
      final room = await supabase.from('quiz_rooms').select('room_name,status').eq('room_id', roomId).maybeSingle();
      final roomMap = room != null ? Map<String, dynamic>.from(room as Map) : null;

      // If sessionToken provided, resolve participant_id for marking current_user
      int? currentParticipantId;
      if (sessionToken != null) {
        try {
          final p = await supabase.from('participants').select('participant_id').eq('session_token', sessionToken).maybeSingle();
          if (p != null) currentParticipantId = (p as Map)['participant_id'] is int ? (p as Map)['participant_id'] as int : int.tryParse((p as Map)['participant_id']?.toString() ?? '') ;
        } catch (_) {}
      }

      final res = await supabase
          .from('participants')
          .select()
          .eq('room_id', roomId)
          .order('total_correct', ascending: false)
          .order('total_time_taken', ascending: true)
          .order('position', ascending: false);

      final participants = res as List<dynamic>;
      final leaderboard = <Map<String, dynamic>>[];
      for (var i = 0; i < participants.length; i++) {
        final p = Map<String, dynamic>.from(participants[i] as Map);
        final int positionVal = p['position'] is int ? p['position'] as int : int.tryParse(p['position']?.toString() ?? '') ?? 0;
        final int totalCorrectVal = p['total_correct'] is int ? p['total_correct'] as int : int.tryParse(p['total_correct']?.toString() ?? '') ?? 0;
        final int totalTimeVal = p['total_time_taken'] is int ? p['total_time_taken'] as int : int.tryParse(p['total_time_taken']?.toString() ?? '') ?? 0;
        final int totalAnsweredVal = p['total_answered'] is int ? p['total_answered'] as int : int.tryParse(p['total_answered']?.toString() ?? '') ?? 0;
        final int charLevelVal = p['character_level'] is int ? p['character_level'] as int : int.tryParse(p['character_level']?.toString() ?? '') ?? 0;
        leaderboard.add({
          'rank': i + 1,
          'nickname': p['nickname']?.toString() ?? '',
          'selected_character': p['selected_character']?.toString(),
          'position': positionVal,
          'total_correct': totalCorrectVal,
          'total_time_taken': totalTimeVal,
          'total_answered': totalAnsweredVal,
          'character_level': charLevelVal,
          'current_user': (p['participant_id'] is int ? p['participant_id'] as int : int.tryParse(p['participant_id']?.toString() ?? '')) == currentParticipantId,
        });
      }

      return {
        'room_id': roomId,
        'room_name': roomMap?['room_name'],
        'status': roomMap?['status'],
        'leaderboard': leaderboard
      };
    } catch (e) {
      rethrow;
    }
  }
}
