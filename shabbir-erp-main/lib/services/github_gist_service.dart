import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_service.dart';

class GithubGistService {
  static const _apiBase = 'https://api.github.com';
  static const _filename = 'shabbir_erp_backup.json';

  static Future<String> backup(String token) async {
    final data = await DatabaseService.instance.exportToJson();
    final body = jsonEncode({
      'description': 'Shabbir ERP Backup - ${DateTime.now().toIso8601String()}',
      'public': false,
      'files': {
        _filename: {'content': data}
      }
    });

    final res = await http.post(
      Uri.parse('$_apiBase/gists'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.github+json',
      },
      body: body,
    );

    if (res.statusCode == 201) {
      final json = jsonDecode(res.body);
      return json['id'] as String;
    }
    throw Exception('Backup failed: ${res.statusCode} — Token galat hai ya internet nahi hai.');
  }

  static Future<void> restore(String token, String gistId) async {
    final res = await http.get(
      Uri.parse('$_apiBase/gists/$gistId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
      },
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final files = json['files'] as Map<String, dynamic>;
      final file = files[_filename] ?? files.values.first;
      String content = file['content'] as String? ?? '';
      if (content.isEmpty && file['truncated'] == true) {
        final rawUrl = file['raw_url'] as String;
        final raw = await http.get(Uri.parse(rawUrl));
        content = raw.body;
      }
      await DatabaseService.instance.importFromJson(content);
      return;
    }
    throw Exception('Restore failed: ${res.statusCode} — Gist ID ya token galat hai.');
  }
}
