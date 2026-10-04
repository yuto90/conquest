import 'drift_profile_store.dart';
import '../awards/award_storage.dart';
import 'match_contracts.dart';
import 'profile_database.dart';
import 'storage_unsupported.dart'
    if (dart.library.io) 'storage_native.dart'
    if (dart.library.js_interop) 'storage_web.dart';

/// Root owns one session; opening does not read or migrate legacy XP.
final class ProfileStorage {
  ProfileStorage._(this.store, this.implementation);
  final DriftProfileStore store;
  final String implementation;

  static Future<ProfileStorage> open({required String executionId}) async {
    requireUuid(executionId, 'executionId');
    final connection = await openStorageConnection();
    final database = ProfileDatabase(connection.executor);
    try {
      await database.select(database.storageMeta).get();
      return ProfileStorage._(
        DriftProfileStore(
          database: database,
          executionId: executionId,
          lease: connection.lease,
          legacyAwards: SharedPreferencesAwardStorage(),
        ),
        connection.implementation,
      );
    } catch (_) {
      try {
        await database.close();
      } finally {
        await connection.lease.release();
      }
      rethrow;
    }
  }

  Future<void> close() => store.close();
}
