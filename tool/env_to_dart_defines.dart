// Converts a dotenv-style KEY=VALUE file into JSON for
// `flutter run --dart-define-from-file=...`.
//
// Usage:
//   dart run tool/env_to_dart_defines.dart .env.development > .dart_defines.json
//
// The output file should remain gitignored (see `.dart_defines*.json`).

import 'dart:convert';
import 'dart:io';

import 'env_parser.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/env_to_dart_defines.dart <env-file> [> .dart_defines.json]',
    );
    exit(64);
  }

  final path = args.first;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('File not found: $path');
    exit(66);
  }

  final map = parseEnvFile(file);
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(map));
}
