import 'dart:io';

import 'package:voice_note/models/note.dart';
import 'package:voice_note/models/note_status.dart';
import 'package:voice_note/services/local_db.dart';

class NotesRepository {
  Future<void> insert(Note note) async {
    final db = await LocalDb.instance;
    await db.insert('notes', note.toMap());
  }

  Future<void> updateStatus(String id, NoteStatus status) async {
    final db = await LocalDb.instance;
    await db.update(
      'notes',
      {'status': status.value, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTitle(String id, String title) async {
    final db = await LocalDb.instance;
    await db.update(
      'notes',
      {'title': title, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTranscript(String id, String transcript) async {
    final db = await LocalDb.instance;
    await db.update(
      'notes',
      {
        'transcript': transcript,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTranslatedText(String id, String translatedText) async {
    final db = await LocalDb.instance;
    await db.update(
      'notes',
      {
        'translated_text': translatedText,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateSummary(String id, String summary) async {
    final db = await LocalDb.instance;
    await db.update(
      'notes',
      {'summary': summary, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Note>> getAll() async {
    final db = await LocalDb.instance;
    final rows = await db.query('notes', orderBy: 'recorded_at DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<List<Note>> getPending() async {
    final db = await LocalDb.instance;
    final rows = await db.query(
      'notes',
      where: 'status = ?',
      whereArgs: [NoteStatus.pending.value],
      orderBy: 'recorded_at ASC',
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<Note?> getById(String id) async {
    final db = await LocalDb.instance;
    final rows = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  /// Deletes the local DB row and the local audio file, if any. Does NOT
  /// touch the server — see SyncService for best-effort server deletion.
  Future<void> delete(String id) async {
    final note = await getById(id);
    if (note?.localAudioPath != null) {
      final file = File(note!.localAudioPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    final db = await LocalDb.instance;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}
