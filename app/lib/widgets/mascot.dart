import 'package:voice_note/models/note_status.dart';
import 'package:flutter/material.dart';

/// Shows the mascot illustration matching the current note status,
/// crossfading smoothly whenever the status changes.
class Mascot extends StatelessWidget {
  /// Null means idle — no active note (e.g. the record screen before the
  /// user has started anything).
  final NoteStatus? status;
  final double size;

  const Mascot({super.key, required this.status, this.size = 160});

  String get _assetPath {
    final s = status;
    if (s == null) return 'assets/images/mascot/maru-chan-idle.png';

    switch (s) {
      case NoteStatus.recording:
      case NoteStatus.pending:
        return 'assets/images/mascot/maru-chan-recording.png';
      case NoteStatus.uploading:
      case NoteStatus.uploaded:
        return 'assets/images/mascot/maru-chan-uploading.png'; // reuse until a dedicated upload pose exists
      case NoteStatus.transcribing:
      case NoteStatus.translating:
        return 'assets/images/mascot/maru-chan-transcribing.png';
      case NoteStatus.summarized:
        return 'assets/images/mascot/maru-chan-done.png';
      case NoteStatus.summarizing:
        return 'assets/images/mascot/maru-chan-done.png';
      case NoteStatus.failed:
        return 'assets/images/mascot/maru-chan-failed.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: Image.asset(
        _assetPath,
        key: ValueKey(_assetPath), // tells AnimatedSwitcher the image changed
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
