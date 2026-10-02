abstract interface class StorageLease {
  bool get isHeld;
  Future<void> release();
}

final class StorageUnavailable implements Exception {
  const StorageUnavailable(this.message);
  final String message;

  @override
  String toString() => 'Storage unavailable: $message';
}

final class StorageAlreadyOwned implements Exception {
  const StorageAlreadyOwned();

  @override
  String toString() => 'Another execution owns this storage';
}
