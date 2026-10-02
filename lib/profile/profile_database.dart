import 'package:drift/drift.dart';

part 'profile_database.g.dart';

@DriftDatabase(include: {'profile_schema.drift'})
class ProfileDatabase extends _$ProfileDatabase {
  ProfileDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      final existing = await customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      ).get();
      if (existing.isNotEmpty) {
        throw StateError(
          'Unversioned existing database; refusing to overwrite',
        );
      }
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      throw StateError('Unsupported profile schema $from -> $to');
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      final integrity = await customSelect('PRAGMA quick_check').get();
      if (integrity.length != 1 ||
          integrity.single.data.values.single != 'ok') {
        throw StateError('Profile database integrity check failed');
      }
      final violations = await customSelect('PRAGMA foreign_key_check').get();
      if (violations.isNotEmpty) {
        throw StateError('Profile database has foreign key violations');
      }
    },
  );
}
