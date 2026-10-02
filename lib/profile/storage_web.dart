import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:drift/wasm.dart';
import 'package:web/web.dart' as web;

import 'storage_connection.dart';
import 'storage_lease.dart';

final class WebWriterLease implements StorageLease {
  WebWriterLease._();

  static const lockName = 'conquest_profile_writer_v1';
  final _released = Completer<JSAny?>();
  late final Future<JSAny?> _request;
  @override
  bool isHeld = false;

  static Future<WebWriterLease> acquire() async {
    if (!web.window.isSecureContext || !web.window.navigator.has('locks')) {
      throw const StorageUnavailable(
        'Web Locks requires a supported secure context',
      );
    }
    final lease = WebWriterLease._();
    final acquired = Completer<void>();
    lease._request = web.window.navigator.locks
        .request(
          lockName,
          web.LockOptions(mode: 'exclusive', ifAvailable: true),
          ((web.Lock? lock) {
            if (lock == null) {
              acquired.completeError(const StorageAlreadyOwned());
              return Future<JSAny?>.value(null).toJS;
            }
            lease.isHeld = true;
            acquired.complete();
            return lease._released.future.toJS;
          }).toJS,
        )
        .toDart;
    unawaited(
      lease._request.then<void>(
        (_) {
          lease.isHeld = false;
        },
        onError: (Object error, StackTrace trace) {
          lease.isHeld = false;
          if (!acquired.isCompleted) acquired.completeError(error, trace);
        },
      ),
    );
    await acquired.future;
    return lease;
  }

  @override
  Future<void> release() async {
    if (!_released.isCompleted) _released.complete(null);
    await _request;
    isHeld = false;
  }
}

Future<StorageConnection> openStorageConnection() async {
  final lease = await WebWriterLease.acquire();
  try {
    final base = Uri.parse(web.document.baseURI);
    final sqlite3Uri = base.resolve('sqlite3.wasm');
    final workerUri = base.resolve('drift_worker.js');
    await Future.wait([
      verifyStorageAsset(sqlite3Uri, {'application/wasm'}),
      verifyStorageAsset(workerUri, {
        'text/javascript',
        'application/javascript',
      }),
    ]);
    final result = await WasmDatabase.open(
      databaseName: 'conquest_profile',
      sqlite3Uri: sqlite3Uri,
      driftWorkerUri: workerUri,
    );
    if (result.chosenImplementation == WasmStorageImplementation.inMemory ||
        result.chosenImplementation ==
            WasmStorageImplementation.unsafeIndexedDb) {
      await result.resolvedExecutor.close();
      throw StorageUnavailable(
        'Unsupported persistence: ${result.chosenImplementation.name}',
      );
    }
    return StorageConnection(
      result.resolvedExecutor,
      lease,
      result.chosenImplementation.name,
    );
  } catch (_) {
    await lease.release();
    rethrow;
  }
}

Future<void> verifyStorageAsset(Uri uri, Set<String> contentTypes) async {
  final response = await web.window.fetch(uri.toString().toJS).toDart;
  final contentType = response.headers
      .get('content-type')
      ?.split(';')
      .first
      .trim();
  if (!response.ok || !contentTypes.contains(contentType)) {
    throw StorageUnavailable('Storage asset unavailable or wrong MIME: $uri');
  }
}
