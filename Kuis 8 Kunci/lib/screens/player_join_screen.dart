// Player Join Screen - Gamified Room Entry with Fun Animations
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

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

class _PlayerJoinScreenState extends State<PlayerJoinScreen>
    with SingleTickerProviderStateMixin {
  final _nicknameController = TextEditingController();
  final _roomCodeController = TextEditingController();
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
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _roomCodeController.dispose();
    _headerPulseController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final quizProvider = context.read<QuizProvider>();
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
      final room = await SupabaseService.getRoomByCode(roomCode);
      if (room == null) throw Exception('Ruangan tidak ditemukan');

      final Map<String, dynamic>? response =
          await SupabaseService.joinRoom({
        'room_id': room['room_id'],
        'nickname': nickname,
      });

      if (response == null) throw Exception('Gagal bergabung ke ruangan');

      final sessionToken = response['session_token'] as String?;
      await _storage.saveSessionToken(sessionToken ?? '');
      await _storage.saveNickname(nickname);
      await _storage.saveRoomCode(roomCode);

      if (mounted) {
        await quizProvider.initializeQuiz(
          roomId: (response['room_id'] is int)
              ? response['room_id'] as int
              : int.tryParse('${response['room_id']}') ?? 0,
          roomCode: roomCode,
          roomName: (room['room_name'] as String?) ?? 'Quiz Room',
          theme: (room['theme'] as String?) ?? 'default',
          sessionToken: sessionToken ?? '',
          totalQuestions: (room['total_questions'] is int)
              ? room['total_questions'] as int
              : int.tryParse('${room['total_questions']}') ?? 20,
          timeLimitPerQuestion: (room['time_limit_per_question'] is int)
              ? room['time_limit_per_question'] as int
              : int.tryParse('${room['time_limit_per_question']}') ?? 30,
        );

        quizProvider.setPlayerInfo(nickname: nickname);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => RoomInfoScreen(
                playerName: nickname,
                response: PlayerJoinResponse(
                  sessionToken: sessionToken ?? '',
                  participantId: response['participant_id'] as int? ?? 0,
                  roomId: response['room_id'] as int,
                  roomName: room['room_name'] as String? ?? 'Ruangan',
                  theme: room['theme'] as String? ?? 'default',
                  totalQuestions: (room['total_questions'] is int)
                      ? room['total_questions'] as int
                      : 20,
                  timeLimitPerQuestion: (room['time_limit_per_question'] is int)
                      ? room['time_limit_per_question'] as int
                      : 30,
                ),
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
          title: '🎮 Masuk Ruangan Kuis',
          onBackPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[600]!,
              Colors.purple[500]!,
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              // add extra bottom padding so last button isn't flush with screen edge
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: AnimationConfiguration.toStaggeredList(
                      duration: const Duration(milliseconds: 500),
                      childAnimationBuilder: (widget) => SlideAnimation(
                        horizontalOffset: 50.0,
                        child: FadeInAnimation(child: widget),
                      ),
                      children: [
                        const SizedBox(height: 16),

                        // ========== HEADER CARD ==========
                        Hero(
                          tag: 'quiz-header',
                          child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.cyan[400]!, Colors.teal[400]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyan[400]!.withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              ScaleTransition(
                                scale: Tween<double>(begin: 0.95, end: 1.05).animate(
                                  CurvedAnimation(
                                    parent: _headerPulseController,
                                    curve: Curves.linear,
                                  ),
                                ),
                                child: const Text(
                                  '👤',
                                  style: TextStyle(fontSize: 60),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Ayo Bergabung!',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Masukkan nama dan kode ruangan',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                  ),
                  const SizedBox(height: 32),

                        // ========== FORM FIELDS ==========
                        // Nickname Field
                        _buildFormField(
                          label: '📝 Nama Pemain',
                          icon: Icons.person,
                          child: TextField(
                            controller: _nicknameController,
                            enabled: !_isLoading,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: 'Masukkan nama mu...',
                              hintStyle: const TextStyle(color: Colors.grey),
                              prefixIcon: Icon(Icons.person,
                                  color: Colors.cyan[600], size: 22),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.95),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.cyan[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.cyan[300]!,
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.cyan[600]!,
                                  width: 3,
                                ),
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Room Code Field
                        _buildFormField(
                          label: '🔑 Kode Ruangan',
                          icon: Icons.vpn_key,
                          child: TextField(
                            controller: _roomCodeController,
                            enabled: !_isLoading,
                            textInputAction: TextInputAction.done,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'Contoh: ABC123',
                              hintStyle: const TextStyle(color: Colors.grey),
                              prefixIcon: Icon(Icons.vpn_key,
                                  color: Colors.purple[600], size: 22),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.95),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.purple[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.purple[300]!,
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.purple[600]!,
                                  width: 3,
                                ),
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ========== ERROR MESSAGE ==========
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red[400]!,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error, color: Colors.red[700], size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Colors.red[900],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().shake(duration: 400.ms),

                        if (_error != null) const SizedBox(height: 20),

                        // ========== JOIN BUTTON ==========
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [Colors.green[600]!, Colors.teal[500]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green[600]!.withValues(alpha: 0.5),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isLoading ? null : _joinRoom,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Center(
                                  child: _isLoading
                                      ? SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.login,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              'Bergabung dengan Kuis',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ========== BACK BUTTON ==========
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          label: const Text(
                            'Kembali ke Menu',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),

                        // Extra bottom spacing so buttons aren't too close to the device bottom
                        const SizedBox(height: 36),
                      ],
                    ),
              ),
            );
          },
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
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
