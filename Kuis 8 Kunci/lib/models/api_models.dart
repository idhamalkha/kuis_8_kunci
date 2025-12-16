/// API Models - Request/Response Classes

// ============================================
// AUTH MODELS
// ============================================

class AdminLoginRequest {
  final String email;
  final String password;

  AdminLoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
  };
}

class AdminLoginResponse {
  final String accessToken;
  final String tokenType;
  final int adminId;
  final String email;
  final String? fullName;

  AdminLoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.adminId,
    required this.email,
    this.fullName,
  });

  factory AdminLoginResponse.fromJson(Map<String, dynamic> json) {
    return AdminLoginResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      adminId: json['admin_id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
    );
  }
}

// ============================================
// PLAYER/PARTICIPANT MODELS
// ============================================

class PlayerJoinRequest {
  final String roomCode;
  final String nickname;

  PlayerJoinRequest({
    required this.roomCode,
    required this.nickname,
  });

  Map<String, dynamic> toJson() => {
    'room_code': roomCode,
    'nickname': nickname,
  };
}

class PlayerJoinResponse {
  final int participantId;
  final String sessionToken;
  final int roomId;
  final String roomName;
  final String theme;
  final int totalQuestions;
  final int timeLimitPerQuestion;

  PlayerJoinResponse({
    required this.participantId,
    required this.sessionToken,
    required this.roomId,
    required this.roomName,
    required this.theme,
    required this.totalQuestions,
    required this.timeLimitPerQuestion,
  });

  factory PlayerJoinResponse.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? fallback;
    }

    String parseString(dynamic v, [String fallback = '']) {
      if (v == null) return fallback;
      return v.toString();
    }

    return PlayerJoinResponse(
      participantId: parseInt(json['participant_id']),
      sessionToken: parseString(json['session_token']),
      roomId: parseInt(json['room_id']),
      roomName: parseString(json['room_name']),
      theme: parseString(json['theme']),
      totalQuestions: parseInt(json['total_questions'], 20),
      timeLimitPerQuestion: parseInt(json['time_limit_per_question'], 30),
    );
  }
}

class RoomInfo {
  final int roomId;
  final String roomCode;
  final String roomName;
  final String theme;
  final String? description;
  final String status;
  final int totalQuestions;
  final int currentParticipants;
  final int maxParticipants;

  RoomInfo({
    required this.roomId,
    required this.roomCode,
    required this.roomName,
    required this.theme,
    this.description,
    required this.status,
    required this.totalQuestions,
    required this.currentParticipants,
    required this.maxParticipants,
  });

  factory RoomInfo.fromJson(Map<String, dynamic> json) {
    return RoomInfo(
      roomId: json['room_id'] as int,
      roomCode: json['room_code'] as String,
      roomName: json['room_name'] as String,
      theme: json['theme'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      totalQuestions: json['total_questions'] as int,
      currentParticipants: json['current_participants'] as int,
      maxParticipants: json['max_participants'] as int,
    );
  }
}

// ============================================
// QUIZ MODELS
// ============================================

class Question {
  final int questionId;
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;

  Question({
    required this.questionId,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      questionId: json['question_id'] as int,
      questionText: json['question_text'] as String,
      optionA: json['option_a'] as String,
      optionB: json['option_b'] as String,
      optionC: json['option_c'] as String,
      optionD: json['option_d'] as String,
    );
  }

  List<String> getOptions() => [optionA, optionB, optionC, optionD];
}

class QuestionLoadResponse {
  final int questionNumber;
  final int totalQuestions;
  final Question? question;
  final int timeLimit;

  QuestionLoadResponse({
    required this.questionNumber,
    required this.totalQuestions,
    this.question,
    required this.timeLimit,
  });

  factory QuestionLoadResponse.fromJson(Map<String, dynamic> json) {
    return QuestionLoadResponse(
      questionNumber: json['question_number'] as int,
      totalQuestions: json['total_questions'] as int,
      question: json['question'] != null
          ? Question.fromJson(json['question'] as Map<String, dynamic>)
          : null,
      timeLimit: json['time_limit'] as int,
    );
  }
}

class AnswerSubmitRequest {
  final int questionNumber;
  final int questionId;
  final String? selectedAnswer;
  final int timeTaken;
  final bool? isFinal;

  AnswerSubmitRequest({
    required this.questionNumber,
    required this.questionId,
    this.selectedAnswer,
    required this.timeTaken,
    this.isFinal,
  });

  Map<String, dynamic> toJson() => {
    'question_number': questionNumber,
    'question_id': questionId,
    'selected_answer': selectedAnswer,
    'time_taken': timeTaken,
    if (isFinal != null) 'is_final': isFinal,
  };
}

class AnswerSubmitResponse {
  final bool isCorrect;
  final String correctAnswer;
  final int positionUpdated;
  final int characterLevel;
  final int? nextQuestionNumber;
  final String message;
  final List<LeaderboardEntry> leaderboardPreview;
  final int? currentParticipantId;

