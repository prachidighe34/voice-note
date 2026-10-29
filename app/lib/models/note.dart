import 'package:voice_note/models/note_status.dart';

class Note {
  final String id;
  final String title;
  final NoteStatus status;
  final String? localAudioPath;
  final String? transcript;
  final String? translatedText;
  final String? summary;
  final String? targetLanguage;
  final DateTime recordedAt;
  final DateTime updatedAt;

  const Note({
    required this.id,
    required this.title,
    required this.status,
    this.localAudioPath,
    this.transcript,
    this.translatedText,
    this.summary,
    this.targetLanguage,
    required this.recordedAt,
    required this.updatedAt,
  });

  Note copyWith({
    String? title,
    NoteStatus? status,
    String? localAudioPath,
    String? transcript,
    String? translatedText,
    String? summary,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      status: status ?? this.status,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      transcript: transcript ?? this.transcript,
      translatedText: translatedText ?? this.translatedText,
      summary: summary ?? this.summary,
      targetLanguage: targetLanguage,
      recordedAt: recordedAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'status': status.value,
      'local_audio_path': localAudioPath,
      'transcript': transcript,
      'translated_text': translatedText,
      'summary': summary,
      'target_language': targetLanguage,
      'recorded_at': recordedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Note.fromMap(Map<String, Object?> map) {
    return Note(
      id: map['id'] as String,
      title: map['title'] as String,
      status: NoteStatusX.fromValue(map['status'] as String),
      localAudioPath: map['local_audio_path'] as String?,
      transcript: map['transcript'] as String?,
      translatedText: map['translated_text'] as String?,
      summary: map['summary'] as String?,
      targetLanguage: map['target_language'] as String?,
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
