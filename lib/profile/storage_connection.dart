import 'package:drift/drift.dart';

import 'storage_lease.dart';

final class StorageConnection {
  const StorageConnection(this.executor, this.lease, this.implementation);

  final QueryExecutor executor;
  final StorageLease lease;
  final String implementation;
}
