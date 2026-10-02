import 'dart:io';

import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'storage_connection.dart';
import 'storage_lease.dart';

final class _NativeLease implements StorageLease {
  _NativeLease(this.file, this.path);
  static final _ownedPaths = <String>{};
  final RandomAccessFile file;
  final String path;
  @override
  bool isHeld = true;

  @override
  Future<void> release() async {
    if (!isHeld) return;
    isHeld = false;
    try {
      await file.unlock();
    } finally {
      await file.close();
      _ownedPaths.remove(path);
    }
  }
}

Future<StorageConnection> openStorageConnection({
  Directory? supportDirectory,
}) async {
  final directory = supportDirectory ?? await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final file = File('${directory.path}/conquest_profile.sqlite');
  final path = file.absolute.path;
  if (!_NativeLease._ownedPaths.add(path)) throw const StorageAlreadyOwned();
  RandomAccessFile lock;
  try {
    lock = await File('${file.path}.lock').open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.exclusive);
    } on FileSystemException {
      await lock.close();
      throw const StorageAlreadyOwned();
    }
  } catch (_) {
    _NativeLease._ownedPaths.remove(path);
    rethrow;
  }
  final lease = _NativeLease(lock, path);
  try {
    return StorageConnection(
      NativeDatabase.createInBackground(file),
      lease,
      'native-isolate',
    );
  } catch (_) {
    await lease.release();
    rethrow;
  }
}
