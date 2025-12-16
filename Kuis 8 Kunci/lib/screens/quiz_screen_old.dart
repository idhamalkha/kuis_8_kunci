/// Quiz Screen - Interactive with Modal Feedback
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';

import '../providers/quiz_provider.dart';
import 'results_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late Future<void> _loadQuiz;
  String? _selectedAnswer;
  late DateTime _questionStartTime;
  Timer? _questionTimer;
  int _timeRemaining = 0;
  int _observedQuestionNumber = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadQuiz = _initQuiz();
    _questionStartTime = DateTime.now();
  }

  Future<void> _initQuiz() async {
    final provider = context.read<QuizProvider>();
    await provider.startQuiz();
  }

  /// Show modal dialog untuk feedback (benar/salah)
  Future<void> _showFeedbackModal(bool isCorrect, String message) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AnimatedDialog(
        isCorrect: isCorrect,
        message: message,
        onContinue: () {
          Navigator.pop(context); // Close dialog
          _continueToNextQuestion(isCorrect);
        },
      ),
    );
  }

  /// Continue ke soal berikutnya atau hasil
  Future<void> _continueToNextQuestion(bool isCorrect) async {
    final provider = context.read<QuizProvider>();

    if (isCorrect) {
      if (provider.currentQuestionNumber >= provider.totalQuestions) {
        provider.finishQuiz();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ResultsScreen()),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _selectedAnswer = null;
            _questionStartTime = DateTime.now();
          });
          await provider.loadQuestion(provider.currentQuestionNumber + 1);
        }
      }
    } else {
      // Wrong answer: reset selection, stay on same question
      if (mounted) {
        setState(() {
          _selectedAnswer = null;
          _questionStartTime = DateTime.now();
        });
      }
    }
  }

  /// Submit answer dengan modal feedback
  Future<void> _submitAnswer() async {
    if (_selectedAnswer == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    _questionTimer?.cancel();

    final provider = context.read<QuizProvider>();
    final timeTaken = DateTime.now().difference(_questionStartTime).inSeconds;

    try {
      final correct = await provider.submitAnswer(
        selectedAnswer: _selectedAnswer,
        timeTaken: timeTaken,
      );

      if (mounted) {
        final message = correct ? 'Jawaban Benar! 🎉' : 'Coba Lagi! 💪';
        await _showFeedbackModal(correct, message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Auto-submit saat timer habis
  void _onTimeUp() {
    if (_selectedAnswer != null && !_isSubmitting) {
      _submitAnswer();
    }
  }

  void _startQuestionTimer(int timeLimit, int questionNumber) {
    _questionTimer?.cancel();
    _timeRemaining = timeLimit;
    _observedQuestionNumber = questionNumber;
    _questionStartTime = DateTime.now();

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsed = DateTime.now().difference(_questionStartTime).inSeconds;
      final remaining = timeLimit - elapsed;

      if (remaining <= 0) {
        timer.cancel();
        if (mounted && !_isSubmitting) {
          _onTimeUp();
        }
      } else {
        if (mounted) setState(() => _timeRemaining = remaining);
      }
    });
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _loadQuiz,
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
                  const Text('Ada masalah saat memuat kuis'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Kembali'),
                  ),
                ],
              ),
            );
          }

          return Consumer<QuizProvider>(
            builder: (context, provider, _) {
              final question = provider.currentQuestion;
              if (question == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final options = question.getOptions();
              final progress = provider.currentQuestionNumber / provider.totalQuestions;

              if (provider.currentQuestionNumber != _observedQuestionNumber) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _startQuestionTimer(provider.timeLimit, provider.currentQuestionNumber);
                });
              }

              return Stack(
                children: [
                  // Background
                  Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/tema/tree/TreeBG.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),

                  // Main Content
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ===== PROGRESS CARD =====
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[700]!, Colors.blue[600]!],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Soal ${provider.currentQuestionNumber}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.amber[300],
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${provider.totalCorrect} ✓',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber[900],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 10,
                                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.green[300]!,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Soal ${provider.currentQuestionNumber}/${provider.totalQuestions}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ===== TIMER CARD (LARGE) =====
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _timeRemaining <= 5
                                    ? [Colors.red[600]!, Colors.red[700]!]
                                    : [Colors.green[600]!, Colors.teal[600]!],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Text(
                                  'Waktu Tersisa',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '$_timeRemaining',
                                  style: const TextStyle(
                                    fontSize: 56,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'detik',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ===== QUESTION CARD =====
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.98),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Pertanyaan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[600],
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  question.questionText,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[800],
                                    height: 1.5,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ===== OPTIONS GRID =====
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final optionLetter = String.fromCharCode(65 + index);
                              final isSelected = _selectedAnswer == optionLetter;

                              return OptionButton(
                                key: ValueKey('option_$optionLetter'),
                                letter: optionLetter,
                                text: options[index],
                                isSelected: isSelected,
                                onTap: () {
                                  setState(() => _selectedAnswer = optionLetter);
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 24),

                          // ===== SUBMIT BUTTON =====
                          ElevatedButton(
                            onPressed: _selectedAnswer == null || _isSubmitting
                                ? null
                                : _submitAnswer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedAnswer == null
                                  ? Colors.grey[400]
                                  : Colors.green[600],
                              disabledBackgroundColor: Colors.grey[400],
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 8,
                            ),
                            child: Text(
                              _isSubmitting ? 'Mengirim...' : 'Kirim Jawaban',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Back Button
                  Positioned(
                    top: 20,
                    left: 16,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.blue[700],
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Tombol Option yang bisa dipilih
class OptionButton extends StatelessWidget {
  final String letter;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const OptionButton({
    super.key,
    required this.letter,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[50] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.green[600]! : Colors.grey[300]!,
            width: isSelected ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Letter Badge
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected
                    ? LinearGradient(
                        colors: [Colors.green[600]!, Colors.teal[400]!],
                      )
                    : LinearGradient(
                        colors: [Colors.blue[400]!, Colors.blue[300]!],
                      ),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal Dialog dengan Animasi untuk Feedback
class AnimatedDialog extends StatefulWidget {
  final bool isCorrect;
  final String message;
  final VoidCallback onContinue;

  const AnimatedDialog({
    super.key,
    required this.isCorrect,
    required this.message,
    required this.onContinue,
  });

  @override
  State<AnimatedDialog> createState() => _AnimatedDialogState();
}

class _AnimatedDialogState extends State<AnimatedDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon dengan bounce animation
              ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.2).animate(
                  CurvedAnimation(parent: _bounceController, curve: Curves.elasticInOut),
                ),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isCorrect
                        ? Colors.green[100]
                        : Colors.orange[100],
                  ),
                  child: Icon(
                    widget.isCorrect ? Icons.check_circle : Icons.info,
                    size: 50,
                    color: widget.isCorrect ? Colors.green[600] : Colors.orange[600],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Message
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: widget.isCorrect ? Colors.green[800] : Colors.orange[800],
                ),
              ),
              const SizedBox(height: 12),

              // Sub-message
              Text(
                widget.isCorrect
                    ? 'Lanjut ke soal berikutnya!'
                    : 'Pilih jawaban lain dan coba lagi!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Continue Button
              ElevatedButton(
                onPressed: widget.onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isCorrect
                      ? Colors.green[600]
                      : Colors.orange[600],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  widget.isCorrect ? 'Lanjut Soal' : 'Coba Lagi',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
