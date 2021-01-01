import 'dart:io';

import 'package:downlow/downlow.dart';
import 'package:test/test.dart';

void main() {
  group('happy path', () {
    test('First Test', () async {
      final target = File('/tmp/test.jpg');
      final options = DownloadOptions(
        progressCallback: (current, total) {
          final progress = (current / total) * 100;
          print('Downloading: $progress');
        },
        target: target,
        progressDatabase: InMemoryProgressDatabase(),
      );
      await download('https://i.imgur.com/z4d4kWk.jpg', options);
      expect(target.existsSync(), true);
    });
  });
}
