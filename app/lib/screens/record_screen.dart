import 'package:voice_note/models/languages.dart';
import 'package:voice_note/models/note_status.dart';
import 'package:voice_note/services/recorder_service.dart';
import 'package:voice_note/widgets/mascot.dart';
import 'package:flutter/material.dart';

/// Result returned to HomePage when recording finishes successfully.
class RecordingResult {
  final String noteId;
  final String audioPath;
  final Duration duration;
  final String title;
  final String? targetLanguage; // null = no translation requested

  RecordingResult({
    required this.noteId,
    required this.audioPath,
    required this.duration,
    required this.title,
    this.targetLanguage,
  });
}

class RecordPage extends StatefulWidget {
  static MaterialPageRoute<RecordingResult> route() =>
      MaterialPageRoute(builder: (context) => const RecordPage());

  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  final _recorderService = RecorderService();

  bool _isRecording = false;
  bool _isStarting = false;
  String? _noteId;
  Duration _elapsed = Duration.zero;

  @override
  void dispose() {
    if (_isRecording) {
      _recorderService.cancel();
    }
    _recorderService.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    setState(() => _isStarting = true);
    try {
      final noteId = await _recorderService.start();
      _recorderService.elapsedStream?.listen((d) {
        if (mounted) setState(() => _elapsed = d);
      });
      setState(() {
        _noteId = noteId;
        _isRecording = true;
        _isStarting = false;
      });
    } on RecorderPermissionException catch (e) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not start recording: $e')));
    }
  }

  Future<void> _stopRecording() async {
    final path = await _recorderService.stop();
    if (!mounted) return;

    if (path == null || _noteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording failed — nothing was saved.')),
      );
      Navigator.of(context).pop();
      return;
    }

    final details = await _promptForDetails();
    if (!mounted) return;

    Navigator.of(context).pop(
      RecordingResult(
        noteId: _noteId!,
        audioPath: path,
        duration: _elapsed,
        title: details.$1,
        targetLanguage: details.$2,
      ),
    );
  }

  /// Asks for a title and an optional translation target language.
  /// Returns (title, targetLanguageOrNull).
  Future<(String, String?)> _promptForDetails() async {
    final controller = TextEditingController(text: _defaultTitle());
    String? selectedLanguage; // null = "None" (no translation)

    final result = await showDialog<(String, String?)>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Name this note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Note title'),
              ),
              const SizedBox(height: 16),
              const Text('Translate to'),
              const SizedBox(height: 4),
              DropdownButton<String?>(
                isExpanded: true,
                value: selectedLanguage,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...supportedLanguages.map(
                    (lang) => DropdownMenuItem<String?>(
                      value: lang.code,
                      child: Text(lang.label),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setDialogState(() => selectedLanguage = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pop((controller.text, selectedLanguage)),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    final title = result?.$1.trim();
    final language = result?.$2;
    return (
      (title == null || title.isEmpty) ? _defaultTitle() : title,
      language,
    );
  }

  String _defaultTitle() {
    final now = DateTime.now();
    return 'Note ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New note')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Mascot(
              status: _isRecording ? NoteStatus.recording : null,
              size: 180,
            ),
            const SizedBox(height: 24),
            Text(
              _formatDuration(_elapsed),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _isStarting ? null : _toggleRecording,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isRecording ? 'Tap to stop' : 'Tap to record',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
