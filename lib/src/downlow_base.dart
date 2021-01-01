import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;

class DownloadOptions {
  final ProgressDatabase progressDatabase;
  final ProgressCallback progressCallback;
  final File target;
  http.BaseClient httpClient;

  DownloadOptions({
    @required this.progressDatabase,
    @required this.progressCallback,
    @required this.target,
    this.httpClient,
  });
}

abstract class ProgressDatabase {
  Future<int> getProgress(String url);
  Future<void> setProgress(String url, int received);
}

class InMemoryProgressDatabase implements ProgressDatabase {
  final Map<String, int> _inner = {};

  @override
  Future<int> getProgress(String url) async {
    return _inner[url] ?? 0;
  }

  @override
  Future<void> setProgress(String url, int received) async {
    _inner[url] = received;
  }
}

class DownloadController {
  final StreamSubscription _inner;
  DownloadController._(StreamSubscription inner) : _inner = inner;

  void pause() {
    _inner.pause();
  }

  void resume() {
    _inner.resume();
  }

  void cancel() {
    _inner.cancel();
  }
}

/// Callback to listen the progress for receiving data.
///
/// [count] is the length of the bytes have been received.
/// [total] is the content length of the response/file body.
typedef ProgressCallback = void Function(int count, int total);

Future<DownloadController> download(String url, DownloadOptions options) async {
  final client = options.httpClient ?? http.Client();
  try {
    var lastProgress = await options.progressDatabase.getProgress(url);
    final request = http.Request('GET', Uri.parse(url));
    request.headers['Range'] = 'bytes=$lastProgress-';
    final target = await options.target.create(recursive: true);
    final response = await client.send(request);
    final total = response.contentLength ?? -1;
    final sink = await target.open(mode: FileMode.writeOnlyAppend);
    StreamSubscription subscription;
    subscription = response.stream.listen(
      (data) async {
        subscription.pause();
        await sink.writeFrom(data);
        final currentProgress = lastProgress + data.length;
        await options.progressDatabase.setProgress(url, currentProgress);
        lastProgress = currentProgress;
        options.progressCallback(currentProgress, total);
        subscription.resume();
      },
      onDone: () async {
        await sink.close();
        if (options.httpClient != null) {
          client.close();
        }
      },
    );
    return DownloadController._(subscription);
  } catch (e) {
    rethrow;
  }
}
