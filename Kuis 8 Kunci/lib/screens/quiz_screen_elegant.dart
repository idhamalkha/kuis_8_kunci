/// Quiz Screen - Elegant & Clean Design for Kids
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:async';
import 'package:provider/provider.dart';

import '../providers/quiz_provider.dart';
import 'results_screen_elegant.dart';

class QuizScreenElegant extends StatefulWidget {
  const QuizScreenElegant({super.key});

  @override
  State<QuizScreenElegant> createState() => _QuizScreenElegantState();
}

class _QuizScreenElegantState extends State<QuizScreenElegant>
    with TickerProviderStateMixin {
  late Future<void> _loadQuiz;
  String? _selectedAnswer;
  late DateTime _questionStartTime;
  Timer? _questionTimer;
  int _timeRemaining = 0;
  int _observedQuestionNumber = 0;
  bool _isSubmitting = false;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _loadQuiz = _initQuiz();
    _questionStartTime = DateTime.now();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
  }

  Future<void> _initQuiz() async {
    final provider = context.read<QuizProvider>();
    await provider.startQuiz();
  }

  Future<void> _showElegantFeedback(bool isCorrect) async {
    if (isCorrect) {
      _confettiController.play();
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ElegantFeedbackDialog(
        isCorrect: isCorrect,
        onContinue: () {
          Navigator.pop(context);
          _continueToNextQuestion(isCorrect);
        },
      ),
    );
  }

  Future<void> _continueToNextQuestion(bool isCorrect) async {
    final provider = context.read<QuizProvider>();

    if (isCorrect) {
      if (provider.currentQuestionNumber >= provider.totalQuestions) {
        provider.finishQuiz();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ResultsScreenElegant()),
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
      if (mounted) {
        setState(() {
          _selectedAnswer = null;
          _questionStartTime = DateTime.now();
        });
      }
    }
  }

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
        await _showElegantFeedback(correct);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

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
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          FutureBuilder<void>(
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

                  return SafeArea(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // === TOP BAR: Progress & Score ===
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Back Button
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.arrow_back_ios_new,
                                      size: 18,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),

                                // Question Counter
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'Soal ${provider.currentQuestionNumber}/${provider.totalQuestions}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),

                                // Score Badge
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.amber[400]!,
                                        Colors.amber[300]!,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${provider.totalCorrect}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // === PROGRESS BAR ===
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blue[600]!,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // === TIMER ===
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
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 24,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Waktu Tersisa',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _timeRemaining <= 5
                                          ? Colors.red[50]
                                          : Colors.blue[50],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$_timeRemaining detik',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _timeRemaining <= 5
                                            ? Colors.red[600]
                                            : Colors.blue[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            // === QUESTION CARD ===
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
                                question.questionText,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[900],
                                  height: 1.6,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // === OPTIONS ===
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: options.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final optionLetter =
                                    String.fromCharCode(65 + index);
                                final isSelected =
                                    _selectedAnswer == optionLetter;

                                return ElegantOptionButton(
                                  letter: optionLetter,
                                  text: options[index],
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() =>
                                        _selectedAnswer = optionLetter);
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 32),

                            // === SUBMIT BUTTON ===
                            ElevatedButton(
                              onPressed: _selectedAnswer == null || _isSubmitting
                                  ? null
                                  : _submitAnswer,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                disabledBackgroundColor: Colors.grey[300],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: _selectedAnswer == null ? 0 : 4,
                              ),
                              child: Text(
                                _isSubmitting ? 'Mengirim...' : 'Kirim Jawaban',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: -3.14 / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 40,
              gravity: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}

/// Elegant Option Button
class ElegantOptionButton extends StatefulWidget {
  final String letter;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const ElegantOptionButton({
    super.key,
    required this.letter,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<ElegantOptionButton> createState() => _ElegantOptionButtonState();
}

class _ElegantOptionButtonState extends State<ElegantOptionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(ElegantOptionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward();
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.02).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected ? Colors.blue[600]! : Colors.grey[300]!,
              width: widget.isSelected ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? Colors.blue.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          child: Row(
            children: [
              // Letter Badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.isSelected ? Colors.blue[600] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    widget.letter,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color:
                          widget.isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Option Text
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Check Icon
              if (widget.isSelected) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.blue[600],
                  size: 24,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Elegant Feedback Dialog
class ElegantFeedbackDialog extends StatefulWidget {
  final bool isCorrect;
  final VoidCallback onContinue;

  const ElegantFeedbackDialog({
    super.key,
    required this.isCorrect,
    required this.onContinue,
  });

  @override
  State<ElegantFeedbackDialog> createState() => _ElegantFeedbackDialogState();
}

class _ElegantFeedbackDialogState extends State<ElegantFeedbackDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Text(
                widget.isCorrect ? '✅' : '🤔',
                style: const TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                widget.isCorrect ? 'Jawaban Benar!' : 'Coba Lagi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: widget.isCorrect
                      ? Colors.green[700]
                      : Colors.amber[700],
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                widget.isCorrect
                    ? 'Lanjut ke soal berikutnya'
                    : 'Pilih jawaban lain dan coba lagi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isCorrect
                        ? Colors.green[600]
                        : Colors.amber[600],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    widget.isCorrect ? 'Lanjut' : 'Coba Lagi',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
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
