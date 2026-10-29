import 'package:voice_note/models/note_status.dart';
import 'package:voice_note/services/api_client.dart';
import 'package:voice_note/services/auth_service.dart';
import 'package:voice_note/services/note_repository.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  final _repo = NotesRepository();
  final _api = ApiClient();
  final _auth = AuthService();

  Future<void> syncPendingNotes() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[sync] skipped: no logged-in user');
      return;
    }

    final pending = await _repo.getPending();
    debugPrint('[sync] ${pending.length} pending note(s) to sync');

    for (final note in pending) {
      if (note.localAudioPath == null) {
        debugPrint(
          '[sync] note ${note.id} has no local audio path — marking failed',
        );
        await _repo.updateStatus(note.id, NoteStatus.failed);
        continue;
      }

      await _repo.updateStatus(note.id, NoteStatus.uploading);
      try {
        await _api.createNote(
          id: note.id,
          userId: userId,
          title: note.title,
          targetLanguage: note.targetLanguage,
        );
        final serverStatus = await _api.uploadAudio(
          noteId: note.id,
          audioPath: note.localAudioPath!,
        );
        await _repo.updateStatus(note.id, NoteStatusX.fromValue(serverStatus));
      } catch (e, stack) {
        debugPrint('[sync] FAILED for note ${note.id}: $e');
        debugPrint('[sync] stack: $stack');
        await _repo.updateStatus(note.id, NoteStatus.failed);
      }
    }
  }

  Future<void> refreshInProgressNotes() async {
    final all = await _repo.getAll();
    final inProgress = all.where(
      (n) => n.status.isBusy && n.status != NoteStatus.recording,
    );
    debugPrint(
      '[sync] checking ${inProgress.length} in-progress note(s) for updates',
    );

    for (final note in inProgress) {
      try {
        final serverNote = await _api.getNote(note.id);
        final status = NoteStatusX.fromValue(
          serverNote['status'] as String? ?? '',
        );
        final transcript = serverNote['transcript'] as String?;
        final translatedText = serverNote['translated_text'] as String?;
        final summary = serverNote['summary'] as String?;

        await _repo.updateStatus(note.id, status);
        if (transcript != null && transcript.isNotEmpty) {
          await _repo.updateTranscript(note.id, transcript);
        }
        if (translatedText != null && translatedText.isNotEmpty) {
          await _repo.updateTranslatedText(note.id, translatedText);
        }
        if (summary != null && summary.isNotEmpty) {
          await _repo.updateSummary(note.id, summary);
        }
      } catch (e) {
        debugPrint('[sync] refresh check failed for ${note.id}: $e');
      }
    }
  }

  Future<void> retry(String noteId) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return;

    final note = await _repo.getById(noteId);
    if (note == null || note.localAudioPath == null) return;

    await _repo.updateStatus(note.id, NoteStatus.uploading);
    try {
      await _api.createNote(
        id: note.id,
        userId: userId,
        title: note.title,
        targetLanguage: note.targetLanguage,
      );
      final serverStatus = await _api.uploadAudio(
        noteId: note.id,
        audioPath: note.localAudioPath!,
      );
      await _repo.updateStatus(note.id, NoteStatusX.fromValue(serverStatus));
    } catch (e) {
      debugPrint('[sync] retry FAILED for note $noteId: $e');
      await _repo.updateStatus(note.id, NoteStatus.failed);
    }
  }

  /// Best-effort: the title is already renamed locally by the time this
  /// is called, so a failure here just means the server falls out of
  /// sync until the next successful call (e.g. a future edit, or if you
  /// add a dedicated retry queue for this later).
  Future<void> renameOnServer(
    String noteId,
    String title,
    String userId,
  ) async {
    try {
      await _api.createNote(id: noteId, userId: userId, title: title);
    } catch (e) {
      debugPrint('[sync] rename sync failed for $noteId: $e');
    }
  }

  /// Best-effort: pushes a locally edited transcript to the server. The
  /// local edit already happened by the time this runs, so the user sees
  /// their correction immediately regardless of whether this succeeds.
  Future<void> editTranscriptOnServer(String noteId, String transcript) async {
    try {
      await _api.updateTranscript(noteId: noteId, transcript: transcript);
    } catch (e) {
      debugPrint('[sync] transcript edit sync failed for $noteId: $e');
    }
  }

  /// Best-effort server delete — local deletion already happened by the
  /// time this runs, so the note is gone from the user's view regardless
  /// of whether this succeeds (e.g. no connection right now).
  Future<void> deleteOnServer(String noteId) async {
    try {
      await _api.deleteNote(noteId);
    } catch (e) {
      debugPrint('[sync] server delete failed for $noteId: $e');
    }
  }
}
