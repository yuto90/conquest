import 'dart:io';

import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'storage_connection.dart';
import 'storage_lease.dart';

final class _NativeLease implements StorageLease {
  _NativeLease(this.file);
  final RandomAccessFile file;
  @override
  bool isHeld = true;

  @override
  Future<void> release() async {
    if (!isHeld) return;
    isHeld = false;
    await file.unlock();
    await file.close();
  }
}

Future<StorageConnection> openStorageConnection() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final file = File('${directory.path}/conquest_profile.sqlite');
  final lock = await File('${file.path}.lock').open(mode: FileMode.append);
  try {
    await lock.lock(FileLock.exclusive);
  } on FileSystemException {
    await lock.close();
    throw const StorageAlreadyOwned();
  }
  final lease = _NativeLease(lock);
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
