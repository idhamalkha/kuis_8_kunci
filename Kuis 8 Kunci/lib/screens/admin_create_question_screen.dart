/// Admin Create Question Screen - Add new quiz questions
import 'package:flutter/material.dart';

import '../services/supabase_direct_service.dart';

class AdminCreateQuestionScreen extends StatefulWidget {
  const AdminCreateQuestionScreen({super.key});

  @override
  State<AdminCreateQuestionScreen> createState() =>
      _AdminCreateQuestionScreenState();
}

class _AdminCreateQuestionScreenState extends State<AdminCreateQuestionScreen> {
  final _questionController = TextEditingController();
  final _optionControllers = List.generate(4, (_) => TextEditingController());

  String? _selectedDifficulty;
  int _correctAnswerIndex = 0;
  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;

  List<dynamic> _subjects = [];
  final Map<int, List<dynamic>> _questionSets = {};
  int? _selectedSubjectId;
  int? _selectedSetId;
  bool _loadingSubjects = true;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final subjects = await SupabaseDirectService.getSubjects();
      if (mounted) {
        setState(() {
          _subjects = subjects;
          _loadingSubjects = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load subjects';
          _loadingSubjects = false;
        });
      }
    }
  }

  Future<void> _loadQuestionSets(int subjectId) async {
    try {
      final detail = await SupabaseDirectService.getSubjectDetail(subjectId);
      if (mounted) {
        setState(() {
          _questionSets[subjectId] = detail['question_sets'] ?? [];
          _selectedSetId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _errorMessage = 'Failed to load question sets');
      }
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submitQuestion() async {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((controller) => controller.text.trim())
        .toList();

    // Validation
    if (_selectedSubjectId == null) {
      setState(() => _errorMessage = 'Please select a subject');
      return;
    }

    if (_selectedSetId == null) {
      setState(() => _errorMessage = 'Please select a question set');
      return;
    }

    if (question.isEmpty) {
      setState(() => _errorMessage = 'Please enter a question');
      return;
    }

    if (options.any((option) => option.isEmpty)) {
      setState(() => _errorMessage = 'Please fill all options');
      return;
    }

    if (_selectedDifficulty == null) {
      setState(() => _errorMessage = 'Please select difficulty level');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final correctAnswer = ['A', 'B', 'C', 'D'][_correctAnswerIndex];
      await SupabaseDirectService.createQuestion(
        questionText: question,
        optionA: options[0],
        optionB: options[1],
        optionC: options[2],
        optionD: options[3],
        correctAnswer: correctAnswer,
        difficulty: _selectedDifficulty!,
        setId: _selectedSetId,
      );

      if (mounted) {
        setState(() {
          _successMessage = 'Question created successfully!';
          _questionController.clear();
          for (var controller in _optionControllers) {
            controller.clear();
          }
          _selectedDifficulty = null;
          _correctAnswerIndex = 0;
        });

        // Clear message after 3 seconds
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          setState(() => _successMessage = null);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _errorMessage = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),

          // Header Card with Gradient
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
                  color: Colors.purple.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit_note,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create New Question',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add questions to your question sets',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Loading or Subject Selection
          if (_loadingSubjects)
            const Center(child: CircularProgressIndicator())
          else if (_subjects.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[300]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No subjects available. Please create a subject first.',
                      style: TextStyle(color: Colors.orange[700], fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Subject Selection
                Text(
                  'Subject',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedSubjectId,
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedSubjectId = value);
                              _loadQuestionSets(value);
                            }
                          },
                    items: _subjects
                        .map<DropdownMenuItem<int>>((subject) {
                          final subjectId = subject['subject_id'] is int
                              ? subject['subject_id']
                              : int.tryParse(subject['subject_id'].toString()) ?? 0;
                          return DropdownMenuItem<int>(
                            value: subjectId,
                            child: Text(subject['subject_name'] ?? 'Unknown'),
                          );
                        })
                        .toList(),
                    decoration: InputDecoration(
                      hintText: 'Select a subject',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.subject, color: Colors.purple[600]),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Question Set Selection
                if (_selectedSubjectId != null) ...[
                  Text(
                    'Question Set',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedSetId,
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              setState(() => _selectedSetId = value);
                            },
                      items: (_questionSets[_selectedSubjectId] ?? [])
                          .map<DropdownMenuItem<int>>((set) {
                            final setId = set['set_id'] is int
                                ? set['set_id']
                                : int.tryParse(set['set_id'].toString()) ?? 0;
                            final setName = set['set_name'] ?? 'Unknown';
                            final totalQuestions = set['total_questions'] ?? 0;
                            return DropdownMenuItem<int>(
                              value: setId,
                              child: Text(
                                  '$setName ($totalQuestions questions)'),
                            );
                          })
                          .toList(),
                      decoration: InputDecoration(
                        hintText: 'Select a question set',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.folder_open, color: Colors.purple[600]),
                      ),
                    ),
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_forward_ios, 
                          size: 16,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Please select a subject first',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

          if (!_loadingSubjects &&
              _subjects.isNotEmpty &&
              _selectedSetId == null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber[200]!, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.amber[700], size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select both subject and question set to continue',
                        style: TextStyle(
                          color: Colors.amber[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (!_loadingSubjects &&
              _subjects.isNotEmpty &&
              _selectedSetId != null)
            const SizedBox(height: 28),

          // Question Input (only show if set is selected)
          if (_selectedSetId != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Question Text Input
                Text(
                  'Question Text',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: TextField(
                    controller: _questionController,
                    decoration: InputDecoration(
                      hintText: 'Enter the quiz question',
                      contentPadding: const EdgeInsets.all(16),
                      border: InputBorder.none,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(
                          top: 12,
                          left: 12,
                          right: 8,
                        ),
                        child: Icon(Icons.help_outline, color: Colors.purple[600]),
                      ),
                      prefixIconConstraints: const BoxConstraints(maxHeight: 48),
                    ),
                    maxLines: 3,
                    enabled: !_isLoading,
                  ),
                ),
                const SizedBox(height: 20),

                // Difficulty Dropdown
                Text(
                  'Difficulty Level',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedDifficulty,
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            setState(() => _selectedDifficulty = value);
                          },
                    items: ['easy', 'medium', 'hard']
                        .map((difficulty) => DropdownMenuItem(
                              value: difficulty,
                              child: Row(
                                children: [
                                  Icon(
                                    difficulty == 'easy'
                                        ? Icons.trending_down
                                        : difficulty == 'medium'
                                            ? Icons.trending_flat
                                            : Icons.trending_up,
                                    size: 16,
                                    color: difficulty == 'easy'
                                        ? Colors.green[600]
                                        : difficulty == 'medium'
                                            ? Colors.orange[600]
                                            : Colors.red[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(difficulty.toUpperCase()),
                                ],
                              ),
                            ))
                        .toList(),
                    decoration: InputDecoration(
                      hintText: 'Select difficulty',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.speed, color: Colors.purple[600]),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Options Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey[200]!, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.list_alt, color: Colors.purple[600]),
                          const SizedBox(width: 12),
                          Text(
                            'Answer Options',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Options with radio buttons
                      ..._optionControllers.asMap().entries.map((entry) {
                        int index = entry.key;
                        TextEditingController controller = entry.value;
                        bool isCorrect = _correctAnswerIndex == index;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isCorrect ? Colors.green[50] : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCorrect
                                    ? Colors.green[300]!
                                    : Colors.grey[300]!,
                                width: isCorrect ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Radio<int>(
                                    value: index,
                                    groupValue: _correctAnswerIndex,
                                    onChanged: _isLoading
                                        ? null
                                        : (value) {
                                            setState(() =>
                                                _correctAnswerIndex = value ?? 0);
                                          },
                                    activeColor: Colors.green[600],
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    decoration: InputDecoration(
                                      hintText: 'Option ${String.fromCharCode(65 + index)}',
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 0,
                                      ),
                                    ),
                                    enabled: !_isLoading,
                                  ),
                                ),
                                if (isCorrect)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Icon(
                                      Icons.check_circle,
                                      color: Colors.green[600],
                                      size: 20,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 12),
                      Text(
                        'Select correct answer via radio button',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Messages
                if (_successMessage != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[300]!, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, 
                          color: Colors.green[600],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[300]!, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, 
                          color: Colors.red[600],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
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

                if (_successMessage != null || _errorMessage != null)
                  const SizedBox(height: 20),

                // Submit Button
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _isLoading
                          ? [Colors.grey[400]!, Colors.grey[500]!]
                          : [Colors.blue[600]!, Colors.purple[600]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      if (!_isLoading)
                        BoxShadow(
                          color: Colors.purple.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitQuestion,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.add_circle_outline, size: 20),
                    label: Text(
                      _isLoading ? 'Creating...' : 'Create Question',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
        ],
      ),
    );
  }
}