  AnswerSubmitResponse({
    required this.isCorrect,
    required this.correctAnswer,
    required this.positionUpdated,
    required this.characterLevel,
    this.nextQuestionNumber,
    required this.message,
    required this.leaderboardPreview,
    this.currentParticipantId,
  });

  factory AnswerSubmitResponse.fromJson(Map<String, dynamic> json) {
    // Optional current participant id returned by backend for reliable matching
    int? currentPid;
    try {
      if (json.containsKey('current_participant_id')) {
        final v = json['current_participant_id'];
        if (v != null) currentPid = (v is int) ? v : int.tryParse(v.toString());
      }
    } catch (_) {}

    final rawList = (json['leaderboard_preview'] as List<dynamic>?) ?? <dynamic>[];
    final parsedList = <LeaderboardEntry>[];
    for (final item in rawList) {
      final m = Map<String, dynamic>.from(item as Map);
      // Normalize participant id and mark current_user if it matches currentPid
      int? pid;
      try {
        final pv = m['participant_id'];
        if (pv != null) pid = (pv is int) ? pv : int.tryParse(pv.toString());
      } catch (_) {}
      if (currentPid != null && pid != null) {
        m['current_user'] = (pid == currentPid);
      }
      parsedList.add(LeaderboardEntry.fromJson(m));
    }

    return AnswerSubmitResponse(
      isCorrect: json['is_correct'] as bool,
      correctAnswer: json['correct_answer'] as String,
      positionUpdated: json['position_updated'] as int,
      characterLevel: json['character_level'] as int,
      nextQuestionNumber: json['next_question_number'] as int?,
      message: json['message'] as String,
      leaderboardPreview: parsedList,
      currentParticipantId: currentPid,
    );
  }
}

// ============================================
// LEADERBOARD MODELS
// ============================================

class LeaderboardEntry {
  final int rank;
  final String nickname;
  final String? selectedCharacter;
  final int position;
  final int totalCorrect;
  final int totalAnswered;
  final int characterLevel;
  final bool currentUser;
  final int totalTimeTaken;
  final int? participantId;

  LeaderboardEntry({
    required this.rank,
    required this.nickname,
    this.selectedCharacter,
    required this.position,
    required this.totalCorrect,
    required this.totalAnswered,
    required this.characterLevel,
    this.currentUser = false,
    this.totalTimeTaken = 0,
    this.participantId,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? fallback;
    }

    String? parseString(dynamic v) {
      if (v == null) return null;
      return v.toString();
    }

    return LeaderboardEntry(
      rank: parseInt(json['rank']),
      nickname: parseString(json['nickname']) ?? '',
      selectedCharacter: parseString(json['selected_character']),
      position: parseInt(json['position']),
      totalCorrect: parseInt(json['total_correct']),
      totalAnswered: parseInt(json['total_answered']),
      characterLevel: parseInt(json['character_level']),
      currentUser: (json['current_user'] is bool) ? json['current_user'] as bool : (json['current_user'] != null && json['current_user'].toString() == 'true'),
      totalTimeTaken: parseInt(json['total_time_taken']),
      participantId: json['participant_id'] is int ? json['participant_id'] as int : (json['participant_id'] != null ? int.tryParse(json['participant_id'].toString() ?? '') : null),
    );
  }
}

class LeaderboardResponse {
  final int roomId;
  final String roomName;
  final String status;
  final List<LeaderboardEntry> leaderboard;

  LeaderboardResponse({
    required this.roomId,
    required this.roomName,
    required this.status,
    required this.leaderboard,
  });

  factory LeaderboardResponse.fromJson(Map<String, dynamic> json) {
    return LeaderboardResponse(
      roomId: json['room_id'] as int,
      roomName: json['room_name'] as String,
      status: json['status'] as String,
      leaderboard: (json['leaderboard'] as List<dynamic>)
          .map((item) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}

// ============================================
// WEBSOCKET MODELS
// ============================================

class WebSocketMessage {
  final String type;
  final Map<String, dynamic> data;

  WebSocketMessage({
    required this.type,
    required this.data,
  });

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] as String,
      data: (json['data'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'data': data,
  };
}

class PingMessage extends WebSocketMessage {
  PingMessage() : super(type: 'ping', data: {});
}

class AnswerSubmittedMessage extends WebSocketMessage {
  final String nickname;
  final bool isCorrect;
  final int position;
  final int characterLevel;
  final int currentQuestion;

  AnswerSubmittedMessage({
    required this.nickname,
    required this.isCorrect,
    required this.position,
    required this.characterLevel,
    required this.currentQuestion,
  }) : super(
    type: 'answer_submitted',
    data: {
      'nickname': nickname,
      'is_correct': isCorrect,
      'position': position,
      'character_level': characterLevel,
      'current_question': currentQuestion,
    },
  );

  factory AnswerSubmittedMessage.fromJson(Map<String, dynamic> json) {
    return AnswerSubmittedMessage(
      nickname: json['nickname'] as String,
      isCorrect: json['is_correct'] as bool,
      position: json['position'] as int,
      characterLevel: json['character_level'] as int,
      currentQuestion: json['current_question'] as int,
    );
  }
}
