import 'package:drift/drift.dart';

part 'profile_database.g.dart';

enum ProfileUpgradeFaultPoint {
  beforeUpgrade,
  afterMatchColumn,
  afterAwardProfiles,
  beforeCommit,
  afterCommit,
}

@DriftDatabase(include: {'profile_schema.drift'})
class ProfileDatabase extends _$ProfileDatabase {
  ProfileDatabase(super.executor, {this.upgradeFaultHook});
  final Future<void> Function(ProfileUpgradeFaultPoint)? upgradeFaultHook;

  @override
  int get schemaVersion => 2;

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
      if (from == 1 && to == 2) {
        await upgradeFaultHook?.call(ProfileUpgradeFaultPoint.beforeUpgrade);
        await transaction(() async {
          await _validateSchema(
            allTables.where(
              (table) => table != awardProfiles && table != awardMatchStates,
            ),
            legacy: true,
          );
          await m.addColumn(matchRecords, matchRecords.awardRequired);
          await upgradeFaultHook?.call(
            ProfileUpgradeFaultPoint.afterMatchColumn,
          );
          await m.createTable(awardProfiles);
          await upgradeFaultHook?.call(
            ProfileUpgradeFaultPoint.afterAwardProfiles,
          );
          await m.createTable(awardMatchStates);
          // Interrupted opens must not leave v2 tables with a v1 version.
          await customStatement('PRAGMA user_version = 2');
          await upgradeFaultHook?.call(ProfileUpgradeFaultPoint.beforeCommit);
        });
        await upgradeFaultHook?.call(ProfileUpgradeFaultPoint.afterCommit);
        return;
      }
      throw StateError('Unsupported profile schema $from -> $to');
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _validateSchema(allTables);
    },
  );

  Future<void> _validateSchema(
    Iterable<TableInfo> expectedTables, {
    bool legacy = false,
  }) async {
    final tables = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    ).get();
    final names = tables.map((row) => row.read<String>('name')).toSet();
    if (names.length != expectedTables.length ||
        !names.containsAll(
          expectedTables.map((table) => table.actualTableName),
        )) {
      throw StateError('Unrecognized profile database tables');
    }
    for (final table in expectedTables) {
      final columns = await customSelect(
        'PRAGMA table_info("${table.actualTableName}")',
      ).get();
      final columnNames = columns
          .map((row) => row.read<String>('name'))
          .toSet();
      final expectedColumns = table.$columns
          .map((column) => column.name)
          .where(
            (name) =>
                !legacy || table != matchRecords || name != 'award_required',
          )
          .toSet();
      if (columnNames.length != expectedColumns.length ||
          !columnNames.containsAll(expectedColumns)) {
        throw StateError('Unrecognized profile database columns');
      }
    }
    final integrity = await customSelect('PRAGMA quick_check').get();
    if (integrity.length != 1 || integrity.single.data.values.single != 'ok') {
      throw StateError('Profile database integrity check failed');
    }
    final violations = await customSelect('PRAGMA foreign_key_check').get();
    if (violations.isNotEmpty) {
      throw StateError('Profile database has foreign key violations');
    }
  }
}
