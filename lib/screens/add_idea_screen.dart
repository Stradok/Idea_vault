import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../services/backend.dart';
import '../state/idea_vault.dart';

class AddIdeaScreen extends StatefulWidget {
  const AddIdeaScreen({super.key});

  @override
  State<AddIdeaScreen> createState() => _AddIdeaScreenState();
}

class _AddIdeaScreenState extends State<AddIdeaScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  late final String _pendingId = const Uuid().v4();

  String? _localImagePath;
  String? _localAudioPath;
  bool _isRecording = false;
  bool _saving = false;
  int _recordSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _titleController.text.trim().isNotEmpty ||
      _localImagePath != null ||
      _localAudioPath != null;

  Future<void> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    if (!mounted) return;
    setState(() => _localImagePath = file.path);
  }

  Future<void> _toggleRecord() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      _timer?.cancel();
      setState(() {
        _isRecording = false;
        _localAudioPath = path;
      });
      return;
    }

    final backend = context.read<Backend>();
    final path = await backend.media.tempAudioPath(_pendingId);
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission needed')),
      );
      return;
    }
    final isLinux = !kIsWeb && Platform.isLinux;
    final config = isLinux
        ? const RecordConfig(encoder: AudioEncoder.pcm16bits)
        : const RecordConfig(encoder: AudioEncoder.aacLc);
    await _recorder.start(config, path: path);
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordSeconds++);
    });
  }

  String _formatRecordTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _save() async {
    final vault = context.read<IdeaVault>();
    setState(() => _saving = true);
    try {
      await vault.addIdea(
        title: _titleController.text.trim().isEmpty
            ? (_localAudioPath != null ? 'Voice note idea' : 'New idea')
            : _titleController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        localImagePath: _localImagePath,
        localAudioPath: _localAudioPath,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save idea: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture idea'),
        actions: [
          TextButton(
            onPressed: _canSave && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              maxLines: 1,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'What\'s your idea?',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Add context, problem, who it\'s for...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_localImagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    Image.file(
                      File(_localImagePath!),
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        onPressed: () => setState(() => _localImagePath = null),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                _CaptureChip(
                  icon: Icons.photo_camera_outlined,
                  label: 'Photo',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: 8),
                _CaptureChip(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CaptureChip(
                    icon: _isRecording ? Icons.stop : Icons.mic_none,
                    label: _isRecording
                        ? 'Stop ${_formatRecordTime(_recordSeconds)}'
                        : (_localAudioPath != null ? 'Re-record' : 'Record'),
                    active: _isRecording,
                    onTap: _toggleRecord,
                  ),
                ),
              ],
            ),
            if (_localAudioPath != null && !_isRecording) ...[
              const SizedBox(height: 12),
              _AudioPreview(path: _localAudioPath!, player: _player),
            ],
          ],
        ),
      ),
    );
  }
}

class _CaptureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _CaptureChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.red.shade50 : null;
    final iconColor = active ? Colors.red : Theme.of(context).colorScheme.primary;
    return Expanded(
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioPreview extends StatelessWidget {
  final String path;
  final AudioPlayer player;
  const _AudioPreview({required this.path, required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.graphic_eq, color: Colors.black54),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Voice note saved', style: TextStyle(fontSize: 13)),
          ),
          IconButton(
            tooltip: 'Play',
            onPressed: () async {
              await player.stop();
              await player.play(DeviceFileSource(path));
            },
            icon: const Icon(Icons.play_circle_outline),
          ),
        ],
      ),
    );
  }
}
