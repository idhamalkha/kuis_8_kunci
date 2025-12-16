import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../widgets/answer_feedback.dart';
// removed unused ByteData import
import 'package:provider/provider.dart';

import '../providers/quiz_provider.dart';
import 'results_screen.dart';

enum AnswerResult { none, correct, wrong }

class QuizScreenGamified extends StatefulWidget {
  const QuizScreenGamified({super.key});

  @override
  State<QuizScreenGamified> createState() => _QuizScreenGamifiedState();
}

class _QuizScreenGamifiedState extends State<QuizScreenGamified>
    with TickerProviderStateMixin {
  late Future<void> _loadQuiz;
  String? _selectedAnswer;
  late DateTime _questionStartTime;
  Timer? _questionTimer;
  int _timeRemaining = 0;
  int _observedQuestionNumber = 0;
  bool _isSubmitting = false;
  late ConfettiController _confettiController;
  // recent answer tracking removed (unused) — keep state minimal

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

  Future<void> _onTimeUp() async {
    // When time is up we submit the current selected answer (if any)
    // but if player didn't select, show a small feedback dialog showing correct answer.
    final hadSelection = _selectedAnswer != null;
    bool correct = false;
    if (hadSelection && !_isSubmitting) {
      // If player selected an option but time ran out, submit as final
      // to get authoritative correctness and the correct answer, then
      // show feedback dialog so the child sees the result.
      setState(() => _isSubmitting = true);
      try {
        final provider = context.read<QuizProvider>();
        final response = await provider.submitAnswerRaw(
          selectedAnswer: _selectedAnswer,
          timeTaken: DateTime.now().difference(_questionStartTime).inSeconds,
          isFinal: true,
        );

        correct = response.isCorrect;

        // Map correct letter to option text if available
        String correctLetter = response.correctAnswer;
        String? correctText;
        final q = provider.currentQuestion;
        if (q != null) {
          switch (correctLetter.toUpperCase()) {
            case 'A':
              correctText = q.optionA;
              break;
            case 'B':
              correctText = q.optionB;
              break;
            case 'C':
              correctText = q.optionC;
              break;
            case 'D':
              correctText = q.optionD;
              break;
            default:
              correctText = null;
          }
        }

        final message = correct
            ? 'Sangat Bagus! 🎉'
            : (correctText != null
                ? 'Waktu habis! Jawaban benar: $correctLetter — $correctText'
                : 'Waktu habis! Jawaban benar: $correctLetter');

        if (mounted) {
          // micro-delay so the UI shows a short loading/lock state before popup
          await Future.delayed(const Duration(milliseconds: 350));
          if (correct) {
            HapticFeedback.mediumImpact();
          } else {
            HapticFeedback.lightImpact();
          }
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (context) => GameifiedFeedbackDialog(
              isCorrect: correct,
              message: message,
              onContinue: () {
                Navigator.pop(context);
              },
            ),
          );
        }

        await _continueToNextQuestion(correct);
        return;
      } catch (e) {
        // fallback: try the non-final submit flow and continue
        try {
          correct = await _submitAnswer(showFeedback: false);
          await _continueToNextQuestion(correct);
          return;
        } catch (_) {
          await _continueToNextQuestion(false);
          return;
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }

    // No selection: call server to get authoritative correct answer and preview,
    // then show a single dialog with the authoritative result. If the server
    // call fails, fallback to a simple timeout message.
    try {
      final provider = context.read<QuizProvider>();
      final response = await provider.submitAnswerRaw(
        selectedAnswer: null,
        timeTaken: DateTime.now().difference(_questionStartTime).inSeconds,
        isFinal: true,
      );

      // Map correct letter to option text if available
      String correctLetter = response.correctAnswer;
      String? correctText;
      final q = provider.currentQuestion;
      if (q != null) {
        switch (correctLetter.toUpperCase()) {
          case 'A':
            correctText = q.optionA;
            break;
          case 'B':
            correctText = q.optionB;
            break;
          case 'C':
            correctText = q.optionC;
            break;
          case 'D':
            correctText = q.optionD;
            break;
          default:
            correctText = null;
        }
      }

      final message = correctText != null
          ? 'Waktu habis! Jawaban benar: $correctLetter — $correctText'
          : 'Waktu habis! Jawaban benar: $correctLetter';

      if (mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => GameifiedFeedbackDialog(
            isCorrect: false,
            message: message,
            onContinue: () {
              Navigator.pop(context);
            },
          ),
        );
      }

      // proceed using server's correctness (should be false when selectedAnswer==null)
      await _continueToNextQuestion(response.isCorrect);
      return;
    } catch (e) {
      // fallback: show generic message and continue
      final message = 'Waktu habis!';
      if (mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (context) => GameifiedFeedbackDialog(
            isCorrect: false,
            message: message,
            onContinue: () => Navigator.pop(context),
          ),
        );
      }
      await _continueToNextQuestion(false);
      return;
    }
  }

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
      if (mounted) {
        setState(() {
          _selectedAnswer = null;
          _questionStartTime = DateTime.now();
        });
      }
    }
  }

  /// Submit current selection. If [showFeedback] is false the UI feedback
  /// (dialogs/snackbars) will be suppressed — useful when called from the
  /// timer expiry handler which then decides how to proceed.
  Future<bool> _submitAnswer({bool showFeedback = true}) async {
    if (_selectedAnswer == null || _isSubmitting) return false;

    setState(() => _isSubmitting = true);

    final provider = context.read<QuizProvider>();
    final timeTaken = DateTime.now().difference(_questionStartTime).inSeconds;

    try {
      final response = await provider.submitAnswerRaw(
        selectedAnswer: _selectedAnswer,
        timeTaken: timeTaken,
        isFinal: !showFeedback,
      );
      final correct = response.isCorrect;
      // Keep the selected option highlighted but avoid unused transient fields.

      if (correct) {
        // Stop timer only when answer is correct so competition rewards
        // the fastest correct responders. Also play confetti.
        _questionTimer?.cancel();
        _confettiController.play();
      }

      if (showFeedback && mounted) {
        final message = correct ? 'Keren... Kamu Menjawab dengan Benar 🎉' : 'Jawaban Kamu Salah... Yuk coba lagi! 💪';

        // Short pause to create a clear submit -> result transition,
        // keeping options disabled while showing a small loading feeling.
        await Future.delayed(const Duration(milliseconds: 350));
        if (correct) {
          HapticFeedback.mediumImpact();
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (context) => GameifiedFeedbackDialog(
              isCorrect: true,
              message: message,
              onContinue: () async {
                Navigator.pop(context);
                await _continueToNextQuestion(true);
              },
            ),
          );
        } else {
          HapticFeedback.lightImpact();
          // Show the same playful dialog for wrong attempts but do not advance
          // to the next question — allow the child to try again while timer
          // continues. The dialog is dismissible.
          if (mounted) {
            await showDialog<void>(
              context: context,
              barrierDismissible: true,
              builder: (context) => GameifiedFeedbackDialog(
                isCorrect: false,
                message: message,
                onContinue: () {
                  Navigator.pop(context);
                },
              ),
            );
          }
        }
      }

      // If showFeedback was false (called from _onTimeUp) we return the
      // correctness flag for the caller to decide next steps.
      return correct;
    } catch (e) {
      return false;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;
    final contentWidth = math.min(900.0, screenWidth * 0.96);
    final basePadding = math.max(12.0, screenWidth * 0.03);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // Softer background gradient to reduce visual noise
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF6F5FB), // very light purple/cream
              Color(0xFFFAF8FF),
            ],
          ),
        ),
        child: Stack(
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
                        const Text('Error loading quiz',
                            style: TextStyle(fontSize: 18)),
                        const SizedBox(height: 12),
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
                    final q = provider.currentQuestion;
                    if (q == null) {
                      return const Center(
                        child: Text('Tidak ada soal'),
                      );
                    }

                    // Start timer only when question changes to avoid restarting
                    // the timer on every build (which freezes the countdown).
                    if (_observedQuestionNumber != provider.currentQuestionNumber) {
                      _startQuestionTimer(
                        provider.timeLimit,
                        provider.currentQuestionNumber,
                      );
                    }

                    final opts = q.getOptions();
                    final progress = provider.currentQuestionNumber /
                        provider.totalQuestions;

                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: contentWidth),
                        child: Padding(
                          // add extra bottom padding so the submit button isn't flush with screen edge
                          padding: EdgeInsets.fromLTRB(basePadding, basePadding, basePadding, basePadding + 12),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Header with Hero for smooth transitions
                                Hero(
                            tag: 'quiz-header',
                            child: Material(
                              color: Colors.transparent,
                              child: GamifiedHeaderCard(
                                currentQuestion:
                                    provider.currentQuestionNumber,
                                totalQuestions: provider.totalQuestions,
                                correctAnswers: provider.totalCorrect,
                                progress: progress,
                                timeRemaining: _timeRemaining,
                              ),
                            ),
                          ),
                          SizedBox(height: math.max(12, screenHeight * 0.02)),

                          // Timer
                          PlayfulTimerCard(
                            timeRemaining: _timeRemaining,
                          ),
                          SizedBox(height: math.max(10, screenHeight * 0.02)),

                          // Question + options block - smooth transitions between questions
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                            child: Column(
                              key: ValueKey(provider.currentQuestionNumber),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                GamifiedQuestionCard(
                                  questionText: q.questionText,
                                ),
                                SizedBox(height: math.max(12, screenHeight * 0.02)),

                                // Wrap options in a constrained scrollable area so long option lists
                                // don't blow up the layout while keeping the whole screen scrollable.
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxHeight: screenHeight * 0.64),
                                  child: SingleChildScrollView(
                                    key: ValueKey('opts-scroll-${provider.currentQuestionNumber}'),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        ...List<Widget>.generate(opts.length, (i) {
                                          final letter = String.fromCharCode(65 + i);
                                          final optId = letter;
                                          final optText = opts[i];
                                          final isSelected = _selectedAnswer == optId;

                                          return Padding(
                                            padding: EdgeInsets.symmetric(horizontal: math.max(8, screenWidth * 0.03)),
                                            child: Column(
                                              children: [
                                                AnimatedOptionButton(
                                                  index: i,
                                                  letter: letter,
                                                  text: optText,
                                                  isSelected: isSelected,
                                                  isSubmitting: _isSubmitting,
                                                  onTap: _isSubmitting
                                                      ? () {}
                                                      : () {
                                                          setState(() => _selectedAnswer = optId);
                                                        },
                                                ),
                                                if (i < opts.length - 1) SizedBox(height: math.max(10, screenHeight * 0.015)),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          GamifiedSubmitButton(
                            isEnabled: _selectedAnswer != null,
                            isLoading: _isSubmitting,
                            onPressed: _submitAnswer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ));
              }, // end Consumer builder
            ); // end Consumer
          }, // end FutureBuilder builder
        ), // end FutureBuilder
            if (_isSubmitting)
              Positioned.fill(
                child: AbsorbPointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: 0.06,
                    child: Container(color: Colors.black.withAlpha((0.06 * 255).round())),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: -3.14 / 2,
                emissionFrequency: 0.05,
                numberOfParticles: 50,
                gravity: 0.15,
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Future<bool> _onWillPop() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari kuis?'),
        content: const Text('Progress jawaban saat ini akan hilang. Yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              // stop active timers/animations to avoid leaks
              _questionTimer?.cancel();
              try {
                _confettiController.stop();
              } catch (_) {}
              Navigator.of(context).pop(true);
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    return shouldExit ?? false;
  }
}

/// Header Card dengan Progress dan Score
class GamifiedHeaderCard extends StatefulWidget {
  final int currentQuestion;
  final int totalQuestions;
  final int correctAnswers;
  final double progress;
  final int timeRemaining;

  const GamifiedHeaderCard({
    super.key,
    required this.currentQuestion,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.progress,
    required this.timeRemaining,
  });

  @override
  State<GamifiedHeaderCard> createState() => _GamifiedHeaderCardState();
}

class _GamifiedHeaderCardState extends State<GamifiedHeaderCard> {
  double _prevProgress = 0.0;

  @override
  void didUpdateWidget(covariant GamifiedHeaderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _prevProgress = oldWidget.progress.clamp(0.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Soal',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.currentQuestion}/${widget.totalQuestions}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[800],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber[300],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Text('⭐'),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.correctAnswers}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: _prevProgress, end: widget.progress.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 600),
              builder: (context, val, _) {
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 12,
                      color: Colors.grey[200],
                    ),
                    FractionallySizedBox(
                      widthFactor: val.clamp(0.0, 1.0),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.purple[400]!, Colors.blue[300]!]),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (MediaQuery.of(context).size.width - 32 - 24) * val.clamp(0.0, 1.0),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.yellow[600],
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4)],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Soal ${widget.currentQuestion} dari ${widget.totalQuestions}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.purple[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Playful Timer Card
class PlayfulTimerCard extends StatefulWidget {
  final int timeRemaining;

  const PlayfulTimerCard({
    super.key,
    required this.timeRemaining,
  });

  @override
  State<PlayfulTimerCard> createState() => _PlayfulTimerCardState();
}

class _PlayfulTimerCardState extends State<PlayfulTimerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void didUpdateWidget(covariant PlayfulTimerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasLow = oldWidget.timeRemaining <= 5;
    final isLow = widget.timeRemaining <= 5;
    if (isLow && !wasLow) {
      _pulseController.repeat(reverse: true);
    } else if (!isLow && wasLow) {
      _pulseController.stop();
      _pulseController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLowTime = widget.timeRemaining <= 5;
    final baseColor = isLowTime ? Colors.orange[100] : Colors.blue[50];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Waktu Tersisa',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
                   Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Transform.rotate(
                         angle: _pulseController.value * 0.6,
                         child: Icon(
                           Icons.timer,
                           color: isLowTime ? Colors.orange[800] : Colors.blue[800],
                           size: 20,
                         ),
                       ),
                       const SizedBox(width: 8),
                       AnimatedBuilder(
                         animation: _pulseController,
                         builder: (context, child) {
                           final scale = 1.0 + (_pulseController.value * 0.06);
                           return Transform.scale(
                             scale: scale,
                             child: Text(
                               '${widget.timeRemaining} s',
                               style: TextStyle(
                                 fontSize: 28,
                                 fontWeight: FontWeight.bold,
                                 color: isLowTime ? Colors.orange[800] : Colors.blue[800],
                               ),
                             ),
                           );
                         },
                       ),
                     ],
                   ),
            ],
          ),
          // Circular progress around clock icon
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: widget.timeRemaining > 0 ? (widget.timeRemaining / 30).clamp(0.0, 1.0) : 0.0,
                  strokeWidth: 6,
                  valueColor: AlwaysStoppedAnimation<Color>(isLowTime ? Colors.orange[600]! : Colors.blue[400]!),
                  backgroundColor: Colors.grey[200],
                ),
                Icon(
                  Icons.access_time,
                  color: isLowTime ? Colors.orange[700] : Colors.blue[700],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Question Card
class GamifiedQuestionCard extends StatelessWidget {
  final String questionText;

  const GamifiedQuestionCard({
    super.key,
    required this.questionText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, color: Colors.purple[300], size: 18),
              const SizedBox(width: 8),
              Text(
                'Pertanyaan',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            questionText,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated Option Button dengan Hover Effect
class AnimatedOptionButton extends StatefulWidget {
  final int index;
  final String letter;
  final String text;
  final bool isSelected;
  final bool isSubmitting;
  final VoidCallback onTap;

  const AnimatedOptionButton({
    super.key,
    required this.index,
    required this.letter,
    required this.text,
    required this.isSelected,
    required this.isSubmitting,
    required this.onTap,
  });

  @override
  State<AnimatedOptionButton> createState() => _AnimatedOptionButtonState();
}

class _AnimatedOptionButtonState extends State<AnimatedOptionButton>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _entranceScale;
  late final AnimationController _selectController;
  late final Animation<double> _selectScale;
  late final AnimationController _submitController;
  late final Animation<double> _submitScale;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _entranceScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );

    _selectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _selectScale = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _selectController, curve: Curves.easeInOut),
    );

    _submitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _submitScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _submitController, curve: Curves.easeOutBack),
    );

    Future.delayed(Duration(milliseconds: 70 * widget.index), () {
      if (mounted) _entranceController.forward();
    });
  }

  bool _hovering = false;

  @override
  void didUpdateWidget(covariant AnimatedOptionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _selectController.forward();
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _selectController.reverse();
    }

    // Trigger a short submit bounce when the parent indicates submitting
    if (widget.isSubmitting && widget.isSelected && !oldWidget.isSubmitting) {
      _submitController.forward().then((_) => _submitController.reverse());
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _selectController.dispose();
    _submitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entranceController,
      child: ScaleTransition(
        scale: _entranceScale,
        child: ScaleTransition(
          scale: _selectScale,
          child: ScaleTransition(
            scale: _submitScale,
            child: MouseRegion(
              onEnter: (_) => setState(() => _hovering = true),
              onExit: (_) => setState(() => _hovering = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                transform: Matrix4.translationValues(0.0, _hovering ? -4.0 : 0.0, 0.0),
                decoration: BoxDecoration(
                  color: widget.isSelected ? Colors.purple[400] : Colors.blue[100],
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(((_hovering ? 0.09 : 0.06) * 255).round()),
                      blurRadius: (_hovering ? 14 : 10) + (widget.isSubmitting && widget.isSelected ? 6 : 0),
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: widget.isSelected ? Border.all(color: Colors.yellow[600]!, width: 2) : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: widget.isSubmitting ? null : widget.onTap,
                    borderRadius: BorderRadius.circular(16),
                    splashColor: Colors.white24,
                    highlightColor: Colors.white12,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha((0.06 * 255).round()),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                widget.letter,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isSelected ? Colors.purple[700] : Colors.blue[800],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              widget.text,
                              style: TextStyle(
                                color: widget.isSelected ? Colors.white : Colors.grey[900],
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gamified Submit Button
class GamifiedSubmitButton extends StatelessWidget {
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onPressed;

  const GamifiedSubmitButton({
    super.key,
    required this.isEnabled,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: isEnabled
            ? LinearGradient(
                colors: [Colors.purple[600]!, Colors.blue[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [Colors.grey[350]!, Colors.grey[300]!],
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                          color: Colors.purple.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled && !isLoading ? onPressed : null,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Mengirim…',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Kirim Jawaban',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gamified Feedback Dialog
class GameifiedFeedbackDialog extends StatefulWidget {
  final bool isCorrect;
  final String message;
  final VoidCallback onContinue;

  const GameifiedFeedbackDialog({
    super.key,
    required this.isCorrect,
    required this.message,
    required this.onContinue,
  });

  @override
  State<GameifiedFeedbackDialog> createState() =>
      _GameifiedFeedbackDialogState();
}

class _GameifiedFeedbackDialogState extends State<GameifiedFeedbackDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _iconController;
  bool _canContinue = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);

    // Provide subtle haptic feedback to reinforce the result
    // correct -> medium impact, wrong/timeout -> light impact
    if (widget.isCorrect) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    // Small delay before allowing user to continue to give moment for animation
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _canContinue = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Keep didChangeDependencies minimal; icon controller handles looping.
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _iconController.dispose();
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
            gradient: widget.isCorrect
                ? LinearGradient(
                    colors: [Colors.green[400]!, Colors.teal[300]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [Colors.orange[400]!, Colors.amber[300]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 140,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Always-visible icon backdrop
                      Icon(
                        widget.isCorrect ? Icons.celebration : Icons.timer_off,
                        color: Colors.white.withAlpha((0.28 * 255).round()),
                        size: 100,
                      ),
                      // Looping animated icon (only icon pulses)
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.9, end: 1.08).animate(
                          CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
                        ),
                        child: Icon(
                          widget.isCorrect ? Icons.celebration : Icons.timer_off,
                          color: Colors.white,
                          size: 90,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Use the shared AnswerFeedback widget for consistent visuals
              AnswerFeedback(correct: widget.isCorrect, message: widget.message),
              const SizedBox(height: 24),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _canContinue ? 1.0 : 0.6,
                child: GestureDetector(
                  onTap: _canContinue ? widget.onContinue : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        if (_canContinue)
                          BoxShadow(
                            color: Colors.black.withAlpha((0.12 * 255).round()),
                            blurRadius: 8,
                            offset: const Offset(0, 6),
                          ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isCorrect ? Icons.check_circle : Icons.refresh,
                          color: widget.isCorrect ? Colors.green[600] : Colors.orange[600],
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.isCorrect ? 'Lanjut' : 'Coba Lagi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: widget.isCorrect ? Colors.green[600] : Colors.orange[600],
                          ),
                        ),
                      ],
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
