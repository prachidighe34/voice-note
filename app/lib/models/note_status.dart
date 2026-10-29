/// Mirrors the Go server's NoteStatus (see server/internal/models/note.go),
/// plus client-only states for the offline/sync lifecycle (Phase 2+).
enum NoteStatus {
  // Client-only states, before the note ever reaches the server.
  recording,
  pending, // recorded locally, waiting to upload
  uploading,

  // Server-driven pipeline states (match the Go backend's NoteStatus).
  uploaded,
  transcribing,
  translating,
  summarizing,
  summarized,
  failed,
}

extension NoteStatusX on NoteStatus {
  bool get isDone => this == NoteStatus.summarized;

  bool get isFailed => this == NoteStatus.failed;

  bool get isBusy => [
    NoteStatus.recording,
    NoteStatus.uploading,
    NoteStatus.transcribing,
    NoteStatus.translating,
    NoteStatus.summarizing,
  ].contains(this);

  String get value => name;

  static NoteStatus fromValue(String value) => NoteStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => NoteStatus.failed,
  );
}
