/// Results Screen - Show final results with playful gamified design
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../providers/quiz_provider.dart';
import '../widgets/player_top_bar.dart';
import 'home_screen.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  late Future<void> _loadLeaderboard;
  late AnimationController _celebrationController;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard = _loadData();
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
  }

  Future<void> _loadData() async {
    final provider = context.read<QuizProvider>();
    await provider.loadLeaderboard();
  }

  void _goHome() {
    context.read<QuizProvider>().resetQuiz();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange[400]!,
              Colors.pink[400]!,
              Colors.purple[400]!,
            ],
          ),
        ),
        child: FutureBuilder<void>(
        future: _loadLeaderboard,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          return Consumer<QuizProvider>(
            builder: (context, provider, _) {
                // Use totalQuestions as the authoritative denominator for accuracy when available.
                final int denom = provider.totalQuestions > 0 ? provider.totalQuestions : provider.totalAnswered;
                final accuracy = denom > 0 ? (provider.totalCorrect / denom * 100) : 0.0;
              final medal = _getMedal(accuracy);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    // 🎉 Celebration Section
                    ScaleTransition(
                      scale: Tween<double>(begin: 0, end: 1).animate(
                        CurvedAnimation(
                          parent: _celebrationController,
                          curve: Curves.elasticOut,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Celebration emoji
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.2),
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                medal,
                                style: const TextStyle(fontSize: 56),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Title
                          const Text(
                            'SELAMAT! 🎉',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  offset: Offset(2, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),

                          // Subtitle
                          Text(
                            'Kamu berhasil menyelesaikan kuis!',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Score Card - Big and Playful
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.blue[50]!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          // Big Score Display
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _ScoreBox(
                                label: 'Benar',
                                value: provider.totalCorrect.toString(),
                                icon: '✅',
                                color: Colors.green[500]!,
                              ),
                              _ScoreBox(
                                label: 'Total',
                                // Show quiz total questions when available, otherwise fallback to total answered
                                value: (provider.totalQuestions > 0 ? provider.totalQuestions : provider.totalAnswered).toString(),
                                icon: '❓',
                                color: Colors.blue[500]!,
                              ),
                              _ScoreBox(
                                label: 'Akurasi',
                                value: '${accuracy.toStringAsFixed(0)}%',
                                icon: '🎯',
                                color: Colors.orange[500]!,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(
                              value: accuracy / 100,
                              minHeight: 16,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                accuracy >= 80
                                    ? Colors.green[500]!
                                    : accuracy >= 60
                                        ? Colors.orange[500]!
                                        : Colors.red[500]!,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Performance message
                          Text(
                            _getPerformanceMessage(accuracy),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Leaderboard Section - Simplified
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                '🏆 Top 3 Pemain',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(
                            provider.leaderboard.length > 3
                                ? 3
                                : provider.leaderboard.length,
                            (index) {
                              final entry = provider.leaderboard[index];
                              return _PlayfulLeaderboardRow(
                                rank: entry.rank,
                                nickname: entry.nickname,
                                correct: entry.totalCorrect,
                                index: index,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Home Button - Playful
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.lime[400]!,
                            Colors.green[400]!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _goHome,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  '🏠 Kembali ke Beranda',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
                                        offset: Offset(1, 1),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      ),
      ),
    );
  }

  String _getPerformanceMessage(double accuracy) {
    if (accuracy >= 90) {
      return '🌟 Luar biasa! Kamu jenius!';
    } else if (accuracy >= 75) {
      return '⭐ Sangat bagus! Teruskan!';
    } else if (accuracy >= 60) {
      return '👍 Bagus! Terus latihan!';
    } else {
      return '💪 Jangan menyerah! Coba lagi!';
    }
  }

  String _getMedal(double accuracy) {
    if (accuracy >= 90) {
      return '🏅';
    } else if (accuracy >= 75) {
      return '⭐';
    } else if (accuracy >= 60) {
      return '🎖️';
    } else {
      return '🎯';
    }
  }
}

/// Score box widget for displaying scores
class _ScoreBox extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  final Color color;

  const _ScoreBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.8),
                color.withValues(alpha: 0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              icon,
              style: const TextStyle(fontSize: 32),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Playful leaderboard row for top 3
class _PlayfulLeaderboardRow extends StatelessWidget {
  final int rank;
  final String nickname;
  final int correct;
  final int index;

  const _PlayfulLeaderboardRow({
    required this.rank,
    required this.nickname,
    required this.correct,
    required this.index,
  });

  String _getMedalEmoji() {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  Color _getMedalColor() {
    switch (rank) {
      case 1:
        return Colors.amber[600]!;
      case 2:
        return Colors.grey[500]!;
      case 3:
        return Colors.orange[700]!;
      default:
        return Colors.grey[400]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _getMedalColor().withValues(alpha: 0.15),
              _getMedalColor().withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getMedalColor().withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Medal
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _getMedalColor(),
                    _getMedalColor().withValues(alpha: 0.6),
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  _getMedalEmoji(),
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Name and Score
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nickname,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Peringkat #$rank',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Correct count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[400],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '✅ $correct',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
