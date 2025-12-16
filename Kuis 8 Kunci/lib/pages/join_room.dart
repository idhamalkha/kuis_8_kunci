import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class JoinRoomPage extends StatefulWidget {
  const JoinRoomPage({super.key});

  @override
  State<JoinRoomPage> createState() => _JoinRoomPageState();
}

class _JoinRoomPageState extends State<JoinRoomPage> {
  final _formKey = GlobalKey<FormState>();
  final _roomCodeController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _isJoining = false;

  @override
  void dispose() {
    _roomCodeController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isJoining = true);

    try {
      // Find room by code
      final rooms = await SupabaseService.listRooms();
      final room = rooms.firstWhere((r) => r['room_code'] == _roomCodeController.text.trim(), orElse: () => <String, dynamic>{});
      if (room == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room not found')));
        return;
      }

      final participant = {
        'room_id': room['room_id'],
        'nickname': _nicknameController.text.trim(),
      };

      final created = await SupabaseService.joinRoom(participant);
      Navigator.of(context).pop(created);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error joining room: $e')));
    } finally {
      setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Room')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _roomCodeController,
                decoration: const InputDecoration(labelText: 'Room Code'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a room code' : null,
              ),
              TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(labelText: 'Your nickname'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your nickname' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isJoining ? null : _join,
                child: _isJoining ? const CircularProgressIndicator() : const Text('Join Room'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
