import 'package:flutter/material.dart';

class AnswerFeedback extends StatelessWidget {
  final bool correct;
  final String message;

  const AnswerFeedback({super.key, required this.correct, required this.message});

  @override
  Widget build(BuildContext context) {
    final primary = (correct ? Colors.green[600] : Colors.orange[600])!;
    final bg = primary.withValues(alpha: 0.12);
    final borderColor = primary.withValues(alpha: 0.2);
    final icon = correct ? Icons.emoji_events : Icons.lightbulb_outline;
    final textColor = (correct ? Colors.green[800] : Colors.orange[800])!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
