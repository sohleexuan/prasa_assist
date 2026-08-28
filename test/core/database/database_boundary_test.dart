import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UI and controllers do not import raw SQLite APIs', () async {
    final violations = <String>[];
    await for (final entity in Directory('lib').list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final path = entity.path.replaceAll('\\', '/');
      final isBoundaryFile =
          path.contains('/screens/') ||
          path.contains('/widgets/') ||
          path.contains('/controllers/');
      if (!isBoundaryFile) {
        continue;
      }
      final contents = await entity.readAsString();
      if (contents.contains('package:sqflite')) {
        violations.add(path);
      }
    }

    expect(violations, isEmpty);
  });
}
