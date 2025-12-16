/// Results Screen - Elegant & Simple Results for Kids
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';

import '../providers/quiz_provider.dart';
import 'home_screen.dart';

class ResultsScreenElegant extends StatefulWidget {
  const ResultsScreenElegant({super.key});

  @override
  State<ResultsScreenElegant> createState() => _ResultsScreenElegantState();
}

class _ResultsScreenElegantState extends State<ResultsScreenElegant> {
  late Future<void> _loadLeaderboard;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard = _loadData();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  Future<void> _loadData() async {
    final provider = context.read<QuizProvider>();
    await provider.loadLeaderboard();
    // If current player is top, celebrate!
    final lb = provider.leaderboard;
    final me = provider.nickname;
    if (lb.isNotEmpty && me != null && lb.first.nickname == me) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _goHome() {
    context.read<QuizProvider>().resetQuiz();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: FutureBuilder<void>(
        future: _loadLeaderboard,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[600]),
                  const SizedBox(height: 16),
                  const Text('Ada masalah memuat hasil'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _goHome,
                    child: const Text('Kembali ke Beranda'),
                  ),
                ],
              ),
            );
          }

          return Consumer<QuizProvider>(
            builder: (context, provider, _) {
              final totalCorrect = provider.totalCorrect;
              final totalQuestions = provider.totalQuestions;
              final accuracy =
                  ((totalCorrect / totalQuestions) * 100).toStringAsFixed(0);

              return SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // === HEADER ===
                        const SizedBox(height: 20),
                        Text(
                          'Selesai!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[900],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // === SCORE CARD ===
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[600]!, Colors.blue[500]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Text(
                                'Skor Akhir',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: totalCorrect.toString(),
                                      style: const TextStyle(
                                        fontSize: 56,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' / $totalQuestions',
                                      style: TextStyle(
                                        fontSize: 24,
                                        color: Colors.white.withValues(alpha: 0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Accuracy Bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: totalCorrect / totalQuestions,
                                  minHeight: 8,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    Colors.greenAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$accuracy% Benar',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // === STATUS MESSAGE ===
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              _getStatusMessage(int.parse(accuracy)),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                                height: 1.6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // === LEADERBOARD SECTION ===
                        Text(
                          'Peringkat Pemain',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[900],
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (provider.leaderboard.isEmpty)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Belum ada pemain lain',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: provider.leaderboard.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final entry = provider.leaderboard[index];
                              final playerName = entry.nickname;
                              final score = entry.totalCorrect;
                              final total = provider.totalQuestions > 0
                                  ? provider.totalQuestions
                                  : 1;
                              final progress = (score / total).clamp(0.0, 1.0);
                              final level = _calculateLevel(score);

                              final isTop = index == 0;

                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 1.0, end: isTop ? 1.03 : 1.0),
                                duration: const Duration(milliseconds: 500),
                                builder: (context, scale, child) {
                                  return Transform.scale(
                                    scale: scale,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isTop ? Colors.amber[200]! : Colors.grey[200]!,
                                      width: isTop ? 1.5 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: isTop ? 16 : 8,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: RadialGradient(
                                                colors: isTop
                                                    ? [Colors.amber.shade200, Colors.orange.shade200]
                                                    : [Colors.blue.shade50, Colors.blue.shade100],
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                playerName.isNotEmpty ? playerName[0].toUpperCase() : '?',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: isTop ? Colors.brown[800] : Colors.blue[800],
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (index == 0)
                                            Positioned(
                                              right: -4,
                                              top: -6,
                                              child: Icon(Icons.emoji_events, color: Colors.amber[700], size: 22),
                                            )
                                          else if (index == 1)
                                            Positioned(
                                              right: -4,
                                              top: -6,
                                              child: Icon(Icons.looks_two, color: Colors.grey[600], size: 20),
                                            )
                                          else if (index == 2)
                                            Positioned(
                                              right: -4,
                                              top: -6,
                                              child: Icon(Icons.looks_3, color: Colors.brown[400], size: 20),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    playerName,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.grey[900],
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [Colors.purple[400]!, Colors.blue[400]!],
                                                    ),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    'Lv $level',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: LinearProgressIndicator(
                                                minHeight: 8,
                                                value: progress,
                                                valueColor: AlwaysStoppedAnimation(isTop ? Colors.orange : Colors.blue),
                                                backgroundColor: Colors.grey[200],
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '$score dari $total soal',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                ),
                                                Row(
                                                  children: [
                                                    if (isTop) Icon(Icons.star, color: Colors.amber[600], size: 18) else const SizedBox.shrink(),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '#${index + 1}',
                                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 32),

                        // === ACTION BUTTONS ===
                        ElevatedButton(
                          onPressed: _goHome,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: const Text(
                            'Kembali ke Beranda',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _getStatusMessage(int accuracy) {
    if (accuracy == 100) {
      return '🌟 Sempurna! Kamu sangat luar biasa!';
    } else if (accuracy >= 80) {
      return '✨ Sangat bagus! Terus belajar ya!';
    } else if (accuracy >= 60) {
      return '👍 Bagus! Coba lagi untuk lebih baik!';
    } else if (accuracy >= 40) {
      return '💪 Cukup baik! Semangat belajar lagi!';
    } else {
      return '📚 Terus belajar dan coba lagi!';
    }
  }

  int _calculateLevel(int score) {
    // Simple leveling: every 3 correct answers = 1 level, minimum level 1
    final lv = (score ~/ 3) + 1;
    return lv < 1 ? 1 : lv;
  }
}
