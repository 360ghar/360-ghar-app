import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every file in assets/fonts/sources.json matches its recorded size and SHA-256', () {
    final manifest = jsonDecode(File('assets/fonts/sources.json').readAsStringSync()) as Map;
    final files = (manifest['files'] as List).cast<Map<String, dynamic>>();
    expect(files, isNotEmpty);
    for (final entry in files) {
      final path = entry['path'] as String;
      final bytes = File(path).readAsBytesSync();
      expect(bytes.length, entry['bytes'], reason: '$path size');
      expect(sha256.convert(bytes).toString(), entry['sha256'], reason: '$path sha256');
    }
  });
}
