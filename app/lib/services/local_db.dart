import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(docsDir.path, 'voice_notes.db');

    return openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            status TEXT NOT NULL,
            local_audio_path TEXT,
            transcript TEXT,
            translated_text TEXT,
            summary TEXT,
            target_language TEXT,
            recorded_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_notes_status ON notes(status)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE notes ADD COLUMN translated_text TEXT');
          await db.execute('ALTER TABLE notes ADD COLUMN target_language TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE notes ADD COLUMN summary TEXT');
        }
      },
    );
  }
}
