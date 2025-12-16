/// Admin Manage Rooms Screen - Create and manage quiz rooms
import 'package:flutter/material.dart';

import '../services/supabase_direct_service.dart';

class AdminManageRoomsScreen extends StatefulWidget {
  const AdminManageRoomsScreen({super.key});

  @override
  State<AdminManageRoomsScreen> createState() =>
      _AdminManageRoomsScreenState();
}

class _AdminManageRoomsScreenState extends State<AdminManageRoomsScreen> {
  final _roomNameController = TextEditingController();
  final _totalQuestionsController = TextEditingController(text: '10');
  final _timeLimitController = TextEditingController(text: '30');

  String _selectedTheme = 'tree';
  int? _selectedSubjectId;
  int? _selectedSetId;
  bool _isLoading = false;
  bool _isLoadingData = false;
  String? _successMessage;
  String? _errorMessage;
  
  List<dynamic> _subjects = [];
  final Map<int, List<dynamic>> _questionSets = {};
  int? _totalQuestionsInSet;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() => _isLoadingData = true);
    try {
      final subjects = await SupabaseDirectService.getSubjects();
      if (mounted) {
        setState(() => _subjects = subjects);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load subjects');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
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
          _totalQuestionsInSet = null;
          _totalQuestionsController.text = '10';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load question sets');
      }
    }
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _totalQuestionsController.dispose();
    _timeLimitController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final roomName = _roomNameController.text.trim();
    final totalQuestions = int.tryParse(_totalQuestionsController.text) ?? 0;
    final timeLimit = int.tryParse(_timeLimitController.text) ?? 30;

    // Validation
    if (roomName.isEmpty) {
      setState(() => _errorMessage = 'Please enter room name');
      return;
    }

    if (_selectedSubjectId == null) {
      setState(() => _errorMessage = 'Please select a subject');
      return;
    }

    if (_selectedSetId == null) {
      setState(() => _errorMessage = 'Please select a question set');
      return;
    }

    if (totalQuestions <= 0) {
      setState(() =>
          _errorMessage = 'Please enter valid number of questions');
      return;
    }

    // Theme is fixed to 'tree' template for new rooms

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await SupabaseDirectService.createQuizRoom(
        roomName: roomName,
        theme: 'tree',
        totalQuestions: totalQuestions,
        timeLimitPerQuestion: timeLimit,
      );

      // After creating the room, attach questions from the selected set
      try {
        final createdRoomId = response['room_id'] is int
            ? response['room_id'] as int
            : int.tryParse('${response['room_id']}') ?? 0;

        final sets = _questionSets[_selectedSubjectId] ?? [];
        Map<String, dynamic>? selectedSet;
        for (final s in sets) {
          try {
            final Map<String, dynamic> sm = Map<String, dynamic>.from(s as Map);
            if (sm['set_id'] == _selectedSetId || sm['set_id']?.toString() == _selectedSetId?.toString()) {
              selectedSet = sm;
              break;
            }
          } catch (_) {}
        }

        if (selectedSet != null) {
          final List<dynamic> questionsRaw = (selectedSet['questions'] as List<dynamic>?) ?? [];
          final List<int> questionIds = questionsRaw.map<int>((q) {
            final qm = q as Map<String, dynamic>;
            return qm['question_id'] is int ? qm['question_id'] as int : int.tryParse('${qm['question_id']}') ?? 0;
          }).take(totalQuestions).toList();

          if (questionIds.isNotEmpty) {
            await SupabaseDirectService.addQuestionsToRoom(roomId: createdRoomId, questionIds: questionIds);
          }
        }
      } catch (e) {
        // non-fatal: room created but attaching questions failed
        if (mounted) {
          setState(() => _errorMessage = 'Room created but failed to attach questions: ${e.toString()}');
        }
      }

      if (mounted) {
          setState(() {
          _successMessage =
              'Room created! Code: ${response['room_code'] ?? 'N/A'}';
          _roomNameController.clear();
          _roomNameController.clear();
          _totalQuestionsController.text = '10';
          _timeLimitController.text = '30';
            _selectedTheme = 'tree';
          _selectedSubjectId = null;
          _selectedSetId = null;
          _totalQuestionsInSet = null;
        });
        // Clear message after 5 seconds
        await Future.delayed(const Duration(seconds: 5));
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
                    Icons.meeting_room,
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
                        'Create New Room',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set up a new quiz room with questions',
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

          // Form Container
          Container(
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Room Name Input
                _buildFormField(
                  label: 'Room Name',
                  icon: Icons.meeting_room,
                  child: TextField(
                    controller: _roomNameController,
                    decoration: _buildInputDecoration(
                      label: 'Enter room name',
                      icon: Icons.meeting_room,
                      enabled: !_isLoading,
                    ),
                    enabled: !_isLoading,
                  ),
                ),
                const SizedBox(height: 20),

                // Subject Selection
                _buildFormField(
                  label: 'Subject (Mata Pelajaran)',
                  icon: Icons.book,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedSubjectId,
                      onChanged: _isLoading || _isLoadingData
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
                        hintText: 'Select subject',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.book, color: Colors.purple[600]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Question Set Selection
                if (_selectedSubjectId != null)
                  _buildFormField(
                    label: 'Question Set (Bungkus Soal)',
                    icon: Icons.layers,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: DropdownButtonFormField<int>(
                        initialValue: _selectedSetId,
                        onChanged: _isLoading || _isLoadingData
                            ? null
                            : (value) {
                                if (value != null) {
                                    final selectedSet =
                                      (_questionSets[_selectedSubjectId] ?? [])
                                        .firstWhere((set) => set['set_id'] == value,
                                          orElse: () => <String, dynamic>{});
                                  setState(() {
                                    _selectedSetId = value;
                                    _totalQuestionsInSet =
                                        selectedSet?['total_questions'] ?? 0;
                                    _totalQuestionsController.text =
                                        (_totalQuestionsInSet ?? 10).toString();
                                  });
                                }
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
                                child: Text('$setName ($totalQuestions questions)'),
                              );
                            })
                            .toList(),
                        decoration: InputDecoration(
                          hintText: 'Select question set',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.layers, color: Colors.purple[600]),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue[600]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Please select a subject first',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_selectedSubjectId != null) const SizedBox(height: 20),

                // Theme is fixed to 'tree' template; no selection UI shown
                const SizedBox(height: 20),

                // Total Questions Input (Read-only)
                _buildFormField(
                  label: 'Total Questions',
                  icon: Icons.numbers,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _totalQuestionsController,
                      decoration: InputDecoration(
                        hintText: 'Auto-populated from Question Set',
                        prefixIcon: Icon(Icons.numbers, color: Colors.grey[600]),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                      ),
                      keyboardType: TextInputType.number,
                      enabled: false,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Time Limit Input
                _buildFormField(
                  label: 'Time per Question (seconds)',
                  icon: Icons.schedule,
                  child: TextField(
                    controller: _timeLimitController,
                    decoration: _buildInputDecoration(
                      label: 'Enter time limit',
                      icon: Icons.schedule,
                      enabled: !_isLoading,
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isLoading,
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
                border: Border.all(color: Colors.green[200]!, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 22),
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
                border: Border.all(color: Colors.red[200]!, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[600], size: 22),
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
                colors: _isLoading
                    ? [Colors.grey[400]!, Colors.grey[500]!]
                    : [Colors.green[600]!, Colors.green[400]!],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (!_isLoading)
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoading ? null : _createRoom,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_isLoading) ...[
                        const Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
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
                        const Text(
                          'Create Room',
                          style: TextStyle(
                            fontSize: 14,
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
          const SizedBox(height: 24),
        ],
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    required bool enabled,
  }) {
    return InputDecoration(
      hintText: label,
      prefixIcon: Icon(icon, color: Colors.purple[600], size: 20),
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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }
}
