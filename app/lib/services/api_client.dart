import 'dart:convert';

import 'package:voice_note/config/server_config.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  final http.Client _client = http.Client();

  Future<void> createNote({
    required String id,
    required String userId,
    required String title,
    String? targetLanguage,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$serverBaseUrl/notes'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': id,
            'user_id': userId,
            'title': title,
            if (targetLanguage != null) 'target_language': targetLanguage,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode >= 300) {
      throw ApiException('createNote failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<String> uploadAudio({
    required String noteId,
    required String audioPath,
  }) async {
    final uri = Uri.parse('$serverBaseUrl/notes/$noteId/upload');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('audio', audioPath));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
    );
    final res = await http.Response.fromStream(streamedResponse);

    if (res.statusCode >= 300) {
      throw ApiException('uploadAudio failed (${res.statusCode}): ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['status'] as String? ?? 'uploaded';
  }

  Future<Map<String, dynamic>> getNote(String noteId) async {
    final res = await _client
        .get(Uri.parse('$serverBaseUrl/notes/$noteId'))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode >= 300) {
      throw ApiException('getNote failed (${res.statusCode}): ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// PATCH /notes/{id} — syncs a locally edited transcript back to the
  /// server. Best-effort by convention of this app's sync model: the
  /// caller should update locally first regardless of this call's outcome.
  Future<void> updateTranscript({
    required String noteId,
    required String transcript,
  }) async {
    final res = await _client
        .patch(
          Uri.parse('$serverBaseUrl/notes/$noteId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'transcript': transcript}),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode >= 300) {
      throw ApiException(
        'updateTranscript failed (${res.statusCode}): ${res.body}',
      );
    }
  }

  /// DELETE /notes/{id} — best-effort; the caller should delete locally
  /// regardless of whether this succeeds (e.g. offline), so a note the
  /// user deletes always disappears from their device immediately.
  Future<void> deleteNote(String noteId) async {
    final res = await _client
        .delete(Uri.parse('$serverBaseUrl/notes/$noteId'))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode >= 300 && res.statusCode != 404) {
      throw ApiException('deleteNote failed (${res.statusCode}): ${res.body}');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
