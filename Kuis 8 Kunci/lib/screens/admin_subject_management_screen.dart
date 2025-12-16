/// Admin Subject Management Screen - Create and manage subjects
import 'package:flutter/material.dart';

import '../services/supabase_direct_service.dart';
import 'view_questions_screen.dart';

class AdminSubjectManagementScreen extends StatefulWidget {
  const AdminSubjectManagementScreen({super.key});

  @override
  State<AdminSubjectManagementScreen> createState() =>
      _AdminSubjectManagementScreenState();
}

class _AdminSubjectManagementScreenState extends State<AdminSubjectManagementScreen> {
  final _subjectNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingList = false;
  String? _errorMessage;
  String? _successMessage;
  List<dynamic> _subjects = [];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  @override
  void dispose() {
    _subjectNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    setState(() => _isLoadingList = true);
    try {
      final subjects = await SupabaseDirectService.getSubjects();
      if (mounted) {
        setState(() => _subjects = subjects);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingList = false);
      }
    }
  }

  Future<void> _createSubject() async {
    final subjectName = _subjectNameController.text.trim();
    final description = _descriptionController.text.trim();

    if (subjectName.isEmpty) {
      setState(() => _errorMessage = 'Please enter subject name');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await SupabaseDirectService.createSubject(
        subjectName: subjectName,
        description: description.isEmpty ? null : description,
      );

      if (mounted) {
        setState(() {
          _successMessage = 'Subject "$subjectName" created!';
          _subjectNameController.clear();
          _descriptionController.clear();
        });

        // Reload subjects
        await _loadSubjects();

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

  void _selectSubject(Map<String, dynamic> subject) {
    // Navigate to question set management for this subject
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminQuestionSetManagementScreen(
          subjectId: subject['subject_id'],
          subjectName: subject['subject_name'],
        ),
      ),
    );
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
                    Icons.book,
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
                        'Subject Management',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create and manage subjects',
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

          // Create Subject Form
          Container(
            padding: const EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create New Subject',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),

                // Subject Name Input
                _buildFormField(
                  label: 'Subject Name',
                  controller: _subjectNameController,
                  hint: 'e.g., Mathematics, Biology',
                  icon: Icons.school,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),

                // Description Input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description (Optional)',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Grade 10 Math',
                        prefixIcon: Icon(Icons.description, color: Colors.purple[600]),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      ),
                      enabled: !_isLoading,
                      maxLines: 2,
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Messages
                if (_successMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[600], size: 20),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[600], size: 20),
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
                  const SizedBox(height: 16),

                // Submit Button
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue[600]!,
                        Colors.blue[400]!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading ? null : _createSubject,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_isLoading) ...[
                              const Icon(Icons.add, color: Colors.white, size: 20),
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
                              Text(
                                'Create Subject',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Subjects List
          Text(
            'My Subjects (${_subjects.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoadingList)
            const Center(
              child: CircularProgressIndicator(),
            ),

          if (!_isLoadingList && _subjects.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.subject,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No subjects yet',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first subject above',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (!_isLoadingList && _subjects.isNotEmpty)
            ..._subjects.map((subject) {
              final int setCount = subject['question_set_count'] ?? (subject['question_sets'] is List ? (subject['question_sets'] as List).length : 0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.book,
                      color: Colors.blue[600],
                    ),
                    title: Text(
                      subject['subject_name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '$setCount question sets',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => _selectSubject(subject),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.purple[600]),
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
          ),
          enabled: enabled,
        ),
      ],
    );
  }
}

/// Question Set Management Screen for a specific subject
class AdminQuestionSetManagementScreen extends StatefulWidget {
  final int subjectId;
  final String subjectName;

  const AdminQuestionSetManagementScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<AdminQuestionSetManagementScreen> createState() =>
      _AdminQuestionSetManagementScreenState();
}

class _AdminQuestionSetManagementScreenState
    extends State<AdminQuestionSetManagementScreen> {
  final _setNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingList = false;
  String? _errorMessage;
  String? _successMessage;
  Map<String, dynamic>? _subjectData;

  @override
  void initState() {
    super.initState();
    _loadSubjectDetail();
  }

  @override
  void dispose() {
    _setNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjectDetail() async {
    setState(() => _isLoadingList = true);
    try {
      final subject = await SupabaseDirectService.getSubjectDetail(widget.subjectId);
      if (mounted) {
        setState(() {
          _subjectData = subject;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingList = false);
      }
    }
  }

  Future<void> _createQuestionSet() async {
    final setName = _setNameController.text.trim();
    final description = _descriptionController.text.trim();

    if (setName.isEmpty) {
      setState(() => _errorMessage = 'Please enter set name');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await SupabaseDirectService.createQuestionSet(
        subjectId: widget.subjectId,
        setName: setName,
        description: description,
      );

      if (mounted) {
        setState(() {
          _successMessage = 'Question set "$setName" created!';
          _setNameController.clear();
          _descriptionController.clear();
        });

        await _loadSubjectDetail();

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

  void _selectQuestionSet(Map<String, dynamic> questionSet) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewQuestionsScreen(
          setId: questionSet['set_id'],
          setName: questionSet['set_name'],
          subjectId: widget.subjectId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subjectName),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // Create Question Set Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create New Question Set (Bungkus Soal)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Example: "PR Minggu 1", "Chapter 3 Test", "Midterm Practice"',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Set Name Input
                    TextField(
                      controller: _setNameController,
                      decoration: InputDecoration(
                        labelText: 'Question Set Name',
                        hintText: 'e.g., PR Minggu 1, Chapter 3',
                        prefixIcon: const Icon(Icons.folder),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabled: !_isLoading,
                      ),
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),

                    // Description Input
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'e.g., Contains 20 questions about Chapter 3',
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabled: !_isLoading,
                      ),
                      enabled: !_isLoading,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Messages
                    if (_successMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[400]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: TextStyle(color: Colors.green[700]),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[400]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error, color: Colors.red[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_successMessage != null || _errorMessage != null)
                      const SizedBox(height: 16),

                    // Create Button
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _createQuestionSet,
                      icon: const Icon(Icons.add),
                      label: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create Question Set'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Question Sets List
            if (_isLoadingList)
              const Center(
                child: CircularProgressIndicator(),
              ),

            if (!_isLoadingList && (_subjectData?['question_sets'] == null || (_subjectData?['question_sets'] as List).isEmpty))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.layers,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No question sets yet',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first question set above',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (!_isLoadingList && _subjectData?['question_sets'] != null && (_subjectData?['question_sets'] as List).isNotEmpty)
              ...((_subjectData?['question_sets'] ?? []) as List).map((set) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.layers,
                        color: Colors.purple[600],
                      ),
                      title: Text(
                        set['set_name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${set['total_questions'] ?? 0} questions',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () => _selectQuestionSet(set),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// Add Questions to a Question Set
class AdminAddQuestionsScreen extends StatefulWidget {
  final int setId;
  final String setName;

  const AdminAddQuestionsScreen({
    super.key,
    required this.setId,
    required this.setName,
  });

  @override
  State<AdminAddQuestionsScreen> createState() =>
      _AdminAddQuestionsScreenState();
}

class _AdminAddQuestionsScreenState extends State<AdminAddQuestionsScreen> {
  final _questionController = TextEditingController();
  final _optionControllers = List.generate(4, (_) => TextEditingController());
  
  String? _selectedDifficulty = 'medium';
  int _correctAnswerIndex = 0;
  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;

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

    if (question.isEmpty) {
      setState(() => _errorMessage = 'Please enter a question');
      return;
    }

    if (options.any((option) => option.isEmpty)) {
      setState(() => _errorMessage = 'Please fill all options');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final correctAnswerLetter = ['A', 'B', 'C', 'D'][_correctAnswerIndex];
      await SupabaseDirectService.createQuestion(
        questionText: question,
        optionA: options[0],
        optionB: options[1],
        optionC: options[2],
        optionD: options[3],
        correctAnswer: correctAnswerLetter,
        difficulty: _selectedDifficulty!,
        setId: widget.setId,
      );

      if (mounted) {
        setState(() {
          _successMessage = 'Question added to "${widget.setName}"!';
          _questionController.clear();
          for (var controller in _optionControllers) {
            controller.clear();
          }
          _correctAnswerIndex = 0;
        });

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Questions to ${widget.setName}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // Question Input
            TextField(
              controller: _questionController,
              decoration: InputDecoration(
                labelText: 'Question',
                hintText: 'Enter the quiz question',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabled: !_isLoading,
              ),
              maxLines: 3,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 20),

            // Difficulty Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedDifficulty,
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() => _selectedDifficulty = value);
                    },
              items: ['easy', 'medium', 'hard']
                  .map((difficulty) => DropdownMenuItem(
                        value: difficulty,
                        child: Text(difficulty.toUpperCase()),
                      ))
                  .toList(),
              decoration: InputDecoration(
                labelText: 'Difficulty',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Options
            Text(
              'Options',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            ..._optionControllers.asMap().entries.map((entry) {
              int index = entry.key;
              TextEditingController controller = entry.value;

              return Column(
                children: [
                  Row(
                    children: [
                      Radio<int>(
                        value: index,
                        groupValue: _correctAnswerIndex,
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                setState(() => _correctAnswerIndex = value ?? 0);
                              },
                      ),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: 'Option ${String.fromCharCode(65 + index)}',
                            hintText: 'Enter option',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          enabled: !_isLoading,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }),

            const SizedBox(height: 12),
            Text(
              'Select the correct answer',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),

            // Messages
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[400]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: TextStyle(color: Colors.green[700]),
                      ),
                    ),
                  ],
                ),
              ),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[400]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),

            if (_successMessage != null || _errorMessage != null)
              const SizedBox(height: 16),

            // Submit Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitQuestion,
              icon: const Icon(Icons.add),
              label: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Question'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
