import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;

class DownloadOptions {
  final ProgressDatabase progressDatabase;
  final File target;
  final deleteOnCancel;

  http.BaseClient httpClient;
  void Function() onDone;
  ProgressCallback progressCallback;

  DownloadOptions({
    @required this.progressDatabase,
    @required this.target,
    this.deleteOnCancel = false,
    this.httpClient,
    this.onDone,
    this.progressCallback,
  });
}

abstract class ProgressDatabase {
  Future<int> getProgress(String url);
  Future<void> setProgress(String url, int received);

  Future<void> resetProgress(String url) async {
    await setProgress(url, 0);
  }
}

class InMemoryProgressDatabase extends ProgressDatabase {
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
  StreamSubscription _inner;
  final DownloadOptions _options;
  final String _url;
  bool isCancelled = false;
  bool isDownloading = true;

  DownloadController._(
    StreamSubscription inner,
    DownloadOptions options,
    String url,
  )   : _inner = inner,
        _options = options,
        _url = url;

  Future<void> pause() async {
    _checkIfStillValid();
    if (isDownloading) {
      await _inner.cancel();
      isDownloading = false;
    }
  }

  Future<void> resume() async {
    _checkIfStillValid();
    if (isDownloading) {
      return;
    }
    _inner = await _download(_url, _options);
  }

  Future<void> cancel() async {
    _checkIfStillValid();
    await _inner.cancel();
    await _options.progressDatabase.resetProgress(_url);
    if (_options.deleteOnCancel) {
      await _options.target.delete();
    }
    isCancelled = true;
  }

  void _checkIfStillValid() {
    if (isCancelled) throw StateError('Already cancelled');
  }
}

/// Callback to listen the progress for receiving data.
///
/// [count] is the length of the bytes have been received.
/// [total] is the content length of the response/file body.
typedef ProgressCallback = void Function(int count, int total);

Future<DownloadController> download(
  String url,
  DownloadOptions options,
) async {
  try {
    final subscription = await _download(url, options);
    return DownloadController._(subscription, options, url);
  } catch (e) {
    rethrow;
  }
}

Future<StreamSubscription> _download(
  String url,
  DownloadOptions options,
) async {
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
        options.progressCallback?.call(currentProgress, total);
        subscription.resume();
      },
      onDone: () async {
        options.onDone?.call();
        await sink.close();
        if (options.httpClient != null) {
          client.close();
        }
      },
    );
    return subscription;
  } catch (e) {
    rethrow;
  }
}
