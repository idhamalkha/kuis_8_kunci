/// Room Info Screen - Gamified Room Details with Exciting Animations
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../models/api_models.dart';
import '../widgets/player_top_bar.dart';
import 'quiz_screen_gamified.dart';

class RoomInfoScreen extends StatefulWidget {
  final PlayerJoinResponse response;
  final String playerName;

  const RoomInfoScreen({
    super.key,
    required this.response,
    required this.playerName,
  });

  @override
  State<RoomInfoScreen> createState() => _RoomInfoScreenState();
}

class _RoomInfoScreenState extends State<RoomInfoScreen> {
  bool _showStartAnimation = false;

  void _startQuiz() async {
    setState(() => _showStartAnimation = true);
    await Future.delayed(const Duration(milliseconds: 600));
    
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const QuizScreenGamified(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final contentWidth = math.min(760.0, screenWidth * 0.94);
    final titleFont = screenWidth < 360 ? 20.0 : (screenWidth < 520 ? 22.0 : 24.0);
    final bodyFont = math.max(12.0, screenWidth * 0.036);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: PlayerTopBar(
          title: '📋 Info Ruangan Kuis',
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
              Colors.indigo[600]!,
              Colors.purple[500]!,
              Colors.pink[400]!,
            ],
          ),
        ),
        child: SingleChildScrollView(
          // add extra bottom padding so the back button isn't flush with the device bottom
          padding: EdgeInsets.fromLTRB(math.max(12, screenWidth * 0.03), math.max(12, screenWidth * 0.03), math.max(12, screenWidth * 0.03), 36),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 500),
              childAnimationBuilder: (widget) => SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(child: widget),
              ),
              children: [
                const SizedBox(height: 12),

                // ========== WELCOME CARD ==========
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber[300]!, Colors.yellow[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber[300]!.withValues(alpha: 0.6),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(math.max(16, screenWidth * 0.04)),
                    child: Column(
                      children: [
                        const Text(
                          '🎉',
                          style: TextStyle(fontSize: 60),
                        ).animate().scaleXY(
                              begin: 0.8,
                              end: 1.0,
                              duration: 600.ms,
                              delay: 200.ms,
                            ),
                        const SizedBox(height: 12),
                        Text(
                          'Selamat Datang, ${widget.playerName}!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: titleFont,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Siap mengikuti kuis yang menakjubkan?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: bodyFont,
                            color: Colors.black.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 28),

                // ========== ROOM INFO CARD ==========
                _GameInfoCard(
                  icon: '🏠',
                  title: 'Informasi Ruangan',
                  child: Column(
                    children: [
                      _buildInfoRow(
                        '📌 Kode Ruangan',
                        '${widget.response.roomId}',
                        Colors.purple[600]!,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        '📝 Jumlah Soal',
                        '${widget.response.totalQuestions} Soal',
                        Colors.blue[600]!,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        '⏱️ Waktu per Soal',
                        '${widget.response.timeLimitPerQuestion} Detik',
                        Colors.orange[600]!,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ========== PLAYER CARD ==========
                _GameInfoCard(
                  icon: '👤',
                  title: 'Profil Pemain Mu',
                  child: Column(
                    children: [
                      _buildInfoRow(
                        '🎮 Nama Pemain',
                        widget.playerName,
                        Colors.green[600]!,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        '⭐ Status',
                        'Siap Bermain',
                        Colors.amber[600]!,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        '🏆 Skor Awal',
                        '0 Poin',
                        Colors.pink[600]!,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ========== TIPS CARD ==========
                Container(
                  padding: EdgeInsets.all(math.max(12, screenWidth * 0.03)),
                  decoration: BoxDecoration(
                    color: Colors.cyan[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.cyan[200]!,
                      width: 2.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡',
                        style: TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tips Bermain',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.cyan[900],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Bacalah soal dengan teliti, pilih jawaban terbaik, dan pastikan menjawab sebelum waktu habis!',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.cyan[800],
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ========== START BUTTON ==========
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.green[600]!, Colors.teal[500]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green[600]!.withValues(alpha: 0.6),
                        blurRadius: 24,
                        spreadRadius: 4,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _startQuiz,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '🚀 Mulai Kuis Sekarang!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: screenWidth < 360 ? 16 : 22,
                                letterSpacing: 1.5,
                              ),
                            ),
                            if (_showStartAnimation)
                              const Text(
                                '  🎉',
                                style: TextStyle(fontSize: 20),
                              )
                                  .animate()
                                  .scaleXY(
                                    begin: 1.5,
                                    end: 1.0,
                                    duration: 400.ms,
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // ========== BACK BUTTON ==========
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: 2.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text(
                    'Kembali ke Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      )));
  }

  Widget _buildInfoRow(String label, String value, Color accentColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: accentColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Game Info Card Widget
class _GameInfoCard extends StatelessWidget {
  final String icon;
  final String title;
  final Widget child;

  const _GameInfoCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final pad = math.max(12.0, screenWidth * 0.04);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
