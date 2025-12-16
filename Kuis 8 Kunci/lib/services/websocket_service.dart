/// WebSocket Service - Real-time Quiz Updates

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';
import 'dart:convert';

import '../config/app_config.dart';
import '../models/api_models.dart';

typedef OnWebSocketMessage = Function(WebSocketMessage message);
typedef OnWebSocketError = Function(String error);
typedef OnWebSocketClose = Function();

class WebSocketService {
  final logger = Logger();
  
  late WebSocketChannel? _channel;
  late OnWebSocketMessage _onMessage;
  late OnWebSocketError _onError;
  late OnWebSocketClose _onClose;
  
  bool _isConnected = false;

  static final WebSocketService _instance = WebSocketService._internal();

  factory WebSocketService() {
    return _instance;
  }

  WebSocketService._internal() {
    _channel = null;
  }

  // ============================================
  // CONNECTION MANAGEMENT
  // ============================================

  Future<void> connect({
    required int roomId,
    required String sessionToken,
    required OnWebSocketMessage onMessage,
    required OnWebSocketError onError,
    required OnWebSocketClose onClose,
  }) async {
    try {
      _onMessage = onMessage;
      _onError = onError;
      _onClose = onClose;

      final wsUrl = Uri.parse(
        '${AppConfig.wsBaseUrl}/ws/room/$roomId?token=$sessionToken',
      );

      logger.i('Connecting to WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(wsUrl);

      // Listen for messages
      _channel!.stream.listen(
        (message) {
          try {
            final decoded = jsonDecode(message as String);
            final wsMessage = WebSocketMessage.fromJson(
              decoded as Map<String, dynamic>,
            );
            _onMessage(wsMessage);
          } catch (e) {
            logger.e('Error parsing WebSocket message: $e');
            _onError('Error parsing message: $e');
          }
        },
        onError: (error) {
          logger.e('WebSocket error: $error');
          _isConnected = false;
          _onError('WebSocket error: $error');
        },
        onDone: () {
          logger.i('WebSocket connection closed');
          _isConnected = false;
          _onClose();
        },
      );

      _isConnected = true;
      logger.i('WebSocket connected successfully');
    } catch (e) {
      logger.e('Failed to connect WebSocket: $e');
      _isConnected = false;
      _onError('Failed to connect: $e');
      rethrow;
    }
  }

  void disconnect() {
    try {
      if (_channel != null) {
        _channel!.sink.close();
        _channel = null;
        _isConnected = false;
        logger.i('WebSocket disconnected');
      }
    } catch (e) {
      logger.e('Error disconnecting WebSocket: $e');
    }
  }

  bool get isConnected => _isConnected;

  // ============================================
  // SEND MESSAGES
  // ============================================

  void sendPing() {
    if (_isConnected && _channel != null) {
      try {
        final message = PingMessage();
        _channel!.sink.add(jsonEncode(message.toJson()));
        logger.i('Ping sent');
      } catch (e) {
        logger.e('Error sending ping: $e');
      }
    }
  }

  void sendAnswerSubmitted({
    required int questionNumber,
    required String selectedAnswer,
    required int position,
    required int characterLevel,
    required int currentQuestion,
  }) {
    if (_isConnected && _channel != null) {
      try {
        final message = AnswerSubmittedMessage(
          nickname: '', // Server will set this
          isCorrect: false, // Server will verify
          position: position,
          characterLevel: characterLevel,
          currentQuestion: currentQuestion,
        );
        _channel!.sink.add(jsonEncode(message.toJson()));
        logger.i('Answer submitted via WebSocket');
      } catch (e) {
        logger.e('Error sending answer: $e');
      }
    }
  }

  void sendCustomMessage(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(data));
        logger.i('Custom message sent');
      } catch (e) {
        logger.e('Error sending custom message: $e');
      }
    }
  }
}
