import 'storage_connection.dart';
import 'storage_lease.dart';

Future<StorageConnection> openStorageConnection() async =>
    throw const StorageUnavailable('Unsupported platform');
