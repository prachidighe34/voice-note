import 'package:voice_note/models/languages.dart';
import 'package:voice_note/models/note.dart';
import 'package:voice_note/services/note_repository.dart';
import 'package:voice_note/services/sync_service.dart';
import 'package:voice_note/widgets/mascot.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:voice_note/models/note_status.dart';

class NoteDetailPage extends StatefulWidget {
  static MaterialPageRoute route(Note note) =>
      MaterialPageRoute(builder: (context) => NoteDetailPage(note: note));

  final Note note;
  const NoteDetailPage({super.key, required this.note});

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  final _repo = NotesRepository();
  final _syncService = SyncService();
  final _player = AudioPlayer();
  late TextEditingController _transcriptController;
  late Note _note;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _audioDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _transcriptController = TextEditingController(text: _note.transcript ?? '');

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _audioDuration = dur);
    });
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_note.localAudioPath == null) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_position > Duration.zero && _position < _audioDuration) {
        await _player.resume();
      } else {
        await _player.play(DeviceFileSource(_note.localAudioPath!));
      }
    }
  }

  Future<void> _saveEdit() async {
    final edited = _transcriptController.text.trim();
    setState(() => _isSaving = true);

    // Save locally first — the user sees their correction immediately,
    // regardless of what happens with the server sync below.
    await _repo.updateTranscript(_note.id, edited);
    setState(() {
      _note = _note.copyWith(transcript: edited);
      _isEditing = false;
      _isSaving = false;
    });

    // Best-effort server sync — failure here doesn't affect the user's
    // local copy, just means the server falls behind until it succeeds.
    await _syncService.editTranscriptOnServer(_note.id, edited);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio = _note.localAudioPath != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_note.title),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit transcript',
              onPressed: _note.transcript == null
                  ? null
                  : () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Mascot(status: _note.status, size: 80),
            const SizedBox(height: 12),
            if (hasAudio) ...[
              Row(
                children: [
                  IconButton(
                    iconSize: 48,
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                    ),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: _togglePlayback,
                  ),
                  Expanded(
                    child: Slider(
                      value: _position.inMilliseconds
                          .clamp(
                            0,
                            _audioDuration.inMilliseconds == 0
                                ? 1
                                : _audioDuration.inMilliseconds,
                          )
                          .toDouble(),
                      max: _audioDuration.inMilliseconds == 0
                          ? 1
                          : _audioDuration.inMilliseconds.toDouble(),
                      onChanged: (value) {
                        _player.seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  ),
                  Text(_formatDuration(_position)),
                ],
              ),
              const Divider(height: 24),
            ],
            Expanded(
              child: _isEditing
                  ? _buildEditView(context)
                  : _buildReadView(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadView(BuildContext context) {
    if (_note.transcript == null) {
      return Center(
        child: Text(
          _note.status.isBusy
              ? 'Still working on this one...'
              : 'No transcript available.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Summary', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_note.summary == null)
            Text(
              _note.status.isBusy ? 'Summarizing...' : 'No summary available.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Text(_note.summary!, style: Theme.of(context).textTheme.bodyLarge),

          const SizedBox(height: 24),
          Text('Transcript', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            _note.transcript!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          if (_note.targetLanguage != null) ...[
            const SizedBox(height: 24),
            Text(
              'Translation (${languageLabelFor(_note.targetLanguage)})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_note.translatedText == null)
              Text(
                _note.status.isBusy
                    ? 'Translating...'
                    : 'No translation available.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Text(
                _note.translatedText!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Editing transcript',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            controller: _transcriptController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: 'Edit the transcript...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving
                    ? null
                    : () => setState(() {
                        _transcriptController.text = _note.transcript ?? '';
                        _isEditing = false;
                      }),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveEdit,
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
