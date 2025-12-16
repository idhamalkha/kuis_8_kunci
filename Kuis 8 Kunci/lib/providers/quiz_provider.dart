/// Quiz Provider - State Management for Quiz

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/api_models.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class QuizProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();

  // Quiz State
  int? _roomId;
  String? _roomCode;
  String? _roomName;
  String? _theme;
  String? _sessionToken;
  int _totalQuestions = 20;
  int _currentQuestionNumber = 1;
  Question? _currentQuestion;
  int _timeLimit = 30;
  int _timeRemaining = 30;

  // Player State
  String? _nickname;
  String? _selectedCharacter;
  int _position = 0;
  int _characterLevel = 0;
  int _totalCorrect = 0;
  int _totalAnswered = 0;

  // Leaderboard
  List<LeaderboardEntry> _leaderboard = [];

  // UI State
  bool _isLoading = false;
  String? _error;
  bool _quizStarted = false;
  bool _quizFinished = false;

  // Getters
  int? get roomId => _roomId;
  String? get roomCode => _roomCode;
  String? get roomName => _roomName;
  String? get theme => _theme;
  String? get sessionToken => _sessionToken;
  int get totalQuestions => _totalQuestions;
  int get currentQuestionNumber => _currentQuestionNumber;
  Question? get currentQuestion => _currentQuestion;
  int get timeLimit => _timeLimit;
  int get timeRemaining => _timeRemaining;

  String? get nickname => _nickname;
  String? get selectedCharacter => _selectedCharacter;
  int get position => _position;
  int get characterLevel => _characterLevel;
  int get totalCorrect => _totalCorrect;
  int get totalAnswered => _totalAnswered;

  List<LeaderboardEntry> get leaderboard => _leaderboard;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get quizStarted => _quizStarted;
  bool get quizFinished => _quizFinished;

  // ============================================
  // INIT & SETUP
  // ============================================

  Future<void> initializeQuiz({
    required int roomId,
    required String roomCode,
    required String roomName,
    required String theme,
    required String sessionToken,
    required int totalQuestions,
    required int timeLimitPerQuestion,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      _roomId = roomId;
      _roomCode = roomCode;
      _roomName = roomName;
      _theme = theme;
      _sessionToken = sessionToken;
      _totalQuestions = totalQuestions;
      _timeLimit = timeLimitPerQuestion;
      _timeRemaining = timeLimitPerQuestion;

      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize quiz: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void setPlayerInfo({required String nickname}) {
    _nickname = nickname;
    notifyListeners();
  }

  void setSelectedCharacter(String character) {
    _selectedCharacter = character;
    notifyListeners();
  }

  // ============================================
  // QUIZ FLOW
  // ============================================

  Future<void> startQuiz() async {
    try {
      _isLoading = true;
      // Use microtask to avoid calling notifyListeners during build phase
      scheduleMicrotask(() => notifyListeners());

      if (_roomId == null) {
        throw Exception('Room ID not set');
      }

      if (_sessionToken == null) {
        throw Exception('Session token not set');
      }

      final response = await _apiService.startQuiz(
        _sessionToken!,
        _roomId!,
        selectedCharacter: _selectedCharacter,
      );
      _currentQuestion = response.question;
      _currentQuestionNumber = response.questionNumber;
      _totalQuestions = response.totalQuestions;
      _timeLimit = response.timeLimit;
      _timeRemaining = response.timeLimit;

      _quizStarted = true;
      _error = null;
      _isLoading = false;
      notifyListeners();

      // Load initial leaderboard for tree visualization
      await loadLeaderboard();
    } catch (e) {
      _error = 'Failed to start quiz: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadQuestion(int questionNumber) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_roomId == null) {
        throw Exception('Room ID not set');
      }

      final response = await _apiService.getQuestion(_roomId!, questionNumber);
      _currentQuestion = response.question;
      _currentQuestionNumber = response.questionNumber;
      _timeLimit = response.timeLimit;
      _timeRemaining = response.timeLimit;

      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load question: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitAnswer({
    String? selectedAnswer,
    required int timeTaken,
    bool isFinal = false,
  }) async {
    final resp = await submitAnswerRaw(
      selectedAnswer: selectedAnswer,
      timeTaken: timeTaken,
      isFinal: isFinal,
    );
    return resp.isCorrect;
  }

  /// Submit answer and return full [AnswerSubmitResponse].
  Future<AnswerSubmitResponse> submitAnswerRaw({
    String? selectedAnswer,
    required int timeTaken,
    bool isFinal = false,
  }) async {
    try {
      if (_roomId == null || _currentQuestion == null || _sessionToken == null) {
        throw Exception('Missing required data');
      }
      final request = AnswerSubmitRequest(
        questionNumber: _currentQuestionNumber,
        questionId: _currentQuestion!.questionId,
        selectedAnswer: selectedAnswer,
        timeTaken: timeTaken,
        isFinal: isFinal,
      );

      final response = await _apiService.submitAnswer(
        roomId: _roomId!,
        sessionToken: _sessionToken!,
        request: request,
      );

      // Update player state from authoritative response
      _position = response.positionUpdated;
      _characterLevel = response.characterLevel;

      // Use leaderboard preview to update local per-player stats when available
      _leaderboard = response.leaderboardPreview;
      bool foundCurrentUser = false;
      try {
        final me = response.leaderboardPreview.firstWhere((e) => e.currentUser);
        _totalAnswered = me.totalAnswered;
        _totalCorrect = me.totalCorrect;
        foundCurrentUser = true;
      } catch (_) {}

      // Fallback: if server returned a current participant id, try to match by participantId
      if (!foundCurrentUser && response.currentParticipantId != null) {
        try {
          final me2 = response.leaderboardPreview.firstWhere((e) => e.participantId == response.currentParticipantId);
          _totalAnswered = me2.totalAnswered;
          _totalCorrect = me2.totalCorrect;
          foundCurrentUser = true;
        } catch (_) {}
      }

      // Refresh authoritative leaderboard
      try {
        await loadLeaderboard();
      } catch (_) {}

      _error = null;
      notifyListeners();

      return response;
    } catch (e) {
      _error = 'Failed to submit answer: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadLeaderboard() async {
    try {
      if (_roomId == null || _sessionToken == null) {
        throw Exception('Room ID or Session Token not set');
      }

      final response = await _apiService.getLeaderboard(_roomId!, _sessionToken!);
      _leaderboard = response.leaderboard;

      // If the leaderboard includes a current user entry, update local totals
      try {
        final me = _leaderboard.firstWhere((e) => e.currentUser);
        _totalAnswered = me.totalAnswered;
        _totalCorrect = me.totalCorrect;
      } catch (_) {
        // Fallback: if leaderboard entries have participantId and ApiService can provide current participant id,
        // we could match by that, but for now if no current_user flag present do not change totals.
      }

      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load leaderboard: $e';
      notifyListeners();
    }
  }

  void finishQuiz() {
    _quizFinished = true;
    notifyListeners();
  }

  // ============================================
  // WEBSOCKET
  // ============================================

  Future<void> connectWebSocket(String sessionToken) async {
    try {
      if (_roomId == null) {
        throw Exception('Room ID not set');
      }

      await _wsService.connect(
        roomId: _roomId!,
        sessionToken: sessionToken,
        onMessage: _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onClose: _handleWebSocketClose,
      );
    } catch (e) {
      _error = 'Failed to connect WebSocket: $e';
      notifyListeners();
    }
  }

  void disconnectWebSocket() {
    _wsService.disconnect();
  }

  void _handleWebSocketMessage(WebSocketMessage message) {
    switch (message.type) {
      case 'answer_submitted':
        // Update leaderboard with other player's answer
        final answerMsg = AnswerSubmittedMessage.fromJson(message.data);
        _updateLeaderboardFromWebSocket(answerMsg);
        break;

      case 'leaderboard_updated':
        // Full leaderboard update
        final data = message.data;
        if (data['leaderboard'] != null) {
          _leaderboard = (data['leaderboard'] as List<dynamic>)
              .map((item) => LeaderboardEntry.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        break;

      case 'quiz_finished':
        _quizFinished = true;
        break;

      case 'pong':
        // Keep-alive response
        break;

      default:
        // Handle other message types as needed
        break;
    }
    notifyListeners();
  }

  void _updateLeaderboardFromWebSocket(AnswerSubmittedMessage message) {
    // Update or add participant in leaderboard
    final existingIndex = _leaderboard.indexWhere(
      (entry) => entry.nickname == message.nickname,
    );
    if (existingIndex != -1) {
      final existing = _leaderboard[existingIndex];
      _leaderboard[existingIndex] = LeaderboardEntry(
        rank: existing.rank,
        nickname: message.nickname,
        selectedCharacter: existing.selectedCharacter,
        position: message.position,
        totalCorrect: existing.totalCorrect + (message.isCorrect ? 1 : 0),
        totalAnswered: existing.totalAnswered + 1,
        characterLevel: message.characterLevel,
        currentUser: existing.currentUser,
        totalTimeTaken: existing.totalTimeTaken, // preserve accumulated time
        participantId: existing.participantId,
      );
    } else {
      // Add a new entry if not present (no time info available)
      _leaderboard.add(LeaderboardEntry(
        rank: _leaderboard.length + 1,
        nickname: message.nickname,
        selectedCharacter: null,
        position: message.position,
        totalCorrect: message.isCorrect ? 1 : 0,
        totalAnswered: 1,
        characterLevel: message.characterLevel,
        currentUser: false,
        totalTimeTaken: 0,
        participantId: null,
      ));
    }

    // Re-sort using server ordering: total_correct DESC, total_time_taken ASC, position DESC
    _leaderboard.sort((a, b) {
      if (a.totalCorrect != b.totalCorrect) return b.totalCorrect.compareTo(a.totalCorrect);
      if (a.totalTimeTaken != b.totalTimeTaken) return a.totalTimeTaken.compareTo(b.totalTimeTaken);
      return b.position.compareTo(a.position);
    });

    // Update ranks while preserving other fields
    for (int i = 0; i < _leaderboard.length; i++) {
      final e = _leaderboard[i];
      _leaderboard[i] = LeaderboardEntry(
        rank: i + 1,
        nickname: e.nickname,
        selectedCharacter: e.selectedCharacter,
        position: e.position,
        totalCorrect: e.totalCorrect,
        totalAnswered: e.totalAnswered,
        characterLevel: e.characterLevel,
        currentUser: e.currentUser,
        totalTimeTaken: e.totalTimeTaken,
        participantId: e.participantId,
      );
    }
  }

  void _handleWebSocketError(String error) {
    _error = 'WebSocket error: $error';
    notifyListeners();
  }

  void _handleWebSocketClose() {
    // Handle WebSocket close
    notifyListeners();
  }

  // ============================================
  // TIMER
  // ============================================

  void setTimeRemaining(int time) {
    _timeRemaining = time;
    notifyListeners();
  }

  void decrementTime() {
    if (_timeRemaining > 0) {
      _timeRemaining--;
      notifyListeners();
    }
  }

  // ============================================
  // RESET
  // ============================================

  void resetQuiz() {
    _roomId = null;
    _roomCode = null;
    _roomName = null;
    _theme = null;
    _totalQuestions = 20;
    _currentQuestionNumber = 1;
    _currentQuestion = null;
    _timeLimit = 30;
    _timeRemaining = 30;

    _nickname = null;
    _position = 0;
    _characterLevel = 0;
    _totalCorrect = 0;
    _totalAnswered = 0;

    _leaderboard = [];

    _isLoading = false;
    _error = null;
    _quizStarted = false;
    _quizFinished = false;

    disconnectWebSocket();
    notifyListeners();
  }
}
