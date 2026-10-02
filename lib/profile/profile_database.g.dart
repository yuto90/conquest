// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_database.dart';

// ignore_for_file: type=lint
class Profiles extends Table with TableInfo<Profiles, Profile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Profiles(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL PRIMARY KEY CHECK (length(profile_id) = 36 AND profile_id = lower(profile_id))',
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'CHECK (display_name IS NULL OR length(trim(display_name)) > 0)',
  );
  static const VerificationMeta _avatarKeyMeta = const VerificationMeta(
    'avatarKey',
  );
  late final GeneratedColumn<String> avatarKey = GeneratedColumn<String>(
    'avatar_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (avatar_key IN (\'island_01\', \'island_02\', \'island_03\', \'island_04\'))',
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _statsStartedAtUtcMeta = const VerificationMeta(
    'statsStartedAtUtc',
  );
  late final GeneratedColumn<int> statsStartedAtUtc = GeneratedColumn<int>(
    'stats_started_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    displayName,
    avatarKey,
    createdAtUtc,
    updatedAtUtc,
    statsStartedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Profile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('avatar_key')) {
      context.handle(
        _avatarKeyMeta,
        avatarKey.isAcceptableOrUnknown(data['avatar_key']!, _avatarKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_avatarKeyMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    if (data.containsKey('stats_started_at_utc')) {
      context.handle(
        _statsStartedAtUtcMeta,
        statsStartedAtUtc.isAcceptableOrUnknown(
          data['stats_started_at_utc']!,
          _statsStartedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_statsStartedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId};
  @override
  Profile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Profile(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      avatarKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_key'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
      statsStartedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stats_started_at_utc'],
      )!,
    );
  }

  @override
  Profiles createAlias(String alias) {
    return Profiles(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Profile extends DataClass implements Insertable<Profile> {
  final String profileId;
  final String? displayName;
  final String avatarKey;
  final int createdAtUtc;
  final int updatedAtUtc;
  final int statsStartedAtUtc;
  const Profile({
    required this.profileId,
    this.displayName,
    required this.avatarKey,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.statsStartedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['avatar_key'] = Variable<String>(avatarKey);
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    map['stats_started_at_utc'] = Variable<int>(statsStartedAtUtc);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      profileId: Value(profileId),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      avatarKey: Value(avatarKey),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
      statsStartedAtUtc: Value(statsStartedAtUtc),
    );
  }

  factory Profile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Profile(
      profileId: serializer.fromJson<String>(json['profile_id']),
      displayName: serializer.fromJson<String?>(json['display_name']),
      avatarKey: serializer.fromJson<String>(json['avatar_key']),
      createdAtUtc: serializer.fromJson<int>(json['created_at_utc']),
      updatedAtUtc: serializer.fromJson<int>(json['updated_at_utc']),
      statsStartedAtUtc: serializer.fromJson<int>(json['stats_started_at_utc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profile_id': serializer.toJson<String>(profileId),
      'display_name': serializer.toJson<String?>(displayName),
      'avatar_key': serializer.toJson<String>(avatarKey),
      'created_at_utc': serializer.toJson<int>(createdAtUtc),
      'updated_at_utc': serializer.toJson<int>(updatedAtUtc),
      'stats_started_at_utc': serializer.toJson<int>(statsStartedAtUtc),
    };
  }

  Profile copyWith({
    String? profileId,
    Value<String?> displayName = const Value.absent(),
    String? avatarKey,
    int? createdAtUtc,
    int? updatedAtUtc,
    int? statsStartedAtUtc,
  }) => Profile(
    profileId: profileId ?? this.profileId,
    displayName: displayName.present ? displayName.value : this.displayName,
    avatarKey: avatarKey ?? this.avatarKey,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    statsStartedAtUtc: statsStartedAtUtc ?? this.statsStartedAtUtc,
  );
  Profile copyWithCompanion(ProfilesCompanion data) {
    return Profile(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      avatarKey: data.avatarKey.present ? data.avatarKey.value : this.avatarKey,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
      statsStartedAtUtc: data.statsStartedAtUtc.present
          ? data.statsStartedAtUtc.value
          : this.statsStartedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Profile(')
          ..write('profileId: $profileId, ')
          ..write('displayName: $displayName, ')
          ..write('avatarKey: $avatarKey, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('statsStartedAtUtc: $statsStartedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    displayName,
    avatarKey,
    createdAtUtc,
    updatedAtUtc,
    statsStartedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.profileId == this.profileId &&
          other.displayName == this.displayName &&
          other.avatarKey == this.avatarKey &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc &&
          other.statsStartedAtUtc == this.statsStartedAtUtc);
}

class ProfilesCompanion extends UpdateCompanion<Profile> {
  final Value<String> profileId;
  final Value<String?> displayName;
  final Value<String> avatarKey;
  final Value<int> createdAtUtc;
  final Value<int> updatedAtUtc;
  final Value<int> statsStartedAtUtc;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.profileId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.avatarKey = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.statsStartedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String profileId,
    this.displayName = const Value.absent(),
    required String avatarKey,
    required int createdAtUtc,
    required int updatedAtUtc,
    required int statsStartedAtUtc,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       avatarKey = Value(avatarKey),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc),
       statsStartedAtUtc = Value(statsStartedAtUtc);
  static Insertable<Profile> custom({
    Expression<String>? profileId,
    Expression<String>? displayName,
    Expression<String>? avatarKey,
    Expression<int>? createdAtUtc,
    Expression<int>? updatedAtUtc,
    Expression<int>? statsStartedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (displayName != null) 'display_name': displayName,
      if (avatarKey != null) 'avatar_key': avatarKey,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (statsStartedAtUtc != null) 'stats_started_at_utc': statsStartedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? profileId,
    Value<String?>? displayName,
    Value<String>? avatarKey,
    Value<int>? createdAtUtc,
    Value<int>? updatedAtUtc,
    Value<int>? statsStartedAtUtc,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      profileId: profileId ?? this.profileId,
      displayName: displayName ?? this.displayName,
      avatarKey: avatarKey ?? this.avatarKey,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      statsStartedAtUtc: statsStartedAtUtc ?? this.statsStartedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (avatarKey.present) {
      map['avatar_key'] = Variable<String>(avatarKey.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (statsStartedAtUtc.present) {
      map['stats_started_at_utc'] = Variable<int>(statsStartedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('profileId: $profileId, ')
          ..write('displayName: $displayName, ')
          ..write('avatarKey: $avatarKey, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('statsStartedAtUtc: $statsStartedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class MatchRecords extends Table with TableInfo<MatchRecords, MatchRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  MatchRecords(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL PRIMARY KEY CHECK (length(match_id) = 36 AND match_id = lower(match_id))',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES profiles(profile_id)',
  );
  static const VerificationMeta _executionIdMeta = const VerificationMeta(
    'executionId',
  );
  late final GeneratedColumn<String> executionId = GeneratedColumn<String>(
    'execution_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (length(execution_id) = 36 AND execution_id = lower(execution_id))',
  );
  static const VerificationMeta _sessionKindMeta = const VerificationMeta(
    'sessionKind',
  );
  late final GeneratedColumn<String> sessionKind = GeneratedColumn<String>(
    'session_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (session_kind = \'normal\')',
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (origin = \'gameplay\')',
  );
  static const VerificationMeta _gameModeMeta = const VerificationMeta(
    'gameMode',
  );
  late final GeneratedColumn<String> gameMode = GeneratedColumn<String>(
    'game_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (game_mode = \'player_vs_cpu\')',
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  late final GeneratedColumn<String> difficulty = GeneratedColumn<String>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (difficulty IN (\'very_easy\', \'easy\', \'normal\', \'hard\'))',
  );
  static const VerificationMeta _playerCpuDifficultyMeta =
      const VerificationMeta('playerCpuDifficulty');
  late final GeneratedColumn<String>
  playerCpuDifficulty = GeneratedColumn<String>(
    'player_cpu_difficulty',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (player_cpu_difficulty IN (\'very_easy\', \'easy\', \'normal\', \'hard\'))',
  );
  static const VerificationMeta _islandCountMeta = const VerificationMeta(
    'islandCount',
  );
  late final GeneratedColumn<int> islandCount = GeneratedColumn<int>(
    'island_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (island_count BETWEEN 8 AND 16)',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (status IN (\'in_progress\', \'completed\', \'abandoned\', \'interrupted\'))',
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (outcome IN (\'win\', \'loss\', \'draw\'))',
  );
  static const VerificationMeta _startedAtUtcMeta = const VerificationMeta(
    'startedAtUtc',
  );
  late final GeneratedColumn<int> startedAtUtc = GeneratedColumn<int>(
    'started_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _endedAtUtcMeta = const VerificationMeta(
    'endedAtUtc',
  );
  late final GeneratedColumn<int> endedAtUtc = GeneratedColumn<int>(
    'ended_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _recoveredAtUtcMeta = const VerificationMeta(
    'recoveredAtUtc',
  );
  late final GeneratedColumn<int> recoveredAtUtc = GeneratedColumn<int>(
    'recovered_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _elapsedMsMeta = const VerificationMeta(
    'elapsedMs',
  );
  late final GeneratedColumn<int> elapsedMs = GeneratedColumn<int>(
    'elapsed_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (elapsed_ms >= 0)',
  );
  static const VerificationMeta _dispatchCountMeta = const VerificationMeta(
    'dispatchCount',
  );
  late final GeneratedColumn<int> dispatchCount = GeneratedColumn<int>(
    'dispatch_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (dispatch_count >= 0)',
  );
  static const VerificationMeta _forcesSentMeta = const VerificationMeta(
    'forcesSent',
  );
  late final GeneratedColumn<int> forcesSent = GeneratedColumn<int>(
    'forces_sent',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (forces_sent >= 0)',
  );
  static const VerificationMeta _capturesMeta = const VerificationMeta(
    'captures',
  );
  late final GeneratedColumn<int> captures = GeneratedColumn<int>(
    'captures',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (captures >= 0)',
  );
  static const VerificationMeta _appVersionMeta = const VerificationMeta(
    'appVersion',
  );
  late final GeneratedColumn<String> appVersion = GeneratedColumn<String>(
    'app_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(app_version)) > 0)',
  );
  static const VerificationMeta _rulesVersionMeta = const VerificationMeta(
    'rulesVersion',
  );
  late final GeneratedColumn<String> rulesVersion = GeneratedColumn<String>(
    'rules_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(rules_version)) > 0)',
  );
  static const VerificationMeta _metricsVersionMeta = const VerificationMeta(
    'metricsVersion',
  );
  late final GeneratedColumn<int> metricsVersion = GeneratedColumn<int>(
    'metrics_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (metrics_version >= 1)',
  );
  static const VerificationMeta _receiptXpMeta = const VerificationMeta(
    'receiptXp',
  );
  late final GeneratedColumn<int> receiptXp = GeneratedColumn<int>(
    'receipt_xp',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (receipt_xp >= 0)',
  );
  static const VerificationMeta _receiptBeforeMeta = const VerificationMeta(
    'receiptBefore',
  );
  late final GeneratedColumn<int> receiptBefore = GeneratedColumn<int>(
    'receipt_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (receipt_before >= 0)',
  );
  static const VerificationMeta _receiptAfterMeta = const VerificationMeta(
    'receiptAfter',
  );
  late final GeneratedColumn<int> receiptAfter = GeneratedColumn<int>(
    'receipt_after',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (receipt_after >= 0)',
  );
  static const VerificationMeta _receiptRewardVersionMeta =
      const VerificationMeta('receiptRewardVersion');
  late final GeneratedColumn<String> receiptRewardVersion =
      GeneratedColumn<String>(
        'receipt_reward_version',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  @override
  List<GeneratedColumn> get $columns => [
    matchId,
    profileId,
    executionId,
    sessionKind,
    origin,
    gameMode,
    difficulty,
    playerCpuDifficulty,
    islandCount,
    status,
    outcome,
    startedAtUtc,
    endedAtUtc,
    recoveredAtUtc,
    elapsedMs,
    dispatchCount,
    forcesSent,
    captures,
    appVersion,
    rulesVersion,
    metricsVersion,
    receiptXp,
    receiptBefore,
    receiptAfter,
    receiptRewardVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('execution_id')) {
      context.handle(
        _executionIdMeta,
        executionId.isAcceptableOrUnknown(
          data['execution_id']!,
          _executionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_executionIdMeta);
    }
    if (data.containsKey('session_kind')) {
      context.handle(
        _sessionKindMeta,
        sessionKind.isAcceptableOrUnknown(
          data['session_kind']!,
          _sessionKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sessionKindMeta);
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    } else if (isInserting) {
      context.missing(_originMeta);
    }
    if (data.containsKey('game_mode')) {
      context.handle(
        _gameModeMeta,
        gameMode.isAcceptableOrUnknown(data['game_mode']!, _gameModeMeta),
      );
    } else if (isInserting) {
      context.missing(_gameModeMeta);
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    } else if (isInserting) {
      context.missing(_difficultyMeta);
    }
    if (data.containsKey('player_cpu_difficulty')) {
      context.handle(
        _playerCpuDifficultyMeta,
        playerCpuDifficulty.isAcceptableOrUnknown(
          data['player_cpu_difficulty']!,
          _playerCpuDifficultyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_playerCpuDifficultyMeta);
    }
    if (data.containsKey('island_count')) {
      context.handle(
        _islandCountMeta,
        islandCount.isAcceptableOrUnknown(
          data['island_count']!,
          _islandCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_islandCountMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    }
    if (data.containsKey('started_at_utc')) {
      context.handle(
        _startedAtUtcMeta,
        startedAtUtc.isAcceptableOrUnknown(
          data['started_at_utc']!,
          _startedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtUtcMeta);
    }
    if (data.containsKey('ended_at_utc')) {
      context.handle(
        _endedAtUtcMeta,
        endedAtUtc.isAcceptableOrUnknown(
          data['ended_at_utc']!,
          _endedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('recovered_at_utc')) {
      context.handle(
        _recoveredAtUtcMeta,
        recoveredAtUtc.isAcceptableOrUnknown(
          data['recovered_at_utc']!,
          _recoveredAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('elapsed_ms')) {
      context.handle(
        _elapsedMsMeta,
        elapsedMs.isAcceptableOrUnknown(data['elapsed_ms']!, _elapsedMsMeta),
      );
    }
    if (data.containsKey('dispatch_count')) {
      context.handle(
        _dispatchCountMeta,
        dispatchCount.isAcceptableOrUnknown(
          data['dispatch_count']!,
          _dispatchCountMeta,
        ),
      );
    }
    if (data.containsKey('forces_sent')) {
      context.handle(
        _forcesSentMeta,
        forcesSent.isAcceptableOrUnknown(data['forces_sent']!, _forcesSentMeta),
      );
    }
    if (data.containsKey('captures')) {
      context.handle(
        _capturesMeta,
        captures.isAcceptableOrUnknown(data['captures']!, _capturesMeta),
      );
    }
    if (data.containsKey('app_version')) {
      context.handle(
        _appVersionMeta,
        appVersion.isAcceptableOrUnknown(data['app_version']!, _appVersionMeta),
      );
    } else if (isInserting) {
      context.missing(_appVersionMeta);
    }
    if (data.containsKey('rules_version')) {
      context.handle(
        _rulesVersionMeta,
        rulesVersion.isAcceptableOrUnknown(
          data['rules_version']!,
          _rulesVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rulesVersionMeta);
    }
    if (data.containsKey('metrics_version')) {
      context.handle(
        _metricsVersionMeta,
        metricsVersion.isAcceptableOrUnknown(
          data['metrics_version']!,
          _metricsVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_metricsVersionMeta);
    }
    if (data.containsKey('receipt_xp')) {
      context.handle(
        _receiptXpMeta,
        receiptXp.isAcceptableOrUnknown(data['receipt_xp']!, _receiptXpMeta),
      );
    }
    if (data.containsKey('receipt_before')) {
      context.handle(
        _receiptBeforeMeta,
        receiptBefore.isAcceptableOrUnknown(
          data['receipt_before']!,
          _receiptBeforeMeta,
        ),
      );
    }
    if (data.containsKey('receipt_after')) {
      context.handle(
        _receiptAfterMeta,
        receiptAfter.isAcceptableOrUnknown(
          data['receipt_after']!,
          _receiptAfterMeta,
        ),
      );
    }
    if (data.containsKey('receipt_reward_version')) {
      context.handle(
        _receiptRewardVersionMeta,
        receiptRewardVersion.isAcceptableOrUnknown(
          data['receipt_reward_version']!,
          _receiptRewardVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {matchId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {matchId, profileId},
  ];
  @override
  MatchRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchRecord(
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      executionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}execution_id'],
      )!,
      sessionKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_kind'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      gameMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_mode'],
      )!,
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}difficulty'],
      )!,
      playerCpuDifficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_cpu_difficulty'],
      )!,
      islandCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}island_count'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      ),
      startedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_utc'],
      )!,
      endedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at_utc'],
      ),
      recoveredAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recovered_at_utc'],
      ),
      elapsedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_ms'],
      ),
      dispatchCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dispatch_count'],
      ),
      forcesSent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}forces_sent'],
      ),
      captures: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captures'],
      ),
      appVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app_version'],
      )!,
      rulesVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rules_version'],
      )!,
      metricsVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}metrics_version'],
      )!,
      receiptXp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}receipt_xp'],
      ),
      receiptBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}receipt_before'],
      ),
      receiptAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}receipt_after'],
      ),
      receiptRewardVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_reward_version'],
      ),
    );
  }

  @override
  MatchRecords createAlias(String alias) {
    return MatchRecords(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'UNIQUE(match_id, profile_id)',
    'CHECK((status = \'in_progress\' AND outcome IS NULL AND ended_at_utc IS NULL AND recovered_at_utc IS NULL AND elapsed_ms IS NULL AND dispatch_count IS NULL AND forces_sent IS NULL AND captures IS NULL AND receipt_xp IS NULL AND receipt_before IS NULL AND receipt_after IS NULL AND receipt_reward_version IS NULL)OR(status IN (\'completed\', \'abandoned\', \'interrupted\') AND receipt_xp IS NOT NULL AND receipt_before IS NOT NULL AND receipt_after IS NOT NULL AND receipt_reward_version IS NOT NULL AND length(trim(receipt_reward_version)) > 0 AND receipt_after = receipt_before + receipt_xp AND(outcome IS \'win\' OR receipt_xp = 0)AND((status = \'completed\' AND outcome IS NOT NULL AND ended_at_utc IS NOT NULL AND recovered_at_utc IS NULL AND elapsed_ms IS NOT NULL AND dispatch_count IS NOT NULL AND forces_sent IS NOT NULL AND captures IS NOT NULL)OR(status = \'abandoned\' AND outcome IS NULL AND ended_at_utc IS NOT NULL AND recovered_at_utc IS NULL AND elapsed_ms IS NOT NULL AND dispatch_count IS NOT NULL AND forces_sent IS NOT NULL AND captures IS NOT NULL)OR(status = \'interrupted\' AND outcome IS NULL AND ended_at_utc IS NULL AND recovered_at_utc IS NOT NULL AND elapsed_ms IS NULL AND dispatch_count IS NULL AND forces_sent IS NULL AND captures IS NULL))))',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class MatchRecord extends DataClass implements Insertable<MatchRecord> {
  final String matchId;
  final String profileId;
  final String executionId;
  final String sessionKind;
  final String origin;
  final String gameMode;
  final String difficulty;
  final String playerCpuDifficulty;
  final int islandCount;
  final String status;
  final String? outcome;
  final int startedAtUtc;
  final int? endedAtUtc;
  final int? recoveredAtUtc;
  final int? elapsedMs;
  final int? dispatchCount;
  final int? forcesSent;
  final int? captures;
  final String appVersion;
  final String rulesVersion;
  final int metricsVersion;
  final int? receiptXp;
  final int? receiptBefore;
  final int? receiptAfter;
  final String? receiptRewardVersion;
  const MatchRecord({
    required this.matchId,
    required this.profileId,
    required this.executionId,
    required this.sessionKind,
    required this.origin,
    required this.gameMode,
    required this.difficulty,
    required this.playerCpuDifficulty,
    required this.islandCount,
    required this.status,
    this.outcome,
    required this.startedAtUtc,
    this.endedAtUtc,
    this.recoveredAtUtc,
    this.elapsedMs,
    this.dispatchCount,
    this.forcesSent,
    this.captures,
    required this.appVersion,
    required this.rulesVersion,
    required this.metricsVersion,
    this.receiptXp,
    this.receiptBefore,
    this.receiptAfter,
    this.receiptRewardVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['match_id'] = Variable<String>(matchId);
    map['profile_id'] = Variable<String>(profileId);
    map['execution_id'] = Variable<String>(executionId);
    map['session_kind'] = Variable<String>(sessionKind);
    map['origin'] = Variable<String>(origin);
    map['game_mode'] = Variable<String>(gameMode);
    map['difficulty'] = Variable<String>(difficulty);
    map['player_cpu_difficulty'] = Variable<String>(playerCpuDifficulty);
    map['island_count'] = Variable<int>(islandCount);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || outcome != null) {
      map['outcome'] = Variable<String>(outcome);
    }
    map['started_at_utc'] = Variable<int>(startedAtUtc);
    if (!nullToAbsent || endedAtUtc != null) {
      map['ended_at_utc'] = Variable<int>(endedAtUtc);
    }
    if (!nullToAbsent || recoveredAtUtc != null) {
      map['recovered_at_utc'] = Variable<int>(recoveredAtUtc);
    }
    if (!nullToAbsent || elapsedMs != null) {
      map['elapsed_ms'] = Variable<int>(elapsedMs);
    }
    if (!nullToAbsent || dispatchCount != null) {
      map['dispatch_count'] = Variable<int>(dispatchCount);
    }
    if (!nullToAbsent || forcesSent != null) {
      map['forces_sent'] = Variable<int>(forcesSent);
    }
    if (!nullToAbsent || captures != null) {
      map['captures'] = Variable<int>(captures);
    }
    map['app_version'] = Variable<String>(appVersion);
    map['rules_version'] = Variable<String>(rulesVersion);
    map['metrics_version'] = Variable<int>(metricsVersion);
    if (!nullToAbsent || receiptXp != null) {
      map['receipt_xp'] = Variable<int>(receiptXp);
    }
    if (!nullToAbsent || receiptBefore != null) {
      map['receipt_before'] = Variable<int>(receiptBefore);
    }
    if (!nullToAbsent || receiptAfter != null) {
      map['receipt_after'] = Variable<int>(receiptAfter);
    }
    if (!nullToAbsent || receiptRewardVersion != null) {
      map['receipt_reward_version'] = Variable<String>(receiptRewardVersion);
    }
    return map;
  }

  MatchRecordsCompanion toCompanion(bool nullToAbsent) {
    return MatchRecordsCompanion(
      matchId: Value(matchId),
      profileId: Value(profileId),
      executionId: Value(executionId),
      sessionKind: Value(sessionKind),
      origin: Value(origin),
      gameMode: Value(gameMode),
      difficulty: Value(difficulty),
      playerCpuDifficulty: Value(playerCpuDifficulty),
      islandCount: Value(islandCount),
      status: Value(status),
      outcome: outcome == null && nullToAbsent
          ? const Value.absent()
          : Value(outcome),
      startedAtUtc: Value(startedAtUtc),
      endedAtUtc: endedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAtUtc),
      recoveredAtUtc: recoveredAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(recoveredAtUtc),
      elapsedMs: elapsedMs == null && nullToAbsent
          ? const Value.absent()
          : Value(elapsedMs),
      dispatchCount: dispatchCount == null && nullToAbsent
          ? const Value.absent()
          : Value(dispatchCount),
      forcesSent: forcesSent == null && nullToAbsent
          ? const Value.absent()
          : Value(forcesSent),
      captures: captures == null && nullToAbsent
          ? const Value.absent()
          : Value(captures),
      appVersion: Value(appVersion),
      rulesVersion: Value(rulesVersion),
      metricsVersion: Value(metricsVersion),
      receiptXp: receiptXp == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptXp),
      receiptBefore: receiptBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptBefore),
      receiptAfter: receiptAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptAfter),
      receiptRewardVersion: receiptRewardVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptRewardVersion),
    );
  }

  factory MatchRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchRecord(
      matchId: serializer.fromJson<String>(json['match_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      executionId: serializer.fromJson<String>(json['execution_id']),
      sessionKind: serializer.fromJson<String>(json['session_kind']),
      origin: serializer.fromJson<String>(json['origin']),
      gameMode: serializer.fromJson<String>(json['game_mode']),
      difficulty: serializer.fromJson<String>(json['difficulty']),
      playerCpuDifficulty: serializer.fromJson<String>(
        json['player_cpu_difficulty'],
      ),
      islandCount: serializer.fromJson<int>(json['island_count']),
      status: serializer.fromJson<String>(json['status']),
      outcome: serializer.fromJson<String?>(json['outcome']),
      startedAtUtc: serializer.fromJson<int>(json['started_at_utc']),
      endedAtUtc: serializer.fromJson<int?>(json['ended_at_utc']),
      recoveredAtUtc: serializer.fromJson<int?>(json['recovered_at_utc']),
      elapsedMs: serializer.fromJson<int?>(json['elapsed_ms']),
      dispatchCount: serializer.fromJson<int?>(json['dispatch_count']),
      forcesSent: serializer.fromJson<int?>(json['forces_sent']),
      captures: serializer.fromJson<int?>(json['captures']),
      appVersion: serializer.fromJson<String>(json['app_version']),
      rulesVersion: serializer.fromJson<String>(json['rules_version']),
      metricsVersion: serializer.fromJson<int>(json['metrics_version']),
      receiptXp: serializer.fromJson<int?>(json['receipt_xp']),
      receiptBefore: serializer.fromJson<int?>(json['receipt_before']),
      receiptAfter: serializer.fromJson<int?>(json['receipt_after']),
      receiptRewardVersion: serializer.fromJson<String?>(
        json['receipt_reward_version'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'match_id': serializer.toJson<String>(matchId),
      'profile_id': serializer.toJson<String>(profileId),
      'execution_id': serializer.toJson<String>(executionId),
      'session_kind': serializer.toJson<String>(sessionKind),
      'origin': serializer.toJson<String>(origin),
      'game_mode': serializer.toJson<String>(gameMode),
      'difficulty': serializer.toJson<String>(difficulty),
      'player_cpu_difficulty': serializer.toJson<String>(playerCpuDifficulty),
      'island_count': serializer.toJson<int>(islandCount),
      'status': serializer.toJson<String>(status),
      'outcome': serializer.toJson<String?>(outcome),
      'started_at_utc': serializer.toJson<int>(startedAtUtc),
      'ended_at_utc': serializer.toJson<int?>(endedAtUtc),
      'recovered_at_utc': serializer.toJson<int?>(recoveredAtUtc),
      'elapsed_ms': serializer.toJson<int?>(elapsedMs),
      'dispatch_count': serializer.toJson<int?>(dispatchCount),
      'forces_sent': serializer.toJson<int?>(forcesSent),
      'captures': serializer.toJson<int?>(captures),
      'app_version': serializer.toJson<String>(appVersion),
      'rules_version': serializer.toJson<String>(rulesVersion),
      'metrics_version': serializer.toJson<int>(metricsVersion),
      'receipt_xp': serializer.toJson<int?>(receiptXp),
      'receipt_before': serializer.toJson<int?>(receiptBefore),
      'receipt_after': serializer.toJson<int?>(receiptAfter),
      'receipt_reward_version': serializer.toJson<String?>(
        receiptRewardVersion,
      ),
    };
  }

  MatchRecord copyWith({
    String? matchId,
    String? profileId,
    String? executionId,
    String? sessionKind,
    String? origin,
    String? gameMode,
    String? difficulty,
    String? playerCpuDifficulty,
    int? islandCount,
    String? status,
    Value<String?> outcome = const Value.absent(),
    int? startedAtUtc,
    Value<int?> endedAtUtc = const Value.absent(),
    Value<int?> recoveredAtUtc = const Value.absent(),
    Value<int?> elapsedMs = const Value.absent(),
    Value<int?> dispatchCount = const Value.absent(),
    Value<int?> forcesSent = const Value.absent(),
    Value<int?> captures = const Value.absent(),
    String? appVersion,
    String? rulesVersion,
    int? metricsVersion,
    Value<int?> receiptXp = const Value.absent(),
    Value<int?> receiptBefore = const Value.absent(),
    Value<int?> receiptAfter = const Value.absent(),
    Value<String?> receiptRewardVersion = const Value.absent(),
  }) => MatchRecord(
    matchId: matchId ?? this.matchId,
    profileId: profileId ?? this.profileId,
    executionId: executionId ?? this.executionId,
    sessionKind: sessionKind ?? this.sessionKind,
    origin: origin ?? this.origin,
    gameMode: gameMode ?? this.gameMode,
    difficulty: difficulty ?? this.difficulty,
    playerCpuDifficulty: playerCpuDifficulty ?? this.playerCpuDifficulty,
    islandCount: islandCount ?? this.islandCount,
    status: status ?? this.status,
    outcome: outcome.present ? outcome.value : this.outcome,
    startedAtUtc: startedAtUtc ?? this.startedAtUtc,
    endedAtUtc: endedAtUtc.present ? endedAtUtc.value : this.endedAtUtc,
    recoveredAtUtc: recoveredAtUtc.present
        ? recoveredAtUtc.value
        : this.recoveredAtUtc,
    elapsedMs: elapsedMs.present ? elapsedMs.value : this.elapsedMs,
    dispatchCount: dispatchCount.present
        ? dispatchCount.value
        : this.dispatchCount,
    forcesSent: forcesSent.present ? forcesSent.value : this.forcesSent,
    captures: captures.present ? captures.value : this.captures,
    appVersion: appVersion ?? this.appVersion,
    rulesVersion: rulesVersion ?? this.rulesVersion,
    metricsVersion: metricsVersion ?? this.metricsVersion,
    receiptXp: receiptXp.present ? receiptXp.value : this.receiptXp,
    receiptBefore: receiptBefore.present
        ? receiptBefore.value
        : this.receiptBefore,
    receiptAfter: receiptAfter.present ? receiptAfter.value : this.receiptAfter,
    receiptRewardVersion: receiptRewardVersion.present
        ? receiptRewardVersion.value
        : this.receiptRewardVersion,
  );
  MatchRecord copyWithCompanion(MatchRecordsCompanion data) {
    return MatchRecord(
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      executionId: data.executionId.present
          ? data.executionId.value
          : this.executionId,
      sessionKind: data.sessionKind.present
          ? data.sessionKind.value
          : this.sessionKind,
      origin: data.origin.present ? data.origin.value : this.origin,
      gameMode: data.gameMode.present ? data.gameMode.value : this.gameMode,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      playerCpuDifficulty: data.playerCpuDifficulty.present
          ? data.playerCpuDifficulty.value
          : this.playerCpuDifficulty,
      islandCount: data.islandCount.present
          ? data.islandCount.value
          : this.islandCount,
      status: data.status.present ? data.status.value : this.status,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      startedAtUtc: data.startedAtUtc.present
          ? data.startedAtUtc.value
          : this.startedAtUtc,
      endedAtUtc: data.endedAtUtc.present
          ? data.endedAtUtc.value
          : this.endedAtUtc,
      recoveredAtUtc: data.recoveredAtUtc.present
          ? data.recoveredAtUtc.value
          : this.recoveredAtUtc,
      elapsedMs: data.elapsedMs.present ? data.elapsedMs.value : this.elapsedMs,
      dispatchCount: data.dispatchCount.present
          ? data.dispatchCount.value
          : this.dispatchCount,
      forcesSent: data.forcesSent.present
          ? data.forcesSent.value
          : this.forcesSent,
      captures: data.captures.present ? data.captures.value : this.captures,
      appVersion: data.appVersion.present
          ? data.appVersion.value
          : this.appVersion,
      rulesVersion: data.rulesVersion.present
          ? data.rulesVersion.value
          : this.rulesVersion,
      metricsVersion: data.metricsVersion.present
          ? data.metricsVersion.value
          : this.metricsVersion,
      receiptXp: data.receiptXp.present ? data.receiptXp.value : this.receiptXp,
      receiptBefore: data.receiptBefore.present
          ? data.receiptBefore.value
          : this.receiptBefore,
      receiptAfter: data.receiptAfter.present
          ? data.receiptAfter.value
          : this.receiptAfter,
      receiptRewardVersion: data.receiptRewardVersion.present
          ? data.receiptRewardVersion.value
          : this.receiptRewardVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchRecord(')
          ..write('matchId: $matchId, ')
          ..write('profileId: $profileId, ')
          ..write('executionId: $executionId, ')
          ..write('sessionKind: $sessionKind, ')
          ..write('origin: $origin, ')
          ..write('gameMode: $gameMode, ')
          ..write('difficulty: $difficulty, ')
          ..write('playerCpuDifficulty: $playerCpuDifficulty, ')
          ..write('islandCount: $islandCount, ')
          ..write('status: $status, ')
          ..write('outcome: $outcome, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('endedAtUtc: $endedAtUtc, ')
          ..write('recoveredAtUtc: $recoveredAtUtc, ')
          ..write('elapsedMs: $elapsedMs, ')
          ..write('dispatchCount: $dispatchCount, ')
          ..write('forcesSent: $forcesSent, ')
          ..write('captures: $captures, ')
          ..write('appVersion: $appVersion, ')
          ..write('rulesVersion: $rulesVersion, ')
          ..write('metricsVersion: $metricsVersion, ')
          ..write('receiptXp: $receiptXp, ')
          ..write('receiptBefore: $receiptBefore, ')
          ..write('receiptAfter: $receiptAfter, ')
          ..write('receiptRewardVersion: $receiptRewardVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    matchId,
    profileId,
    executionId,
    sessionKind,
    origin,
    gameMode,
    difficulty,
    playerCpuDifficulty,
    islandCount,
    status,
    outcome,
    startedAtUtc,
    endedAtUtc,
    recoveredAtUtc,
    elapsedMs,
    dispatchCount,
    forcesSent,
    captures,
    appVersion,
    rulesVersion,
    metricsVersion,
    receiptXp,
    receiptBefore,
    receiptAfter,
    receiptRewardVersion,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchRecord &&
          other.matchId == this.matchId &&
          other.profileId == this.profileId &&
          other.executionId == this.executionId &&
          other.sessionKind == this.sessionKind &&
          other.origin == this.origin &&
          other.gameMode == this.gameMode &&
          other.difficulty == this.difficulty &&
          other.playerCpuDifficulty == this.playerCpuDifficulty &&
          other.islandCount == this.islandCount &&
          other.status == this.status &&
          other.outcome == this.outcome &&
          other.startedAtUtc == this.startedAtUtc &&
          other.endedAtUtc == this.endedAtUtc &&
          other.recoveredAtUtc == this.recoveredAtUtc &&
          other.elapsedMs == this.elapsedMs &&
          other.dispatchCount == this.dispatchCount &&
          other.forcesSent == this.forcesSent &&
          other.captures == this.captures &&
          other.appVersion == this.appVersion &&
          other.rulesVersion == this.rulesVersion &&
          other.metricsVersion == this.metricsVersion &&
          other.receiptXp == this.receiptXp &&
          other.receiptBefore == this.receiptBefore &&
          other.receiptAfter == this.receiptAfter &&
          other.receiptRewardVersion == this.receiptRewardVersion);
}

class MatchRecordsCompanion extends UpdateCompanion<MatchRecord> {
  final Value<String> matchId;
  final Value<String> profileId;
  final Value<String> executionId;
  final Value<String> sessionKind;
  final Value<String> origin;
  final Value<String> gameMode;
  final Value<String> difficulty;
  final Value<String> playerCpuDifficulty;
  final Value<int> islandCount;
  final Value<String> status;
  final Value<String?> outcome;
  final Value<int> startedAtUtc;
  final Value<int?> endedAtUtc;
  final Value<int?> recoveredAtUtc;
  final Value<int?> elapsedMs;
  final Value<int?> dispatchCount;
  final Value<int?> forcesSent;
  final Value<int?> captures;
  final Value<String> appVersion;
  final Value<String> rulesVersion;
  final Value<int> metricsVersion;
  final Value<int?> receiptXp;
  final Value<int?> receiptBefore;
  final Value<int?> receiptAfter;
  final Value<String?> receiptRewardVersion;
  final Value<int> rowid;
  const MatchRecordsCompanion({
    this.matchId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.executionId = const Value.absent(),
    this.sessionKind = const Value.absent(),
    this.origin = const Value.absent(),
    this.gameMode = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.playerCpuDifficulty = const Value.absent(),
    this.islandCount = const Value.absent(),
    this.status = const Value.absent(),
    this.outcome = const Value.absent(),
    this.startedAtUtc = const Value.absent(),
    this.endedAtUtc = const Value.absent(),
    this.recoveredAtUtc = const Value.absent(),
    this.elapsedMs = const Value.absent(),
    this.dispatchCount = const Value.absent(),
    this.forcesSent = const Value.absent(),
    this.captures = const Value.absent(),
    this.appVersion = const Value.absent(),
    this.rulesVersion = const Value.absent(),
    this.metricsVersion = const Value.absent(),
    this.receiptXp = const Value.absent(),
    this.receiptBefore = const Value.absent(),
    this.receiptAfter = const Value.absent(),
    this.receiptRewardVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchRecordsCompanion.insert({
    required String matchId,
    required String profileId,
    required String executionId,
    required String sessionKind,
    required String origin,
    required String gameMode,
    required String difficulty,
    required String playerCpuDifficulty,
    required int islandCount,
    required String status,
    this.outcome = const Value.absent(),
    required int startedAtUtc,
    this.endedAtUtc = const Value.absent(),
    this.recoveredAtUtc = const Value.absent(),
    this.elapsedMs = const Value.absent(),
    this.dispatchCount = const Value.absent(),
    this.forcesSent = const Value.absent(),
    this.captures = const Value.absent(),
    required String appVersion,
    required String rulesVersion,
    required int metricsVersion,
    this.receiptXp = const Value.absent(),
    this.receiptBefore = const Value.absent(),
    this.receiptAfter = const Value.absent(),
    this.receiptRewardVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : matchId = Value(matchId),
       profileId = Value(profileId),
       executionId = Value(executionId),
       sessionKind = Value(sessionKind),
       origin = Value(origin),
       gameMode = Value(gameMode),
       difficulty = Value(difficulty),
       playerCpuDifficulty = Value(playerCpuDifficulty),
       islandCount = Value(islandCount),
       status = Value(status),
       startedAtUtc = Value(startedAtUtc),
       appVersion = Value(appVersion),
       rulesVersion = Value(rulesVersion),
       metricsVersion = Value(metricsVersion);
  static Insertable<MatchRecord> custom({
    Expression<String>? matchId,
    Expression<String>? profileId,
    Expression<String>? executionId,
    Expression<String>? sessionKind,
    Expression<String>? origin,
    Expression<String>? gameMode,
    Expression<String>? difficulty,
    Expression<String>? playerCpuDifficulty,
    Expression<int>? islandCount,
    Expression<String>? status,
    Expression<String>? outcome,
    Expression<int>? startedAtUtc,
    Expression<int>? endedAtUtc,
    Expression<int>? recoveredAtUtc,
    Expression<int>? elapsedMs,
    Expression<int>? dispatchCount,
    Expression<int>? forcesSent,
    Expression<int>? captures,
    Expression<String>? appVersion,
    Expression<String>? rulesVersion,
    Expression<int>? metricsVersion,
    Expression<int>? receiptXp,
    Expression<int>? receiptBefore,
    Expression<int>? receiptAfter,
    Expression<String>? receiptRewardVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (matchId != null) 'match_id': matchId,
      if (profileId != null) 'profile_id': profileId,
      if (executionId != null) 'execution_id': executionId,
      if (sessionKind != null) 'session_kind': sessionKind,
      if (origin != null) 'origin': origin,
      if (gameMode != null) 'game_mode': gameMode,
      if (difficulty != null) 'difficulty': difficulty,
      if (playerCpuDifficulty != null)
        'player_cpu_difficulty': playerCpuDifficulty,
      if (islandCount != null) 'island_count': islandCount,
      if (status != null) 'status': status,
      if (outcome != null) 'outcome': outcome,
      if (startedAtUtc != null) 'started_at_utc': startedAtUtc,
      if (endedAtUtc != null) 'ended_at_utc': endedAtUtc,
      if (recoveredAtUtc != null) 'recovered_at_utc': recoveredAtUtc,
      if (elapsedMs != null) 'elapsed_ms': elapsedMs,
      if (dispatchCount != null) 'dispatch_count': dispatchCount,
      if (forcesSent != null) 'forces_sent': forcesSent,
      if (captures != null) 'captures': captures,
      if (appVersion != null) 'app_version': appVersion,
      if (rulesVersion != null) 'rules_version': rulesVersion,
      if (metricsVersion != null) 'metrics_version': metricsVersion,
      if (receiptXp != null) 'receipt_xp': receiptXp,
      if (receiptBefore != null) 'receipt_before': receiptBefore,
      if (receiptAfter != null) 'receipt_after': receiptAfter,
      if (receiptRewardVersion != null)
        'receipt_reward_version': receiptRewardVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchRecordsCompanion copyWith({
    Value<String>? matchId,
    Value<String>? profileId,
    Value<String>? executionId,
    Value<String>? sessionKind,
    Value<String>? origin,
    Value<String>? gameMode,
    Value<String>? difficulty,
    Value<String>? playerCpuDifficulty,
    Value<int>? islandCount,
    Value<String>? status,
    Value<String?>? outcome,
    Value<int>? startedAtUtc,
    Value<int?>? endedAtUtc,
    Value<int?>? recoveredAtUtc,
    Value<int?>? elapsedMs,
    Value<int?>? dispatchCount,
    Value<int?>? forcesSent,
    Value<int?>? captures,
    Value<String>? appVersion,
    Value<String>? rulesVersion,
    Value<int>? metricsVersion,
    Value<int?>? receiptXp,
    Value<int?>? receiptBefore,
    Value<int?>? receiptAfter,
    Value<String?>? receiptRewardVersion,
    Value<int>? rowid,
  }) {
    return MatchRecordsCompanion(
      matchId: matchId ?? this.matchId,
      profileId: profileId ?? this.profileId,
      executionId: executionId ?? this.executionId,
      sessionKind: sessionKind ?? this.sessionKind,
      origin: origin ?? this.origin,
      gameMode: gameMode ?? this.gameMode,
      difficulty: difficulty ?? this.difficulty,
      playerCpuDifficulty: playerCpuDifficulty ?? this.playerCpuDifficulty,
      islandCount: islandCount ?? this.islandCount,
      status: status ?? this.status,
      outcome: outcome ?? this.outcome,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      endedAtUtc: endedAtUtc ?? this.endedAtUtc,
      recoveredAtUtc: recoveredAtUtc ?? this.recoveredAtUtc,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      dispatchCount: dispatchCount ?? this.dispatchCount,
      forcesSent: forcesSent ?? this.forcesSent,
      captures: captures ?? this.captures,
      appVersion: appVersion ?? this.appVersion,
      rulesVersion: rulesVersion ?? this.rulesVersion,
      metricsVersion: metricsVersion ?? this.metricsVersion,
      receiptXp: receiptXp ?? this.receiptXp,
      receiptBefore: receiptBefore ?? this.receiptBefore,
      receiptAfter: receiptAfter ?? this.receiptAfter,
      receiptRewardVersion: receiptRewardVersion ?? this.receiptRewardVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (executionId.present) {
      map['execution_id'] = Variable<String>(executionId.value);
    }
    if (sessionKind.present) {
      map['session_kind'] = Variable<String>(sessionKind.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (gameMode.present) {
      map['game_mode'] = Variable<String>(gameMode.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<String>(difficulty.value);
    }
    if (playerCpuDifficulty.present) {
      map['player_cpu_difficulty'] = Variable<String>(
        playerCpuDifficulty.value,
      );
    }
    if (islandCount.present) {
      map['island_count'] = Variable<int>(islandCount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (startedAtUtc.present) {
      map['started_at_utc'] = Variable<int>(startedAtUtc.value);
    }
    if (endedAtUtc.present) {
      map['ended_at_utc'] = Variable<int>(endedAtUtc.value);
    }
    if (recoveredAtUtc.present) {
      map['recovered_at_utc'] = Variable<int>(recoveredAtUtc.value);
    }
    if (elapsedMs.present) {
      map['elapsed_ms'] = Variable<int>(elapsedMs.value);
    }
    if (dispatchCount.present) {
      map['dispatch_count'] = Variable<int>(dispatchCount.value);
    }
    if (forcesSent.present) {
      map['forces_sent'] = Variable<int>(forcesSent.value);
    }
    if (captures.present) {
      map['captures'] = Variable<int>(captures.value);
    }
    if (appVersion.present) {
      map['app_version'] = Variable<String>(appVersion.value);
    }
    if (rulesVersion.present) {
      map['rules_version'] = Variable<String>(rulesVersion.value);
    }
    if (metricsVersion.present) {
      map['metrics_version'] = Variable<int>(metricsVersion.value);
    }
    if (receiptXp.present) {
      map['receipt_xp'] = Variable<int>(receiptXp.value);
    }
    if (receiptBefore.present) {
      map['receipt_before'] = Variable<int>(receiptBefore.value);
    }
    if (receiptAfter.present) {
      map['receipt_after'] = Variable<int>(receiptAfter.value);
    }
    if (receiptRewardVersion.present) {
      map['receipt_reward_version'] = Variable<String>(
        receiptRewardVersion.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchRecordsCompanion(')
          ..write('matchId: $matchId, ')
          ..write('profileId: $profileId, ')
          ..write('executionId: $executionId, ')
          ..write('sessionKind: $sessionKind, ')
          ..write('origin: $origin, ')
          ..write('gameMode: $gameMode, ')
          ..write('difficulty: $difficulty, ')
          ..write('playerCpuDifficulty: $playerCpuDifficulty, ')
          ..write('islandCount: $islandCount, ')
          ..write('status: $status, ')
          ..write('outcome: $outcome, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('endedAtUtc: $endedAtUtc, ')
          ..write('recoveredAtUtc: $recoveredAtUtc, ')
          ..write('elapsedMs: $elapsedMs, ')
          ..write('dispatchCount: $dispatchCount, ')
          ..write('forcesSent: $forcesSent, ')
          ..write('captures: $captures, ')
          ..write('appVersion: $appVersion, ')
          ..write('rulesVersion: $rulesVersion, ')
          ..write('metricsVersion: $metricsVersion, ')
          ..write('receiptXp: $receiptXp, ')
          ..write('receiptBefore: $receiptBefore, ')
          ..write('receiptAfter: $receiptAfter, ')
          ..write('receiptRewardVersion: $receiptRewardVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class XpEntries extends Table with TableInfo<XpEntries, XpEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  XpEntries(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES profiles(profile_id)',
  );
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (reason IN (\'legacy_import\', \'match_victory\'))',
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (amount >= 0)',
  );
  static const VerificationMeta _rewardVersionMeta = const VerificationMeta(
    'rewardVersion',
  );
  late final GeneratedColumn<String> rewardVersion = GeneratedColumn<String>(
    'reward_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(reward_version)) > 0)',
  );
  static const VerificationMeta _totalXpBeforeMeta = const VerificationMeta(
    'totalXpBefore',
  );
  late final GeneratedColumn<int> totalXpBefore = GeneratedColumn<int>(
    'total_xp_before',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (total_xp_before >= 0)',
  );
  static const VerificationMeta _totalXpAfterMeta = const VerificationMeta(
    'totalXpAfter',
  );
  late final GeneratedColumn<int> totalXpAfter = GeneratedColumn<int>(
    'total_xp_after',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (total_xp_after = total_xp_before + amount)',
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    entryId,
    profileId,
    matchId,
    reason,
    amount,
    rewardVersion,
    totalXpBefore,
    totalXpAfter,
    createdAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'xp_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<XpEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('reward_version')) {
      context.handle(
        _rewardVersionMeta,
        rewardVersion.isAcceptableOrUnknown(
          data['reward_version']!,
          _rewardVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rewardVersionMeta);
    }
    if (data.containsKey('total_xp_before')) {
      context.handle(
        _totalXpBeforeMeta,
        totalXpBefore.isAcceptableOrUnknown(
          data['total_xp_before']!,
          _totalXpBeforeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalXpBeforeMeta);
    }
    if (data.containsKey('total_xp_after')) {
      context.handle(
        _totalXpAfterMeta,
        totalXpAfter.isAcceptableOrUnknown(
          data['total_xp_after']!,
          _totalXpAfterMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalXpAfterMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {matchId, reason},
  ];
  @override
  XpEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return XpEntry(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      ),
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      rewardVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reward_version'],
      )!,
      totalXpBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_xp_before'],
      )!,
      totalXpAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_xp_after'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
    );
  }

  @override
  XpEntries createAlias(String alias) {
    return XpEntries(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY(match_id, profile_id)REFERENCES match_records(match_id, profile_id)',
    'UNIQUE(match_id, reason)',
    'CHECK((reason = \'legacy_import\' AND match_id IS NULL AND entry_id = \'legacy:\' || profile_id)OR(reason = \'match_victory\' AND match_id IS NOT NULL AND amount > 0))',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class XpEntry extends DataClass implements Insertable<XpEntry> {
  final String entryId;
  final String profileId;
  final String? matchId;
  final String reason;
  final int amount;
  final String rewardVersion;
  final int totalXpBefore;
  final int totalXpAfter;
  final int createdAtUtc;
  const XpEntry({
    required this.entryId,
    required this.profileId,
    this.matchId,
    required this.reason,
    required this.amount,
    required this.rewardVersion,
    required this.totalXpBefore,
    required this.totalXpAfter,
    required this.createdAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['profile_id'] = Variable<String>(profileId);
    if (!nullToAbsent || matchId != null) {
      map['match_id'] = Variable<String>(matchId);
    }
    map['reason'] = Variable<String>(reason);
    map['amount'] = Variable<int>(amount);
    map['reward_version'] = Variable<String>(rewardVersion);
    map['total_xp_before'] = Variable<int>(totalXpBefore);
    map['total_xp_after'] = Variable<int>(totalXpAfter);
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    return map;
  }

  XpEntriesCompanion toCompanion(bool nullToAbsent) {
    return XpEntriesCompanion(
      entryId: Value(entryId),
      profileId: Value(profileId),
      matchId: matchId == null && nullToAbsent
          ? const Value.absent()
          : Value(matchId),
      reason: Value(reason),
      amount: Value(amount),
      rewardVersion: Value(rewardVersion),
      totalXpBefore: Value(totalXpBefore),
      totalXpAfter: Value(totalXpAfter),
      createdAtUtc: Value(createdAtUtc),
    );
  }

  factory XpEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return XpEntry(
      entryId: serializer.fromJson<String>(json['entry_id']),
      profileId: serializer.fromJson<String>(json['profile_id']),
      matchId: serializer.fromJson<String?>(json['match_id']),
      reason: serializer.fromJson<String>(json['reason']),
      amount: serializer.fromJson<int>(json['amount']),
      rewardVersion: serializer.fromJson<String>(json['reward_version']),
      totalXpBefore: serializer.fromJson<int>(json['total_xp_before']),
      totalXpAfter: serializer.fromJson<int>(json['total_xp_after']),
      createdAtUtc: serializer.fromJson<int>(json['created_at_utc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entry_id': serializer.toJson<String>(entryId),
      'profile_id': serializer.toJson<String>(profileId),
      'match_id': serializer.toJson<String?>(matchId),
      'reason': serializer.toJson<String>(reason),
      'amount': serializer.toJson<int>(amount),
      'reward_version': serializer.toJson<String>(rewardVersion),
      'total_xp_before': serializer.toJson<int>(totalXpBefore),
      'total_xp_after': serializer.toJson<int>(totalXpAfter),
      'created_at_utc': serializer.toJson<int>(createdAtUtc),
    };
  }

  XpEntry copyWith({
    String? entryId,
    String? profileId,
    Value<String?> matchId = const Value.absent(),
    String? reason,
    int? amount,
    String? rewardVersion,
    int? totalXpBefore,
    int? totalXpAfter,
    int? createdAtUtc,
  }) => XpEntry(
    entryId: entryId ?? this.entryId,
    profileId: profileId ?? this.profileId,
    matchId: matchId.present ? matchId.value : this.matchId,
    reason: reason ?? this.reason,
    amount: amount ?? this.amount,
    rewardVersion: rewardVersion ?? this.rewardVersion,
    totalXpBefore: totalXpBefore ?? this.totalXpBefore,
    totalXpAfter: totalXpAfter ?? this.totalXpAfter,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
  );
  XpEntry copyWithCompanion(XpEntriesCompanion data) {
    return XpEntry(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      reason: data.reason.present ? data.reason.value : this.reason,
      amount: data.amount.present ? data.amount.value : this.amount,
      rewardVersion: data.rewardVersion.present
          ? data.rewardVersion.value
          : this.rewardVersion,
      totalXpBefore: data.totalXpBefore.present
          ? data.totalXpBefore.value
          : this.totalXpBefore,
      totalXpAfter: data.totalXpAfter.present
          ? data.totalXpAfter.value
          : this.totalXpAfter,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('XpEntry(')
          ..write('entryId: $entryId, ')
          ..write('profileId: $profileId, ')
          ..write('matchId: $matchId, ')
          ..write('reason: $reason, ')
          ..write('amount: $amount, ')
          ..write('rewardVersion: $rewardVersion, ')
          ..write('totalXpBefore: $totalXpBefore, ')
          ..write('totalXpAfter: $totalXpAfter, ')
          ..write('createdAtUtc: $createdAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    entryId,
    profileId,
    matchId,
    reason,
    amount,
    rewardVersion,
    totalXpBefore,
    totalXpAfter,
    createdAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is XpEntry &&
          other.entryId == this.entryId &&
          other.profileId == this.profileId &&
          other.matchId == this.matchId &&
          other.reason == this.reason &&
          other.amount == this.amount &&
          other.rewardVersion == this.rewardVersion &&
          other.totalXpBefore == this.totalXpBefore &&
          other.totalXpAfter == this.totalXpAfter &&
          other.createdAtUtc == this.createdAtUtc);
}

class XpEntriesCompanion extends UpdateCompanion<XpEntry> {
  final Value<String> entryId;
  final Value<String> profileId;
  final Value<String?> matchId;
  final Value<String> reason;
  final Value<int> amount;
  final Value<String> rewardVersion;
  final Value<int> totalXpBefore;
  final Value<int> totalXpAfter;
  final Value<int> createdAtUtc;
  final Value<int> rowid;
  const XpEntriesCompanion({
    this.entryId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.matchId = const Value.absent(),
    this.reason = const Value.absent(),
    this.amount = const Value.absent(),
    this.rewardVersion = const Value.absent(),
    this.totalXpBefore = const Value.absent(),
    this.totalXpAfter = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  XpEntriesCompanion.insert({
    required String entryId,
    required String profileId,
    this.matchId = const Value.absent(),
    required String reason,
    required int amount,
    required String rewardVersion,
    required int totalXpBefore,
    required int totalXpAfter,
    required int createdAtUtc,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       profileId = Value(profileId),
       reason = Value(reason),
       amount = Value(amount),
       rewardVersion = Value(rewardVersion),
       totalXpBefore = Value(totalXpBefore),
       totalXpAfter = Value(totalXpAfter),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<XpEntry> custom({
    Expression<String>? entryId,
    Expression<String>? profileId,
    Expression<String>? matchId,
    Expression<String>? reason,
    Expression<int>? amount,
    Expression<String>? rewardVersion,
    Expression<int>? totalXpBefore,
    Expression<int>? totalXpAfter,
    Expression<int>? createdAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (profileId != null) 'profile_id': profileId,
      if (matchId != null) 'match_id': matchId,
      if (reason != null) 'reason': reason,
      if (amount != null) 'amount': amount,
      if (rewardVersion != null) 'reward_version': rewardVersion,
      if (totalXpBefore != null) 'total_xp_before': totalXpBefore,
      if (totalXpAfter != null) 'total_xp_after': totalXpAfter,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  XpEntriesCompanion copyWith({
    Value<String>? entryId,
    Value<String>? profileId,
    Value<String?>? matchId,
    Value<String>? reason,
    Value<int>? amount,
    Value<String>? rewardVersion,
    Value<int>? totalXpBefore,
    Value<int>? totalXpAfter,
    Value<int>? createdAtUtc,
    Value<int>? rowid,
  }) {
    return XpEntriesCompanion(
      entryId: entryId ?? this.entryId,
      profileId: profileId ?? this.profileId,
      matchId: matchId ?? this.matchId,
      reason: reason ?? this.reason,
      amount: amount ?? this.amount,
      rewardVersion: rewardVersion ?? this.rewardVersion,
      totalXpBefore: totalXpBefore ?? this.totalXpBefore,
      totalXpAfter: totalXpAfter ?? this.totalXpAfter,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (rewardVersion.present) {
      map['reward_version'] = Variable<String>(rewardVersion.value);
    }
    if (totalXpBefore.present) {
      map['total_xp_before'] = Variable<int>(totalXpBefore.value);
    }
    if (totalXpAfter.present) {
      map['total_xp_after'] = Variable<int>(totalXpAfter.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('XpEntriesCompanion(')
          ..write('entryId: $entryId, ')
          ..write('profileId: $profileId, ')
          ..write('matchId: $matchId, ')
          ..write('reason: $reason, ')
          ..write('amount: $amount, ')
          ..write('rewardVersion: $rewardVersion, ')
          ..write('totalXpBefore: $totalXpBefore, ')
          ..write('totalXpAfter: $totalXpAfter, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class StorageMeta extends Table with TableInfo<StorageMeta, StorageMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  StorageMeta(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'storage_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<StorageMetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  StorageMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StorageMetaData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  StorageMeta createAlias(String alias) {
    return StorageMeta(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class StorageMetaData extends DataClass implements Insertable<StorageMetaData> {
  final String key;
  final String value;
  const StorageMetaData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  StorageMetaCompanion toCompanion(bool nullToAbsent) {
    return StorageMetaCompanion(key: Value(key), value: Value(value));
  }

  factory StorageMetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StorageMetaData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  StorageMetaData copyWith({String? key, String? value}) =>
      StorageMetaData(key: key ?? this.key, value: value ?? this.value);
  StorageMetaData copyWithCompanion(StorageMetaCompanion data) {
    return StorageMetaData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StorageMetaData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StorageMetaData &&
          other.key == this.key &&
          other.value == this.value);
}

class StorageMetaCompanion extends UpdateCompanion<StorageMetaData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const StorageMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StorageMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<StorageMetaData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StorageMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return StorageMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StorageMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ProfileDatabase extends GeneratedDatabase {
  _$ProfileDatabase(QueryExecutor e) : super(e);
  $ProfileDatabaseManager get managers => $ProfileDatabaseManager(this);
  late final Profiles profiles = Profiles(this);
  late final MatchRecords matchRecords = MatchRecords(this);
  late final Index matchHistory = Index(
    'match_history',
    'CREATE INDEX match_history ON match_records (profile_id, started_at_utc DESC, match_id DESC)',
  );
  late final Index matchStatistics = Index(
    'match_statistics',
    'CREATE INDEX match_statistics ON match_records (profile_id, status, session_kind, difficulty, island_count)',
  );
  late final Index matchExecution = Index(
    'match_execution',
    'CREATE INDEX match_execution ON match_records (profile_id, execution_id, status)',
  );
  late final XpEntries xpEntries = XpEntries(this);
  late final Index legacyImportOnce = Index(
    'legacy_import_once',
    'CREATE UNIQUE INDEX legacy_import_once ON xp_entries (profile_id) WHERE reason = \'legacy_import\'',
  );
  late final Trigger victoryMatchesReceipt = Trigger(
    'CREATE TRIGGER victory_matches_receipt BEFORE INSERT ON xp_entries WHEN NEW.reason = \'match_victory\' BEGIN SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM match_records WHERE match_id = NEW.match_id AND profile_id = NEW.profile_id AND status = \'completed\' AND outcome = \'win\' AND receipt_xp = NEW.amount AND receipt_before = NEW.total_xp_before AND receipt_after = NEW.total_xp_after AND receipt_reward_version = NEW.reward_version) THEN RAISE (ABORT, \'XP does not match victory receipt\') END;END',
    'victory_matches_receipt',
  );
  late final StorageMeta storageMeta = StorageMeta(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    profiles,
    matchRecords,
    matchHistory,
    matchStatistics,
    matchExecution,
    xpEntries,
    legacyImportOnce,
    victoryMatchesReceipt,
    storageMeta,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'xp_entries',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [],
    ),
  ]);
}

typedef $ProfilesCreateCompanionBuilder =
    ProfilesCompanion Function({
      required String profileId,
      Value<String?> displayName,
      required String avatarKey,
      required int createdAtUtc,
      required int updatedAtUtc,
      required int statsStartedAtUtc,
      Value<int> rowid,
    });
typedef $ProfilesUpdateCompanionBuilder =
    ProfilesCompanion Function({
      Value<String> profileId,
      Value<String?> displayName,
      Value<String> avatarKey,
      Value<int> createdAtUtc,
      Value<int> updatedAtUtc,
      Value<int> statsStartedAtUtc,
      Value<int> rowid,
    });

final class $ProfilesReferences
    extends BaseReferences<_$ProfileDatabase, Profiles, Profile> {
  $ProfilesReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<MatchRecords, List<MatchRecord>>
  _matchRecordsRefsTable(_$ProfileDatabase db) => MultiTypedResultKey.fromTable(
    db.matchRecords,
    aliasName: 'profiles__profile_id__match_records__profile_id',
  );

  $MatchRecordsProcessedTableManager get matchRecordsRefs {
    final manager = $MatchRecordsTableManager($_db, $_db.matchRecords).filter(
      (f) =>
          f.profileId.profileId.sqlEquals($_itemColumn<String>('profile_id')!),
    );

    final cache = $_typedResult.readTableOrNull(_matchRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<XpEntries, List<XpEntry>> _xpEntriesRefsTable(
    _$ProfileDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.xpEntries,
    aliasName: 'profiles__profile_id__xp_entries__profile_id',
  );

  $XpEntriesProcessedTableManager get xpEntriesRefs {
    final manager = $XpEntriesTableManager($_db, $_db.xpEntries).filter(
      (f) =>
          f.profileId.profileId.sqlEquals($_itemColumn<String>('profile_id')!),
    );

    final cache = $_typedResult.readTableOrNull(_xpEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $ProfilesFilterComposer extends Composer<_$ProfileDatabase, Profiles> {
  $ProfilesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarKey => $composableBuilder(
    column: $table.avatarKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get statsStartedAtUtc => $composableBuilder(
    column: $table.statsStartedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> matchRecordsRefs(
    Expression<bool> Function($MatchRecordsFilterComposer f) f,
  ) {
    final $MatchRecordsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.matchRecords,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MatchRecordsFilterComposer(
            $db: $db,
            $table: $db.matchRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> xpEntriesRefs(
    Expression<bool> Function($XpEntriesFilterComposer f) f,
  ) {
    final $XpEntriesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.xpEntries,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $XpEntriesFilterComposer(
            $db: $db,
            $table: $db.xpEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ProfilesOrderingComposer extends Composer<_$ProfileDatabase, Profiles> {
  $ProfilesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarKey => $composableBuilder(
    column: $table.avatarKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get statsStartedAtUtc => $composableBuilder(
    column: $table.statsStartedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ProfilesAnnotationComposer
    extends Composer<_$ProfileDatabase, Profiles> {
  $ProfilesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarKey =>
      $composableBuilder(column: $table.avatarKey, builder: (column) => column);

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get statsStartedAtUtc => $composableBuilder(
    column: $table.statsStartedAtUtc,
    builder: (column) => column,
  );

  Expression<T> matchRecordsRefs<T extends Object>(
    Expression<T> Function($MatchRecordsAnnotationComposer a) f,
  ) {
    final $MatchRecordsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.matchRecords,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MatchRecordsAnnotationComposer(
            $db: $db,
            $table: $db.matchRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> xpEntriesRefs<T extends Object>(
    Expression<T> Function($XpEntriesAnnotationComposer a) f,
  ) {
    final $XpEntriesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.xpEntries,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $XpEntriesAnnotationComposer(
            $db: $db,
            $table: $db.xpEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ProfilesTableManager
    extends
        RootTableManager<
          _$ProfileDatabase,
          Profiles,
          Profile,
          $ProfilesFilterComposer,
          $ProfilesOrderingComposer,
          $ProfilesAnnotationComposer,
          $ProfilesCreateCompanionBuilder,
          $ProfilesUpdateCompanionBuilder,
          (Profile, $ProfilesReferences),
          Profile,
          PrefetchHooks Function({bool matchRecordsRefs, bool xpEntriesRefs})
        > {
  $ProfilesTableManager(_$ProfileDatabase db, Profiles table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ProfilesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ProfilesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ProfilesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String> avatarKey = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int> statsStartedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                profileId: profileId,
                displayName: displayName,
                avatarKey: avatarKey,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                statsStartedAtUtc: statsStartedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                Value<String?> displayName = const Value.absent(),
                required String avatarKey,
                required int createdAtUtc,
                required int updatedAtUtc,
                required int statsStartedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                profileId: profileId,
                displayName: displayName,
                avatarKey: avatarKey,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                statsStartedAtUtc: statsStartedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Profiles, Profile>(table),
                  $ProfilesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({matchRecordsRefs = false, xpEntriesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (matchRecordsRefs) db.matchRecords,
                    if (xpEntriesRefs) db.xpEntries,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (matchRecordsRefs)
                        await $_getPrefetchedData<
                          Profile,
                          Profiles,
                          MatchRecord
                        >(
                          currentTable: table,
                          referencedTable: $ProfilesReferences
                              ._matchRecordsRefsTable(db),
                          managerFromTypedResult: (p0) => $ProfilesReferences(
                            db,
                            table,
                            p0,
                          ).matchRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.profileId,
                              ),
                          typedResults: items,
                        ),
                      if (xpEntriesRefs)
                        await $_getPrefetchedData<Profile, Profiles, XpEntry>(
                          currentTable: table,
                          referencedTable: $ProfilesReferences
                              ._xpEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $ProfilesReferences(db, table, p0).xpEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.profileId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $ProfilesProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDatabase,
      Profiles,
      Profile,
      $ProfilesFilterComposer,
      $ProfilesOrderingComposer,
      $ProfilesAnnotationComposer,
      $ProfilesCreateCompanionBuilder,
      $ProfilesUpdateCompanionBuilder,
      (Profile, $ProfilesReferences),
      Profile,
      PrefetchHooks Function({bool matchRecordsRefs, bool xpEntriesRefs})
    >;
typedef $MatchRecordsCreateCompanionBuilder =
    MatchRecordsCompanion Function({
      required String matchId,
      required String profileId,
      required String executionId,
      required String sessionKind,
      required String origin,
      required String gameMode,
      required String difficulty,
      required String playerCpuDifficulty,
      required int islandCount,
      required String status,
      Value<String?> outcome,
      required int startedAtUtc,
      Value<int?> endedAtUtc,
      Value<int?> recoveredAtUtc,
      Value<int?> elapsedMs,
      Value<int?> dispatchCount,
      Value<int?> forcesSent,
      Value<int?> captures,
      required String appVersion,
      required String rulesVersion,
      required int metricsVersion,
      Value<int?> receiptXp,
      Value<int?> receiptBefore,
      Value<int?> receiptAfter,
      Value<String?> receiptRewardVersion,
      Value<int> rowid,
    });
typedef $MatchRecordsUpdateCompanionBuilder =
    MatchRecordsCompanion Function({
      Value<String> matchId,
      Value<String> profileId,
      Value<String> executionId,
      Value<String> sessionKind,
      Value<String> origin,
      Value<String> gameMode,
      Value<String> difficulty,
      Value<String> playerCpuDifficulty,
      Value<int> islandCount,
      Value<String> status,
      Value<String?> outcome,
      Value<int> startedAtUtc,
      Value<int?> endedAtUtc,
      Value<int?> recoveredAtUtc,
      Value<int?> elapsedMs,
      Value<int?> dispatchCount,
      Value<int?> forcesSent,
      Value<int?> captures,
      Value<String> appVersion,
      Value<String> rulesVersion,
      Value<int> metricsVersion,
      Value<int?> receiptXp,
      Value<int?> receiptBefore,
      Value<int?> receiptAfter,
      Value<String?> receiptRewardVersion,
      Value<int> rowid,
    });

final class $MatchRecordsReferences
    extends BaseReferences<_$ProfileDatabase, MatchRecords, MatchRecord> {
  $MatchRecordsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Profiles _profileIdTable(_$ProfileDatabase db) => db.profiles
      .createAlias('match_records__profile_id__profiles__profile_id');

  $ProfilesProcessedTableManager get profileId {
    final $_column = $_itemColumn<String>('profile_id')!;

    final manager = $ProfilesTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.profileId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $MatchRecordsFilterComposer
    extends Composer<_$ProfileDatabase, MatchRecords> {
  $MatchRecordsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get matchId => $composableBuilder(
    column: $table.matchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get executionId => $composableBuilder(
    column: $table.executionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionKind => $composableBuilder(
    column: $table.sessionKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gameMode => $composableBuilder(
    column: $table.gameMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playerCpuDifficulty => $composableBuilder(
    column: $table.playerCpuDifficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get islandCount => $composableBuilder(
    column: $table.islandCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAtUtc => $composableBuilder(
    column: $table.endedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recoveredAtUtc => $composableBuilder(
    column: $table.recoveredAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elapsedMs => $composableBuilder(
    column: $table.elapsedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dispatchCount => $composableBuilder(
    column: $table.dispatchCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get forcesSent => $composableBuilder(
    column: $table.forcesSent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get captures => $composableBuilder(
    column: $table.captures,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rulesVersion => $composableBuilder(
    column: $table.rulesVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get metricsVersion => $composableBuilder(
    column: $table.metricsVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get receiptXp => $composableBuilder(
    column: $table.receiptXp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get receiptBefore => $composableBuilder(
    column: $table.receiptBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get receiptAfter => $composableBuilder(
    column: $table.receiptAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptRewardVersion => $composableBuilder(
    column: $table.receiptRewardVersion,
    builder: (column) => ColumnFilters(column),
  );

  $ProfilesFilterComposer get profileId {
    final $ProfilesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProfilesFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MatchRecordsOrderingComposer
    extends Composer<_$ProfileDatabase, MatchRecords> {
  $MatchRecordsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get matchId => $composableBuilder(
    column: $table.matchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get executionId => $composableBuilder(
    column: $table.executionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionKind => $composableBuilder(
    column: $table.sessionKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gameMode => $composableBuilder(
    column: $table.gameMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playerCpuDifficulty => $composableBuilder(
    column: $table.playerCpuDifficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get islandCount => $composableBuilder(
    column: $table.islandCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAtUtc => $composableBuilder(
    column: $table.endedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recoveredAtUtc => $composableBuilder(
    column: $table.recoveredAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsedMs => $composableBuilder(
    column: $table.elapsedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dispatchCount => $composableBuilder(
    column: $table.dispatchCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get forcesSent => $composableBuilder(
    column: $table.forcesSent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get captures => $composableBuilder(
    column: $table.captures,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rulesVersion => $composableBuilder(
    column: $table.rulesVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get metricsVersion => $composableBuilder(
    column: $table.metricsVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get receiptXp => $composableBuilder(
    column: $table.receiptXp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get receiptBefore => $composableBuilder(
    column: $table.receiptBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get receiptAfter => $composableBuilder(
    column: $table.receiptAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptRewardVersion => $composableBuilder(
    column: $table.receiptRewardVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $ProfilesOrderingComposer get profileId {
    final $ProfilesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProfilesOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MatchRecordsAnnotationComposer
    extends Composer<_$ProfileDatabase, MatchRecords> {
  $MatchRecordsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get matchId =>
      $composableBuilder(column: $table.matchId, builder: (column) => column);

  GeneratedColumn<String> get executionId => $composableBuilder(
    column: $table.executionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionKind => $composableBuilder(
    column: $table.sessionKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get gameMode =>
      $composableBuilder(column: $table.gameMode, builder: (column) => column);

  GeneratedColumn<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<String> get playerCpuDifficulty => $composableBuilder(
    column: $table.playerCpuDifficulty,
    builder: (column) => column,
  );

  GeneratedColumn<int> get islandCount => $composableBuilder(
    column: $table.islandCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endedAtUtc => $composableBuilder(
    column: $table.endedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get recoveredAtUtc => $composableBuilder(
    column: $table.recoveredAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get elapsedMs =>
      $composableBuilder(column: $table.elapsedMs, builder: (column) => column);

  GeneratedColumn<int> get dispatchCount => $composableBuilder(
    column: $table.dispatchCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get forcesSent => $composableBuilder(
    column: $table.forcesSent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get captures =>
      $composableBuilder(column: $table.captures, builder: (column) => column);

  GeneratedColumn<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rulesVersion => $composableBuilder(
    column: $table.rulesVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get metricsVersion => $composableBuilder(
    column: $table.metricsVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get receiptXp =>
      $composableBuilder(column: $table.receiptXp, builder: (column) => column);

  GeneratedColumn<int> get receiptBefore => $composableBuilder(
    column: $table.receiptBefore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get receiptAfter => $composableBuilder(
    column: $table.receiptAfter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receiptRewardVersion => $composableBuilder(
    column: $table.receiptRewardVersion,
    builder: (column) => column,
  );

  $ProfilesAnnotationComposer get profileId {
    final $ProfilesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProfilesAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MatchRecordsTableManager
    extends
        RootTableManager<
          _$ProfileDatabase,
          MatchRecords,
          MatchRecord,
          $MatchRecordsFilterComposer,
          $MatchRecordsOrderingComposer,
          $MatchRecordsAnnotationComposer,
          $MatchRecordsCreateCompanionBuilder,
          $MatchRecordsUpdateCompanionBuilder,
          (MatchRecord, $MatchRecordsReferences),
          MatchRecord,
          PrefetchHooks Function({bool profileId})
        > {
  $MatchRecordsTableManager(_$ProfileDatabase db, MatchRecords table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $MatchRecordsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $MatchRecordsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $MatchRecordsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> matchId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> executionId = const Value.absent(),
                Value<String> sessionKind = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<String> gameMode = const Value.absent(),
                Value<String> difficulty = const Value.absent(),
                Value<String> playerCpuDifficulty = const Value.absent(),
                Value<int> islandCount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> outcome = const Value.absent(),
                Value<int> startedAtUtc = const Value.absent(),
                Value<int?> endedAtUtc = const Value.absent(),
                Value<int?> recoveredAtUtc = const Value.absent(),
                Value<int?> elapsedMs = const Value.absent(),
                Value<int?> dispatchCount = const Value.absent(),
                Value<int?> forcesSent = const Value.absent(),
                Value<int?> captures = const Value.absent(),
                Value<String> appVersion = const Value.absent(),
                Value<String> rulesVersion = const Value.absent(),
                Value<int> metricsVersion = const Value.absent(),
                Value<int?> receiptXp = const Value.absent(),
                Value<int?> receiptBefore = const Value.absent(),
                Value<int?> receiptAfter = const Value.absent(),
                Value<String?> receiptRewardVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchRecordsCompanion(
                matchId: matchId,
                profileId: profileId,
                executionId: executionId,
                sessionKind: sessionKind,
                origin: origin,
                gameMode: gameMode,
                difficulty: difficulty,
                playerCpuDifficulty: playerCpuDifficulty,
                islandCount: islandCount,
                status: status,
                outcome: outcome,
                startedAtUtc: startedAtUtc,
                endedAtUtc: endedAtUtc,
                recoveredAtUtc: recoveredAtUtc,
                elapsedMs: elapsedMs,
                dispatchCount: dispatchCount,
                forcesSent: forcesSent,
                captures: captures,
                appVersion: appVersion,
                rulesVersion: rulesVersion,
                metricsVersion: metricsVersion,
                receiptXp: receiptXp,
                receiptBefore: receiptBefore,
                receiptAfter: receiptAfter,
                receiptRewardVersion: receiptRewardVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String matchId,
                required String profileId,
                required String executionId,
                required String sessionKind,
                required String origin,
                required String gameMode,
                required String difficulty,
                required String playerCpuDifficulty,
                required int islandCount,
                required String status,
                Value<String?> outcome = const Value.absent(),
                required int startedAtUtc,
                Value<int?> endedAtUtc = const Value.absent(),
                Value<int?> recoveredAtUtc = const Value.absent(),
                Value<int?> elapsedMs = const Value.absent(),
                Value<int?> dispatchCount = const Value.absent(),
                Value<int?> forcesSent = const Value.absent(),
                Value<int?> captures = const Value.absent(),
                required String appVersion,
                required String rulesVersion,
                required int metricsVersion,
                Value<int?> receiptXp = const Value.absent(),
                Value<int?> receiptBefore = const Value.absent(),
                Value<int?> receiptAfter = const Value.absent(),
                Value<String?> receiptRewardVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchRecordsCompanion.insert(
                matchId: matchId,
                profileId: profileId,
                executionId: executionId,
                sessionKind: sessionKind,
                origin: origin,
                gameMode: gameMode,
                difficulty: difficulty,
                playerCpuDifficulty: playerCpuDifficulty,
                islandCount: islandCount,
                status: status,
                outcome: outcome,
                startedAtUtc: startedAtUtc,
                endedAtUtc: endedAtUtc,
                recoveredAtUtc: recoveredAtUtc,
                elapsedMs: elapsedMs,
                dispatchCount: dispatchCount,
                forcesSent: forcesSent,
                captures: captures,
                appVersion: appVersion,
                rulesVersion: rulesVersion,
                metricsVersion: metricsVersion,
                receiptXp: receiptXp,
                receiptBefore: receiptBefore,
                receiptAfter: receiptAfter,
                receiptRewardVersion: receiptRewardVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<MatchRecords, MatchRecord>(table),
                  $MatchRecordsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable: $MatchRecordsReferences
                                    ._profileIdTable(db),
                                referencedColumn: $MatchRecordsReferences
                                    ._profileIdTable(db)
                                    .profileId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $MatchRecordsProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDatabase,
      MatchRecords,
      MatchRecord,
      $MatchRecordsFilterComposer,
      $MatchRecordsOrderingComposer,
      $MatchRecordsAnnotationComposer,
      $MatchRecordsCreateCompanionBuilder,
      $MatchRecordsUpdateCompanionBuilder,
      (MatchRecord, $MatchRecordsReferences),
      MatchRecord,
      PrefetchHooks Function({bool profileId})
    >;
typedef $XpEntriesCreateCompanionBuilder =
    XpEntriesCompanion Function({
      required String entryId,
      required String profileId,
      Value<String?> matchId,
      required String reason,
      required int amount,
      required String rewardVersion,
      required int totalXpBefore,
      required int totalXpAfter,
      required int createdAtUtc,
      Value<int> rowid,
    });
typedef $XpEntriesUpdateCompanionBuilder =
    XpEntriesCompanion Function({
      Value<String> entryId,
      Value<String> profileId,
      Value<String?> matchId,
      Value<String> reason,
      Value<int> amount,
      Value<String> rewardVersion,
      Value<int> totalXpBefore,
      Value<int> totalXpAfter,
      Value<int> createdAtUtc,
      Value<int> rowid,
    });

final class $XpEntriesReferences
    extends BaseReferences<_$ProfileDatabase, XpEntries, XpEntry> {
  $XpEntriesReferences(super.$_db, super.$_table, super.$_typedResult);

  static Profiles _profileIdTable(_$ProfileDatabase db) =>
      db.profiles.createAlias('xp_entries__profile_id__profiles__profile_id');

  $ProfilesProcessedTableManager get profileId {
    final $_column = $_itemColumn<String>('profile_id')!;

    final manager = $ProfilesTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.profileId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $XpEntriesFilterComposer extends Composer<_$ProfileDatabase, XpEntries> {
  $XpEntriesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matchId => $composableBuilder(
    column: $table.matchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rewardVersion => $composableBuilder(
    column: $table.rewardVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalXpBefore => $composableBuilder(
    column: $table.totalXpBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalXpAfter => $composableBuilder(
    column: $table.totalXpAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $ProfilesFilterComposer get profileId {
    final $ProfilesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProfilesFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $XpEntriesOrderingComposer
    extends Composer<_$ProfileDatabase, XpEntries> {
  $XpEntriesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchId => $composableBuilder(
    column: $table.matchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rewardVersion => $composableBuilder(
    column: $table.rewardVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalXpBefore => $composableBuilder(
    column: $table.totalXpBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalXpAfter => $composableBuilder(
    column: $table.totalXpAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $ProfilesOrderingComposer get profileId {
    final $ProfilesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProfilesOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $XpEntriesAnnotationComposer
    extends Composer<_$ProfileDatabase, XpEntries> {
  $XpEntriesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get matchId =>
      $composableBuilder(column: $table.matchId, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get rewardVersion => $composableBuilder(
    column: $table.rewardVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalXpBefore => $composableBuilder(
    column: $table.totalXpBefore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalXpAfter => $composableBuilder(
    column: $table.totalXpAfter,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  $ProfilesAnnotationComposer get profileId {
    final $ProfilesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ProfilesAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $XpEntriesTableManager
    extends
        RootTableManager<
          _$ProfileDatabase,
          XpEntries,
          XpEntry,
          $XpEntriesFilterComposer,
          $XpEntriesOrderingComposer,
          $XpEntriesAnnotationComposer,
          $XpEntriesCreateCompanionBuilder,
          $XpEntriesUpdateCompanionBuilder,
          (XpEntry, $XpEntriesReferences),
          XpEntry,
          PrefetchHooks Function({bool profileId})
        > {
  $XpEntriesTableManager(_$ProfileDatabase db, XpEntries table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $XpEntriesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $XpEntriesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $XpEntriesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String?> matchId = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String> rewardVersion = const Value.absent(),
                Value<int> totalXpBefore = const Value.absent(),
                Value<int> totalXpAfter = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => XpEntriesCompanion(
                entryId: entryId,
                profileId: profileId,
                matchId: matchId,
                reason: reason,
                amount: amount,
                rewardVersion: rewardVersion,
                totalXpBefore: totalXpBefore,
                totalXpAfter: totalXpAfter,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required String profileId,
                Value<String?> matchId = const Value.absent(),
                required String reason,
                required int amount,
                required String rewardVersion,
                required int totalXpBefore,
                required int totalXpAfter,
                required int createdAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => XpEntriesCompanion.insert(
                entryId: entryId,
                profileId: profileId,
                matchId: matchId,
                reason: reason,
                amount: amount,
                rewardVersion: rewardVersion,
                totalXpBefore: totalXpBefore,
                totalXpAfter: totalXpAfter,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<XpEntries, XpEntry>(table),
                  $XpEntriesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable: $XpEntriesReferences
                                    ._profileIdTable(db),
                                referencedColumn: $XpEntriesReferences
                                    ._profileIdTable(db)
                                    .profileId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $XpEntriesProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDatabase,
      XpEntries,
      XpEntry,
      $XpEntriesFilterComposer,
      $XpEntriesOrderingComposer,
      $XpEntriesAnnotationComposer,
      $XpEntriesCreateCompanionBuilder,
      $XpEntriesUpdateCompanionBuilder,
      (XpEntry, $XpEntriesReferences),
      XpEntry,
      PrefetchHooks Function({bool profileId})
    >;
typedef $StorageMetaCreateCompanionBuilder =
    StorageMetaCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $StorageMetaUpdateCompanionBuilder =
    StorageMetaCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $StorageMetaFilterComposer
    extends Composer<_$ProfileDatabase, StorageMeta> {
  $StorageMetaFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $StorageMetaOrderingComposer
    extends Composer<_$ProfileDatabase, StorageMeta> {
  $StorageMetaOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $StorageMetaAnnotationComposer
    extends Composer<_$ProfileDatabase, StorageMeta> {
  $StorageMetaAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $StorageMetaTableManager
    extends
        RootTableManager<
          _$ProfileDatabase,
          StorageMeta,
          StorageMetaData,
          $StorageMetaFilterComposer,
          $StorageMetaOrderingComposer,
          $StorageMetaAnnotationComposer,
          $StorageMetaCreateCompanionBuilder,
          $StorageMetaUpdateCompanionBuilder,
          (
            StorageMetaData,
            BaseReferences<_$ProfileDatabase, StorageMeta, StorageMetaData>,
          ),
          StorageMetaData,
          PrefetchHooks Function()
        > {
  $StorageMetaTableManager(_$ProfileDatabase db, StorageMeta table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $StorageMetaFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $StorageMetaOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $StorageMetaAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StorageMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => StorageMetaCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<StorageMeta, StorageMetaData>(table),
                  BaseReferences<
                    _$ProfileDatabase,
                    StorageMeta,
                    StorageMetaData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $StorageMetaProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDatabase,
      StorageMeta,
      StorageMetaData,
      $StorageMetaFilterComposer,
      $StorageMetaOrderingComposer,
      $StorageMetaAnnotationComposer,
      $StorageMetaCreateCompanionBuilder,
      $StorageMetaUpdateCompanionBuilder,
      (
        StorageMetaData,
        BaseReferences<_$ProfileDatabase, StorageMeta, StorageMetaData>,
      ),
      StorageMetaData,
      PrefetchHooks Function()
    >;

class $ProfileDatabaseManager {
  final _$ProfileDatabase _db;
  $ProfileDatabaseManager(this._db);
  $ProfilesTableManager get profiles =>
      $ProfilesTableManager(_db, _db.profiles);
  $MatchRecordsTableManager get matchRecords =>
      $MatchRecordsTableManager(_db, _db.matchRecords);
  $XpEntriesTableManager get xpEntries =>
      $XpEntriesTableManager(_db, _db.xpEntries);
  $StorageMetaTableManager get storageMeta =>
      $StorageMetaTableManager(_db, _db.storageMeta);
}
