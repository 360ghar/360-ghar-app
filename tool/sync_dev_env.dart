// Syncs local `.env.development` (or `.env`) into a debug-only Dart map so
// bare `flutter run` works without --dart-define-from-file.
//
// Usage:
//   dart run tool/sync_dev_env.dart
//   dart run tool/sync_dev_env.dart --empty          # strip / CI
//   dart run tool/sync_dev_env.dart --check-clean    # pre-commit
//   dart run tool/sync_dev_env.dart path/to/.env
//
// Output: lib/core/config/dev_env.g.dart
// Never commit real secrets in that file.

import 'dart:io';

import 'env_parser.dart';

const _outputRelative = 'lib/core/config/dev_env.g.dart';
const _beginMarker = '// <dev-env:begin>';
const _endMarker = '// <dev-env:end>';

void main(List<String> args) {
  final empty = args.contains('--empty');
  final checkClean = args.contains('--check-clean');
  final pathArgs = args.where((a) => !a.startsWith('--')).toList();
  final preferred = pathArgs.isEmpty ? null : pathArgs.first;

  final outFile = File(_outputRelative);

  if (checkClean) {
    _checkClean(outFile);
    return;
  }

  if (empty) {
    _writeGenerated(outFile, const {});
    stdout.writeln('Wrote empty $_outputRelative (--empty)');
    return;
  }

  final envFile = resolveDevEnvFile(preferred: preferred);
  if (envFile == null) {
    _writeGenerated(outFile, const {});
    stderr.writeln(
      'No .env.development or .env found. Wrote empty $_outputRelative.\n'
      'Copy .env.development.example → .env.development and re-run:\n'
      '  dart run tool/sync_dev_env.dart',
    );
    return;
  }

  final values = parseEnvFile(envFile);
  _writeGenerated(outFile, values);
  stdout.writeln('Synced ${values.length} keys from ${envFile.path} → $_outputRelative');
}

void _checkClean(File outFile) {
  if (!outFile.existsSync()) {
    stdout.writeln('OK: $_outputRelative missing (treated as clean).');
    exit(0);
  }
  final content = outFile.readAsStringSync();
  final begin = content.indexOf(_beginMarker);
  final end = content.indexOf(_endMarker);
  if (begin < 0 || end < 0 || end <= begin) {
    stderr.writeln('ERROR: $_outputRelative missing markers; regenerate with --empty.');
    exit(1);
  }
  final body = content.substring(begin + _beginMarker.length, end).trim();
  final hasEntries = body
      .split('\n')
      .map((l) => l.trim())
      .any((l) => l.isNotEmpty && !l.startsWith('//') && l.contains(':'));
  if (hasEntries) {
    stderr.writeln(
      'ERROR: $_outputRelative contains generated secrets and must not be committed.\n'
      'Run: dart run tool/sync_dev_env.dart --empty\n'
      'Then unstage or restore the file before committing.\n'
      '(Local filled values are fine — just do not commit them.)',
    );
    exit(1);
  }
  stdout.writeln('OK: $_outputRelative is clean (no secrets).');
}

void _writeGenerated(File outFile, Map<String, String> values) {
  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE — do not edit by hand.')
    ..writeln('// Source: .env.development (or .env) via `dart run tool/sync_dev_env.dart`')
    ..writeln('//')
    ..writeln('// Debug-only fallback for bare `flutter run` without --dart-define-from-file.')
    ..writeln('// Release/profile builds ignore this map (see AppConfig + kDebugMode).')
    ..writeln('//')
    ..writeln('// Do NOT commit secrets. Pre-commit: dart run tool/sync_dev_env.dart --check-clean')
    ..writeln('')
    ..writeln('/// Compile-time debug env map. Empty in git; filled locally by sync_dev_env.')
    ..writeln('const Map<String, String> kDevEnv = {')
    ..writeln('  $_beginMarker');

  final keys = values.keys.toList()..sort();
  for (final key in keys) {
    final value = values[key]!;
    if (value.isEmpty) continue;
    buffer.writeln('  ${dartStringLiteral(key)}: ${dartStringLiteral(value)},');
  }

  buffer
    ..writeln('  $_endMarker')
    ..writeln('};')
    ..writeln('');

  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(buffer.toString());
}
