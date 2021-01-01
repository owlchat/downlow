# Downlow

Tiny, Lightwight and Fast file downloads in pure Dart.

Supports Full control over the download progress (pause, resume, cancel, and get progress feedback)

## Usage

A simple usage example:

```dart
import 'dart:io';

import 'package:downlow/downlow.dart';

Future<void> main() async {
  final target = File('/tmp/cat.jpg');
  final options = DownloadOptions(
    progressCallback: (current, total) {
      final progress = (current / total) * 100;
      print('Downloading: $progress');
    },
    target: target,
    progressDatabase: InMemoryProgressDatabase(),
  );
  final controller = await download('https://i.imgur.com/z4d4kWk.jpg', options);
  controller.pause(); // to pause the download.
  controller.resume(); // to resume the download.
  controller.cancel(); // to cancel the download.
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: http://example.com/issues/replaceme
