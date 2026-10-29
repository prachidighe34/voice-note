import 'package:voice_note/models/note.dart';
import 'package:voice_note/models/note_status.dart';
import 'package:voice_note/screens/note_detail_screen.dart';
import 'package:voice_note/screens/record_screen.dart';
import 'package:voice_note/services/auth_service.dart';
import 'package:voice_note/services/note_repository.dart';
import 'package:voice_note/services/sync_service.dart';
import 'package:voice_note/widgets/mascot.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authService = AuthService();
  final _notesRepository = NotesRepository();
  final _syncService = SyncService();

  List<Note> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThenSync();
  }

  Future<void> _loadNotes() async {
    final notes = await _notesRepository.getAll();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _isLoading = false;
    });
  }

  Future<void> _loadThenSync() async {
    await _loadNotes();
    await _syncService.syncPendingNotes();
    await _syncService.refreshInProgressNotes();
    await _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _authService.signOut(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
          ? _buildEmptyState(context)
          : _buildNotesGrid(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startRecording,
        icon: const Icon(Icons.mic),
        label: const Text('Record'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Mascot(status: null, size: 140),
          const SizedBox(height: 24),
          Text('No notes yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Tap record to capture your first note.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesGrid() {
    return RefreshIndicator(
      onRefresh: _loadThenSync,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index];
          return _NoteCard(
            note: note,
            onTap: () => _openNote(note),
            onLongPress: () => _showNoteActions(note),
          );
        },
      ),
    );
  }

  Future<void> _openNote(Note note) async {
    if (note.status.isFailed) {
      await _retryNote(note.id);
      return;
    }
    await Navigator.of(context).push(NoteDetailPage.route(note));
    await _loadNotes();
  }

  Future<void> _showNoteActions(Note note) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.of(context).pop();
                _renameNote(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () {
                Navigator.of(context).pop();
                _confirmDelete(note);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameNote(Note note) async {
    final controller = TextEditingController(text: note.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename note'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTitle == null || newTitle.isEmpty || newTitle == note.title) return;

    await _notesRepository.updateTitle(note.id, newTitle);
    await _loadNotes();

    final userId = _authService.currentUser?.id;
    if (userId != null && !note.status.isBusy) {
      // Only attempt a server sync if the note has actually reached the
      // server before (busy/pending notes will send their current title
      // when they sync normally).
      await _syncService.renameOnServer(note.id, newTitle, userId);
    }
  }

  Future<void> _confirmDelete(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this note?'),
        content: Text(
          '"${note.title}" will be permanently deleted. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Delete locally first — the note disappears from the user's view
    // immediately, regardless of whether the server call below succeeds.
    await _notesRepository.delete(note.id);
    await _loadNotes();
    await _syncService.deleteOnServer(note.id);
  }

  Future<void> _startRecording() async {
    final result = await Navigator.of(context).push(RecordPage.route());
    if (result == null) return;

    final now = DateTime.now();
    final note = Note(
      id: result.noteId,
      title: result.title,
      status: NoteStatus.pending,
      localAudioPath: result.audioPath,
      targetLanguage: result.targetLanguage,
      recordedAt: now,
      updatedAt: now,
    );

    await _notesRepository.insert(note);
    await _loadNotes();
    await _syncService.syncPendingNotes();
    await _loadNotes();
  }

  Future<void> _retryNote(String noteId) async {
    await _syncService.retry(noteId);
    await _loadNotes();
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onLongPress,
  });

  String _statusLabel(NoteStatus status) {
    switch (status) {
      case NoteStatus.recording:
        return 'Recording...';
      case NoteStatus.pending:
        return 'Waiting to upload';
      case NoteStatus.uploading:
        return 'Uploading...';
      case NoteStatus.uploaded:
        return 'Uploaded';
      case NoteStatus.transcribing:
        return 'Transcribing...';
      case NoteStatus.translating:
        return 'Translating...';
      case NoteStatus.summarizing:
        return 'Summarizing...';
      case NoteStatus.summarized:
        return 'Done';
      case NoteStatus.failed:
        return 'Failed — tap to retry';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(child: Mascot(status: note.status, size: 64)),
              ),
              const SizedBox(height: 8),
              Text(
                note.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _statusLabel(note.status),
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
