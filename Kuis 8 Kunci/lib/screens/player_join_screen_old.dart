/// Player Join Screen - Enter name and room code
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

import '../models/api_models.dart';
import '../providers/quiz_provider.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../widgets/player_top_bar.dart';
import 'room_info_screen.dart';

class PlayerJoinScreen extends StatefulWidget {
  const PlayerJoinScreen({super.key});

  @override
  State<PlayerJoinScreen> createState() => _PlayerJoinScreenState();
}

class _PlayerJoinScreenState extends State<PlayerJoinScreen> with SingleTickerProviderStateMixin {
  final _nicknameController = TextEditingController();
  final _roomCodeController = TextEditingController();
  // Use Supabase service now
  final _storage = StorageService();

  late AnimationController _headerPulseController;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _headerPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.92,
      upperBound: 1.06,
    )..repeat(reverse: true);
  }

  void dispose() {
    _nicknameController.dispose();
    _roomCodeController.dispose();
    _headerPulseController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final nickname = _nicknameController.text.trim();
    final roomCode = _roomCodeController.text.trim().toUpperCase();

    if (nickname.isEmpty || roomCode.isEmpty) {
      setState(() => _error = 'Nama dan kode ruangan harus diisi!');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Verify room exists
      final room = await SupabaseService.getRoomByCode(roomCode);
      if (room == null) throw Exception('Ruangan tidak ditemukan');

      // Join room
      final Map<String, dynamic>? response = await SupabaseService.joinRoom({
        'room_id': room['room_id'],
        'nickname': nickname,
      });

      if (response == null) throw Exception('Gagal bergabung ke ruangan');

      // Save session
      // Save session info from Supabase response
      final sessionToken = response['session_token'] as String?;
      await _storage.saveSessionToken(sessionToken ?? '');
      await _storage.saveNickname(nickname);
      await _storage.saveRoomCode(roomCode);

      // Initialize quiz provider
      if (mounted) {
        await context.read<QuizProvider>().initializeQuiz(
          roomId: (response['room_id'] is int) ? response['room_id'] as int : int.tryParse('${response['room_id']}') ?? 0,
          roomCode: roomCode,
          roomName: (room['room_name'] as String?) ?? 'Quiz Room',
          theme: (room['theme'] as String?) ?? 'default',
          sessionToken: sessionToken ?? '',
          totalQuestions: (room['total_questions'] is int) ? room['total_questions'] as int : int.tryParse('${room['total_questions']}') ?? 20,
          timeLimitPerQuestion: (room['time_limit_per_question'] is int) ? room['time_limit_per_question'] as int : int.tryParse('${room['time_limit_per_question']}') ?? 30,
        );

        context.read<QuizProvider>().setPlayerInfo(nickname: nickname);

        // Navigate to room info screen
        if (mounted) {
            Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => RoomInfoScreen(
                response: PlayerJoinResponse.fromJson(response),
                playerName: nickname,
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: PlayerTopBar(
          title: 'Masuk Ruangan Kuis',
          onBackPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),

            // Header Card with playful animation
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue[700]!, Colors.purple[600]!],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  ScaleTransition(
                    scale: _headerPulseController,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.12),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: const Center(
                        child: Icon(Icons.emoji_events, color: Colors.white, size: 42),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DefaultTextStyle(
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          child: AnimatedTextKit(
                            isRepeatingAnimation: false,
                            animatedTexts: [
                              TypewriterAnimatedText('Yuk Ikutan Kuis!'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Masukkan nama dan kode ruangan untuk bergabung',
                          style: TextStyle(color: Colors.white.withOpacity(0.95)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Form Container
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Nickname Input
                  _buildFormField(
                    label: 'Nama Pemainmu',
                    icon: Icons.person,
                    child: TextField(
                      controller: _nicknameController,
                      decoration: _buildInputDecoration(
                        label: 'Masukkan nama kamu',
                        icon: Icons.person,
                        enabled: !_isLoading,
                      ),
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Room Code Input
                  _buildFormField(
                    label: 'Kode Ruangan',
                    icon: Icons.door_front_door,
                    child: TextField(
                      controller: _roomCodeController,
                      decoration: _buildInputDecoration(
                        label: 'Masukkan kode 6 huruf',
                        icon: Icons.door_front_door,
                        enabled: !_isLoading,
                      ),
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _joinRoom(),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Error Message
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[600], size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (_error != null) const SizedBox(height: 16),

            // Join Button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isLoading
                      ? [Colors.grey[400]!, Colors.grey[500]!]
                      : [Colors.green[600]!, Colors.green[400]!],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  if (!_isLoading)
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoading ? null : _joinRoom,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_isLoading) ...[
                          const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        if (_isLoading)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          )
                        else
                          const Text(
                            'Masuk Ruangan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Back Button
            TextButton.icon(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back, color: Colors.grey[600]),
              label: Text(
                'Back',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    required bool enabled,
  }) {
    return InputDecoration(
      hintText: label,
      prefixIcon: Icon(icon, color: Colors.purple[600], size: 20),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.purple[400]!, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }
}
