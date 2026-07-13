// Shared dotenv-style parser for local tooling.
// Used by env_to_dart_defines.dart and sync_dev_env.dart.

import 'dart:io';

/// Parses a KEY=VALUE env file into a map. Ignores blanks and `#` comments.
Map<String, String> parseEnvFile(File file) {
  final map = <String, String>{};
  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    final key = line.substring(0, eq).trim();
    var value = line.substring(eq + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    map[key] = value;
  }
  return map;
}

/// Resolves the preferred local env file for development.
///
/// Order: explicit [preferred], then `.env.development`, then `.env`.
File? resolveDevEnvFile({String? preferred, Directory? root}) {
  final base = root ?? Directory.current;
  final candidates = <String>[
    if (preferred != null && preferred.isNotEmpty) preferred,
    '.env.development',
    '.env',
  ];
  for (final name in candidates) {
    final file = File('${base.path}${Platform.pathSeparator}$name');
    if (file.existsSync()) return file;
  }
  return null;
}

/// Dart string literal with proper escaping for generated source.
String dartStringLiteral(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\$', r'\$');
  return "'$escaped'";
}
