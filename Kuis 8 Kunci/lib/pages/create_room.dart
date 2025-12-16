import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({super.key});

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final _formKey = GlobalKey<FormState>();
  final _roomNameController = TextEditingController();
  final _themeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _roomNameController.dispose();
    _themeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final room = {
      'room_name': _roomNameController.text.trim(),
      'room_code': DateTime.now().millisecondsSinceEpoch.toString().substring(8),
      'theme': _themeController.text.trim().isEmpty ? 'tree' : _themeController.text.trim(),
      'status': 'draft'
    };

    try {
      final created = await SupabaseService.createRoom(room);
      Navigator.of(context).pop(created);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating room: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Room')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _roomNameController,
                decoration: const InputDecoration(labelText: 'Room Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a room name' : null,
              ),
              TextFormField(
                controller: _themeController,
                decoration: const InputDecoration(labelText: 'Theme (optional)'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting ? const CircularProgressIndicator() : const Text('Create Room'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
