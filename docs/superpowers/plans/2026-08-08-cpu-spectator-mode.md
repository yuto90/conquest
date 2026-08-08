# CPU対CPU観戦モード Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 通常CPU戦を維持しながら、1P・2Pの個別難易度、公平な同時判断、1P / 2P表示を備えたCPU対CPU観戦モードを追加する。

**Architecture:** `GameConfiguration`を島数・モード・両CPU難易度の正本とし、既存`Faction.player` / `Faction.cpu`は内部陣営IDとして維持する。`CpuStrategy`を操作陣営でパラメーター化し、`GameController`が陣営別strategyとゲーム内絶対期限を管理して、同時判断を同一スナップショットから収集後に適用する。表示文字列はUI専用`FactionPresentation`へ分離し、観戦モードだけ1P / 2P表記へ切り替える。

**Tech Stack:** Flutter 3.44.8、Dart 3.12.2、Riverpod 3、riverpod_annotation、flutter_test、FVM

## Global Constraints

- 対象IssueはGitHub Issue #32、ベースブランチは最新`main`とする。
- 設計の正本は`docs/superpowers/specs/2026-08-08-cpu-spectator-mode-design.md`と`docs/game-rules.md`とする。
- 初期モードは通常CPU戦、1P・2P CPU難易度の初期値は両方Normalとする。
- 既存`cpuDifficulty`は2P CPU難易度として互換性を維持する。
- 通常CPU戦のP / Player、C / CPU、Victory / Defeat / Draw表記と1P操作を維持する。
- 観戦モードだけ島・移動部隊・結果を1P / 2P、1P WIN / 2P WIN / DRAWと表示する。
- 同時刻に期限を迎えた両CPUは同じルールtick後スナップショットから判断する。
- 一時停止と再開では両CPUのゲーム内絶対期限を維持する。
- 観戦中はUIと`GameController.tapBase`の両方で人間の出兵を拒否する。
- 戦闘、増加、移動、勝敗、map生成アルゴリズムは変更しない。
- 観戦速度、途中介入、戦績・リプレイ保存、大会、CPU自作、オンライン対戦は追加しない。
- 各実装タスクはred-green-refactorで進め、タスク単位でfocused testsとコミットを完了する。

---

## File Structure

### Create

- `lib/faction_presentation.dart`: `GameMode`と`Faction`からmarkerとsemantic nameを返すUI専用値。

### Modify

- `lib/game/game_state.dart`: `GameMode`と1P CPU難易度を`GameConfiguration`へ追加する。
- `lib/game/cpu_strategy.dart`: 操作陣営と敵陣営を注入し、既存戦略を両陣営で再利用可能にする。
- `lib/game/game_controller.dart`: 1P strategy provider、設定API、陣営別期限、同時判断、操作防御を追加する。
- `lib/home.dart`: モード選択、条件付き難易度、開始Semantics、スクロール、盤面表示、結果表示を追加する。
- `lib/base.dart`: 注入された陣営表示と`onPressed`に一致するSemanticsを使用する。
- `lib/moving_force.dart`: 注入された陣営表示を使用する。
- `docs/game-rules.md`、`docs/integration-qa.md`: 観戦仕様と検証記録を追加する。

### Test

- `test/game_rules_test.dart`: 設定の初期値、copy、等価性、互換性。
- `test/cpu_strategy_test.dart`: 両陣営の攻撃・防衛・適用・対称性。
- `test/game_controller_test.dart`: 設定変更、map保持、操作防御、ライフサイクル。
- `test/cpu_controller_integration_test.dart`: 個別難易度、独立期限、同時判断、部隊ID。
- `test/widget_test.dart`: 設定UI、狭い画面、表示、Semantics、結果、再戦。
- `test/integration_qa_test.dart`: 全島数の開始、決定論的CPU対CPU試合、結果停止。

---

### Task 1: モードと両CPU難易度を設定モデルへ追加する

**Files:**
- Modify: `lib/game/game_state.dart:24-140`
- Test: `test/game_rules_test.dart:18-55`

**Interfaces:**
- Consumes: 既存`CpuDifficulty`、`GameConfiguration(totalIslandCount:, cpuDifficulty:)`。
- Produces: `GameMode`、`GameConfiguration.gameMode`、`GameConfiguration.playerCpuDifficulty`、拡張済み`copyWith` / equality / `hashCode`。

- [ ] **Step 1: 初期値と互換性の失敗テストを書く**

```dart
test('configuration defaults to player versus CPU with Normal CPUs', () {
  expect(GameConfiguration.initial.gameMode, GameMode.playerVsCpu);
  expect(
    GameConfiguration.initial.playerCpuDifficulty,
    CpuDifficulty.normal,
  );
  expect(GameConfiguration.initial.cpuDifficulty, CpuDifficulty.normal);
});

test('configuration copy and equality include mode and both difficulties', () {
  final spectator = GameConfiguration(
    totalIslandCount: 8,
    gameMode: GameMode.cpuVsCpu,
    playerCpuDifficulty: CpuDifficulty.hard,
    cpuDifficulty: CpuDifficulty.easy,
  );
  final standard = spectator.copyWith(gameMode: GameMode.playerVsCpu);

  expect(standard.gameMode, GameMode.playerVsCpu);
  expect(standard.playerCpuDifficulty, CpuDifficulty.hard);
  expect(standard.cpuDifficulty, CpuDifficulty.easy);
  expect(standard, isNot(spectator));
});
```

- [ ] **Step 2: テストが未定義APIで失敗することを確認する**

Run: `fvm flutter test test/game_rules_test.dart --plain-name "configuration defaults to player versus CPU with Normal CPUs"`

Expected: `GameMode`または`playerCpuDifficulty`が未定義でコンパイルFAIL。

- [ ] **Step 3: `GameMode`と設定フィールドを最小実装する**

```dart
enum GameMode { playerVsCpu, cpuVsCpu }

factory GameConfiguration({
  int? totalIslandCount,
  int? islandCount,
  GameMode? gameMode,
  CpuDifficulty? playerCpuDifficulty,
  CpuDifficulty? cpuDifficulty,
}) {
  final count = totalIslandCount ?? islandCount ?? defaultIslandCount;
  if (!isValidIslandCount(count)) {
    throw ArgumentError.value(
      count,
      'totalIslandCount',
      'must be one of 6, 8, 10, or 12',
    );
  }
  return GameConfiguration._(
    count,
    gameMode ?? GameMode.playerVsCpu,
    playerCpuDifficulty ?? CpuDifficulty.normal,
    cpuDifficulty ?? CpuDifficulty.normal,
  );
}

const GameConfiguration._(
  this.totalIslandCount,
  this.gameMode,
  this.playerCpuDifficulty,
  this.cpuDifficulty,
);

final GameMode gameMode;
final CpuDifficulty playerCpuDifficulty;
final CpuDifficulty cpuDifficulty;
```

`initial`、`copyWith`、`operator ==`、`hashCode`も4フィールドを同じ順で扱う。既存`cpuDifficulty`の引数名とfield名は変更しない。

- [ ] **Step 4: 設定テスト全体を通す**

Run: `fvm flutter test test/game_rules_test.dart`

Expected: PASS。既存の島数・難易度テストも成功する。

- [ ] **Step 5: formatと差分検査を行う**

Run: `fvm dart format lib/game/game_state.dart test/game_rules_test.dart && git diff --check`

Expected: format完了、`git diff --check`成功。

- [ ] **Step 6: 設定モデルをコミットする**

```bash
git add lib/game/game_state.dart test/game_rules_test.dart
git commit -m "feat: model spectator match settings"
```

---

### Task 2: 既存CPU戦略を操作陣営で汎用化する

**Files:**
- Modify: `lib/game/cpu_strategy.dart:45-548`
- Test: `test/cpu_strategy_test.dart`

**Interfaces:**
- Consumes: 既存`Faction`、`CpuDifficulty`、`CpuDecision`、`GameRules.createMovingForce`。
- Produces: `CpuStrategy(controlledFaction:)`、`CpuStrategy.noop(controlledFaction:)`。既定値は`Faction.cpu`。

- [ ] **Step 1: 1P CPUの攻撃と部隊陣営の失敗テストを書く**

```dart
test('player-controlled strategy dispatches only player forces', () {
  final strategy = CpuStrategy(
    controlledFaction: Faction.player,
    random: Random(1),
    viewport: _viewport,
  );
  final state = _playing(
    islands: [
      _island(id: 0, faction: Faction.player, forces: 40, x: 0.7, y: 0.7),
      _island(id: 1, faction: Faction.cpu, forces: 5, x: -0.7, y: -0.7),
    ],
  );

  final decision = strategy.decide(state)!;
  final next = strategy.applyDecision(state, decision, movingForceId: 9);

  expect(decision.sourceIslandId, 0);
  expect(next.movingForces.single.id, 9);
  expect(next.movingForces.single.faction, Faction.player);
});

test('neutral cannot be a controlled CPU faction', () {
  expect(
    CpuStrategy.noop(controlledFaction: Faction.player).controlledFaction,
    Faction.player,
  );
  expect(
    () => CpuStrategy(controlledFaction: Faction.neutral),
    throwsArgumentError,
  );
  expect(
    () => CpuStrategy.noop(controlledFaction: Faction.neutral),
    throwsArgumentError,
  );
});

test('player-controlled strategy rejects stale or foreign sources', () {
  final strategy = CpuStrategy(
    controlledFaction: Faction.player,
    random: Random(1),
    viewport: _viewport,
  );
  final state = _playing(
    islands: [
      _island(id: 0, faction: Faction.player, forces: 40),
      _island(id: 1, faction: Faction.cpu, forces: 5),
    ],
  );
  final decision = strategy.decide(state)!;
  final stale = state.copyWith(
    islands: [state.islands[0].copyWith(currentForces: 30), state.islands[1]],
  );
  final foreign = state.copyWith(
    islands: [
      state.islands[0].copyWith(faction: Faction.cpu),
      state.islands[1],
    ],
  );

  expect(strategy.applyDecision(stale, decision), same(stale));
  expect(strategy.applyDecision(foreign, decision), same(foreign));
});
```

- [ ] **Step 2: 1P APIが未実装で失敗することを確認する**

Run: `fvm flutter test test/cpu_strategy_test.dart --plain-name "player-controlled strategy dispatches only player forces"`

Expected: `controlledFaction`が未定義でコンパイルFAIL。

- [ ] **Step 3: 操作陣営と敵陣営の境界を実装する**

```dart
CpuStrategy({
  Faction controlledFaction = Faction.cpu,
  math.Random? random,
  GameRules? rules,
  IslandMapViewport viewport = GameRules.defaultMapViewport,
}) : this._(
       controlledFaction: _requirePlayableFaction(controlledFaction),
       random: random ?? math.Random(),
       rules: rules ?? const GameRules(),
       viewport: viewport,
     );

CpuStrategy.noop({
  Faction controlledFaction = Faction.cpu,
  GameRules? rules,
  IslandMapViewport viewport = GameRules.defaultMapViewport,
}) : this._(
       controlledFaction: _requirePlayableFaction(controlledFaction),
       random: math.Random(0),
       rules: rules ?? const GameRules(),
       viewport: viewport,
       enabled: false,
     );

CpuStrategy._({
  required this.controlledFaction,
  required this.random,
  required this.rules,
  required this.viewport,
  this.enabled = true,
});

static Faction _requirePlayableFaction(Faction faction) {
  if (faction == Faction.neutral) {
    throw ArgumentError.value(
      faction,
      'controlledFaction',
      'must be player or cpu',
    );
  }
  return faction;
}

final Faction controlledFaction;

Faction get _opponentFaction => switch (controlledFaction) {
  Faction.player => Faction.cpu,
  Faction.cpu => Faction.player,
  Faction.neutral => throw StateError('neutral cannot control a CPU strategy'),
};
```

public constructorと`noop`の両方から検証済み`controlledFaction`をprivate constructorへ渡し、`enabled`の意味を変えない。

- [ ] **Step 4: 攻撃・防衛・予測・適用の固定陣営参照を置換する**

```dart
if (source.faction != controlledFaction ||
    expectedStrength <= 0 ||
    decision.strength != expectedStrength) {
  return state;
}

final force = rules.createMovingForce(
  id: movingForceId ?? _nextMovingForceId(state),
  faction: controlledFaction,
  source: source,
  destination: destination,
  strength: expectedStrength,
  departureTimeMs: state.elapsedMs,
  viewport: viewport,
);
```

`_chooseDefense`では敵移動部隊を`_opponentFaction`、防衛対象と予測結果を`controlledFaction`で判定する。`_chooseAttack`、`_capturableCandidates`、`_candidateForce`も同じ2値だけを使用し、中立島判定は変更しない。

- [ ] **Step 5: 陣営反転の対称性テストを書く**

```dart
test('mirrored factions produce symmetric CPU decisions', () {
  final cpuStrategy = CpuStrategy(
    controlledFaction: Faction.cpu,
    random: Random(9),
    viewport: _viewport,
  );
  final playerStrategy = CpuStrategy(
    controlledFaction: Faction.player,
    random: Random(9),
    viewport: _viewport,
  );
  final cpuState = _playing(islands: _symmetricDecisionIslands());
  final playerState = _playing(
    islands: [
      for (final island in _symmetricDecisionIslands())
        island.copyWith(faction: _oppositeFaction(island.faction)),
    ],
  );

  expect(playerStrategy.decide(playerState), cpuStrategy.decide(cpuState));
});

List<IslandState> _symmetricDecisionIslands() => [
  _island(
    id: 0,
    faction: Faction.cpu,
    forces: 40,
    x: 0.7,
    y: 0,
  ),
  _island(
    id: 1,
    faction: Faction.player,
    forces: 5,
    x: -0.7,
    y: 0,
  ),
  _island(
    id: 2,
    faction: Faction.neutral,
    forces: 5,
    x: 0,
    y: 0.8,
    durability: 5,
  ),
];

Faction _oppositeFaction(Faction faction) => switch (faction) {
  Faction.player => Faction.cpu,
  Faction.cpu => Faction.player,
  Faction.neutral => Faction.neutral,
};
```

島ID・位置・兵力は変更せず、`CpuDecision`に陣営fieldを追加しない。

- [ ] **Step 6: CPU戦略テスト全体を通す**

Run: `fvm flutter test test/cpu_strategy_test.dart`

Expected: PASS。既存2P CPUの優先順位、難易度、再現性テストも成功する。

- [ ] **Step 7: formatしてコミットする**

```bash
fvm dart format lib/game/cpu_strategy.dart test/cpu_strategy_test.dart
git diff --check
git add lib/game/cpu_strategy.dart test/cpu_strategy_test.dart
git commit -m "refactor: make CPU strategy faction aware"
```

---

### Task 3: 設定APIと観戦モードの操作防御をControllerへ追加する

**Files:**
- Modify: `lib/game/game_controller.dart:226-390`
- Test: `test/game_controller_test.dart`

**Interfaces:**
- Consumes: Task 1の`GameMode`、`playerCpuDifficulty`。
- Produces: `selectGameMode(GameMode)`、`selectPlayerCpuDifficulty(CpuDifficulty)`、設定だけを更新するprivate helper、観戦モードを拒否する`tapBase`。

- [ ] **Step 1: モード・1P難易度・map保持の失敗テストを書く**

```dart
test('selects spectator settings without regenerating the map', () {
  final controller = container.read(gameControllerProvider.notifier);
  final before = container.read(gameControllerProvider);

  controller.selectGameMode(GameMode.cpuVsCpu);
  controller.selectPlayerCpuDifficulty(CpuDifficulty.hard);

  final after = container.read(gameControllerProvider);
  expect(after.configuration.gameMode, GameMode.cpuVsCpu);
  expect(after.configuration.playerCpuDifficulty, CpuDifficulty.hard);
  expect(after.configuration.cpuDifficulty, CpuDifficulty.normal);
  expect(after.islands, orderedEquals(before.islands));
});

test('ignores spectator setting changes after a match starts', () {
  final controller = container.read(gameControllerProvider.notifier);
  controller.startGame();
  final started = container.read(gameControllerProvider);

  controller.selectGameMode(GameMode.cpuVsCpu);
  controller.selectPlayerCpuDifficulty(CpuDifficulty.hard);

  expect(container.read(gameControllerProvider), same(started));
});
```

- [ ] **Step 2: 未実装APIで失敗することを確認する**

Run: `fvm flutter test test/game_controller_test.dart --plain-name "selects spectator settings without regenerating the map"`

Expected: `selectGameMode`または`selectPlayerCpuDifficulty`が未定義でコンパイルFAIL。

- [ ] **Step 3: 設定更新helperと公開APIを実装する**

```dart
void selectGameMode(GameMode mode) {
  if (_disposed || state.phase != GamePhase.configuration) return;
  if (state.configuration.gameMode == mode) return;
  _updateConfigurationWithoutRegeneratingMap(
    state.configuration.copyWith(gameMode: mode),
  );
}

void selectPlayerCpuDifficulty(CpuDifficulty difficulty) {
  if (_disposed || state.phase != GamePhase.configuration) return;
  if (state.configuration.playerCpuDifficulty == difficulty) return;
  _updateConfigurationWithoutRegeneratingMap(
    state.configuration.copyWith(playerCpuDifficulty: difficulty),
  );
}

void _updateConfigurationWithoutRegeneratingMap(
  GameConfiguration configuration,
) {
  final updated = state.copyWith(configuration: configuration);
  state = updated;
  _cachedConfiguration = configuration;
  _cachedViewport = ref.read(mapViewportProvider);
  _cachedInitialState = updated;
}
```

既存`selectCpuDifficulty`も同じhelperを使う。

- [ ] **Step 4: 観戦中の直接操作を拒否する失敗テストを書く**

```dart
test('ignores direct island taps while spectating', () {
  final controller = container.read(gameControllerProvider.notifier);
  controller.selectGameMode(GameMode.cpuVsCpu);
  controller.startGame();
  controller.state = container.read(gameControllerProvider).copyWith(
    phase: GamePhase.playing,
    countdownRemainingMs: 0,
  );
  final before = container.read(gameControllerProvider);

  controller.tapBase(0);
  controller.tapBase(1);

  expect(container.read(gameControllerProvider), same(before));
});
```

- [ ] **Step 5: `tapBase`へモードguardを追加する**

```dart
if (_disposed ||
    state.phase != GamePhase.playing ||
    state.configuration.gameMode != GameMode.playerVsCpu) {
  return;
}
```

- [ ] **Step 6: map生成失敗時に観戦を開始しない回帰テストを書く**

```dart
test('does not start spectator CPUs when map generation failed', () {
  final failedLoop = ManualGameLoop();
  final failedContainer = ProviderContainer(
    overrides: [
      gameConfigurationProvider.overrideWithValue(
        GameConfiguration(
          totalIslandCount: 6,
          gameMode: GameMode.cpuVsCpu,
        ),
      ),
      gameLoopProvider.overrideWithValue(failedLoop),
      mapViewportProvider.overrideWithValue(
        const IslandMapViewport(width: 180, height: 180),
      ),
      randomProvider.overrideWithValue(Random(1)),
      cpuStrategyProvider.overrideWithValue(CpuStrategy.noop()),
    ],
  );
  addTearDown(failedContainer.dispose);
  final controller = failedContainer.read(gameControllerProvider.notifier);
  final before = failedContainer.read(gameControllerProvider);
  expect(before.phase, GamePhase.configuration);
  expect(before.islands, isEmpty);

  controller.startGame();

  expect(failedContainer.read(gameControllerProvider), same(before));
  expect(failedLoop.isRunning, isFalse);
});
```

`startGame`のconfiguration分岐へ、生成済み島数が`configuration.totalIslandCount`と一致しない場合のearly returnを追加する。pauseからのresume開始はこのguardの対象にしない。

```dart
if (_disposed ||
    state.phase == GamePhase.playing ||
    (state.phase == GamePhase.configuration &&
        state.islands.length != state.configuration.totalIslandCount)) {
  return;
}
```

- [ ] **Step 7: Controller unit testsを通す**

Run: `fvm flutter test test/game_controller_test.dart`

Expected: PASS。通常CPU戦の選択・出兵・再戦テストも成功する。

- [ ] **Step 8: formatしてコミットする**

```bash
fvm dart format lib/game/game_controller.dart test/game_controller_test.dart
git diff --check
git add lib/game/game_controller.dart test/game_controller_test.dart
git commit -m "feat: configure CPU spectator matches"
```

---

### Task 4: 両CPUのprovider・判断期限・同時判断を実装する

**Files:**
- Modify: `lib/game/game_controller.dart:13-220,392-469`
- Test: `test/cpu_controller_integration_test.dart`
- Test: `test/game_controller_test.dart`

**Interfaces:**
- Consumes: Task 1の両難易度、Task 2の`CpuStrategy(controlledFaction:)`、Task 3のモード設定。
- Produces: `playerCpuRandomProvider`、`playerCpuStrategyProvider`、陣営別strategy map、陣営別絶対期限、同時判断batch。

- [ ] **Step 1: 1P providerと個別難易度の失敗テストを書く**

```dart
test('spectator CPUs use independent difficulty deadlines', () {
  final localLoop = ManualGameLoop();
  final localContainer = ProviderContainer(
    overrides: [
      gameLoopProvider.overrideWithValue(localLoop),
      randomProvider.overrideWithValue(Random(7)),
      playerCpuStrategyProvider.overrideWithValue(
        CpuStrategy(
          controlledFaction: Faction.player,
          random: ZeroRandom(),
          viewport: GameRules.defaultMapViewport,
        ),
      ),
      cpuStrategyProvider.overrideWithValue(
        CpuStrategy(
          controlledFaction: Faction.cpu,
          random: ZeroRandom(),
          viewport: GameRules.defaultMapViewport,
        ),
      ),
    ],
  );
  addTearDown(localContainer.dispose);
  final controller = localContainer.read(gameControllerProvider.notifier);
  controller.selectGameMode(GameMode.cpuVsCpu);
  controller.selectPlayerCpuDifficulty(CpuDifficulty.hard);
  controller.selectCpuDifficulty(CpuDifficulty.easy);
  controller.startGame();
  completeStartCountdown(localLoop);

  for (var index = 0; index < 15; index++) {
    localLoop.tick();
  }
  final state = localContainer.read(gameControllerProvider);
  expect(
    state.movingForces.where((force) => force.faction == Faction.player),
    hasLength(1),
  );
  expect(
    state.movingForces.where((force) => force.faction == Faction.cpu),
    isEmpty,
  );
});

test('standard mode never schedules the player CPU', () {
  final localLoop = ManualGameLoop();
  final localContainer = ProviderContainer(
    overrides: [
      gameLoopProvider.overrideWithValue(localLoop),
      randomProvider.overrideWithValue(Random(7)),
      playerCpuStrategyProvider.overrideWithValue(
        CpuStrategy(
          controlledFaction: Faction.player,
          random: ZeroRandom(),
          viewport: GameRules.defaultMapViewport,
        ),
      ),
      cpuStrategyProvider.overrideWithValue(
        CpuStrategy(
          controlledFaction: Faction.cpu,
          random: ZeroRandom(),
          viewport: GameRules.defaultMapViewport,
        ),
      ),
    ],
  );
  addTearDown(localContainer.dispose);
  final controller = localContainer.read(gameControllerProvider.notifier);
  controller.startGame();
  completeStartCountdown(localLoop);
  for (var index = 0; index < 30; index++) {
    localLoop.tick();
  }

  final state = localContainer.read(gameControllerProvider);
  expect(state.configuration.gameMode, GameMode.playerVsCpu);
  expect(
    state.movingForces.where((force) => force.faction == Faction.player),
    isEmpty,
  );
  expect(
    state.movingForces.where((force) => force.faction == Faction.cpu),
    hasLength(1),
  );
});
```

- [ ] **Step 2: 1P provider未定義で失敗することを確認する**

Run: `fvm flutter test test/cpu_controller_integration_test.dart --plain-name "spectator CPUs use independent difficulty deadlines"`

Expected: `playerCpuStrategyProvider`が未定義でコンパイルFAIL。

- [ ] **Step 3: 1P乱数・strategy providerを追加する**

```dart
final playerCpuRandomProvider = Provider<Random>((ref) => Random());

final playerCpuStrategyProvider = Provider<CpuStrategy>((ref) {
  return CpuStrategy(
    controlledFaction: Faction.player,
    random: ref.read(playerCpuRandomProvider),
    rules: ref.read(gameRulesProvider),
    viewport: ref.watch(mapViewportProvider),
  );
});
```

既存`cpuStrategyProvider`は`controlledFaction: Faction.cpu`を明示し、既存`randomProvider`を維持する。

- [ ] **Step 4: 単一期限を陣営別mapへ置き換える**

```dart
late Map<Faction, CpuStrategy> _cpuStrategies;
final Map<Faction, int> _nextCpuDecisionAtMsByFaction = {};

Iterable<Faction> get _activeCpuFactions =>
    state.configuration.gameMode == GameMode.cpuVsCpu
    ? const [Faction.player, Faction.cpu]
    : const [Faction.cpu];

CpuDifficulty _difficultyFor(Faction faction) => switch (faction) {
  Faction.player => state.configuration.playerCpuDifficulty,
  Faction.cpu => state.configuration.cpuDifficulty,
  Faction.neutral => throw ArgumentError.value(faction),
};

void _scheduleNextCpuDecision(Faction faction) {
  final strategy = _cpuStrategies[faction]!;
  _nextCpuDecisionAtMsByFaction[faction] =
      state.elapsedMs +
      strategy.nextDecisionDelayMs(difficulty: _difficultyFor(faction));
}

void _clearCpuDecisionDeadlines() {
  _nextCpuDecisionAtMsByFaction.clear();
}
```

`build`でstrategy mapを更新するがdeadline mapを再生成しない。`finish`、`returnToConfiguration`、`replayGame`、map生成失敗、結果確定の単一期限null代入を`_clearCpuDecisionDeadlines()`へ置換する。一時停止とresumeではclearしない。

- [ ] **Step 5: 同一スナップショットから判断を収集して適用する**

```dart
void _runCpuDecisionsIfDue() {
  final active = _activeCpuFactions.toList(growable: false);
  for (final faction in active) {
    _nextCpuDecisionAtMsByFaction.putIfAbsent(
      faction,
      () => state.elapsedMs +
          _cpuStrategies[faction]!.nextDecisionDelayMs(
            difficulty: _difficultyFor(faction),
          ),
    );
  }

  final due = [
    for (final faction in const [Faction.player, Faction.cpu])
      if (active.contains(faction) &&
          state.elapsedMs >= _nextCpuDecisionAtMsByFaction[faction]!)
        faction,
  ];
  if (due.isEmpty) return;

  final snapshot = state;
  final decisions = [
    for (final faction in due)
      (faction: faction, decision: _cpuStrategies[faction]!.decide(snapshot)),
  ];
  for (final entry in decisions) {
    final decision = entry.decision;
    if (decision != null) {
      state = _cpuStrategies[entry.faction]!.applyDecision(
        state,
        decision,
        movingForceId: _nextMovingForceId,
      );
    }
  }
  for (final faction in due) {
    _scheduleNextCpuDecision(faction);
  }
}
```

開始カウントダウンから`playing`へ遷移したときは有効な全陣営をscheduleする。resume countdownからの遷移では既存期限を上書きしない。

- [ ] **Step 6: 同時判断の公平性と部隊IDの失敗テストを書く**

```dart
test('simultaneous CPUs decide from the same pre-dispatch snapshot', () {
  final localLoop = ManualGameLoop();
  final playerStrategy = CpuStrategy(
    controlledFaction: Faction.player,
    random: ZeroRandom(),
    viewport: GameRules.defaultMapViewport,
  );
  final cpuStrategy = CpuStrategy(
    controlledFaction: Faction.cpu,
    random: ZeroRandom(),
    viewport: GameRules.defaultMapViewport,
  );
  final localContainer = ProviderContainer(
    overrides: [
      gameLoopProvider.overrideWithValue(localLoop),
      randomProvider.overrideWithValue(Random(7)),
      playerCpuStrategyProvider.overrideWithValue(playerStrategy),
      cpuStrategyProvider.overrideWithValue(cpuStrategy),
    ],
  );
  addTearDown(localContainer.dispose);
  final controller = localContainer.read(gameControllerProvider.notifier);
  controller.selectGameMode(GameMode.cpuVsCpu);
  controller.selectPlayerCpuDifficulty(CpuDifficulty.hard);
  controller.selectCpuDifficulty(CpuDifficulty.hard);
  controller.startGame();
  completeStartCountdown(localLoop);
  final started = localContainer.read(gameControllerProvider);
  final board = started.copyWith(
    islands: _simultaneousDecisionBoard(started.islands),
  );
  controller.state = board;

  // Hard + ZeroRandom is due at 750 ms. No island-growth boundary occurs
  // before then, so this is the exact post-rule-tick snapshot for both CPUs.
  final dueSnapshot = board.copyWith(elapsedMs: 750);
  final expectedPlayer = playerStrategy.decide(dueSnapshot)!;
  final expectedCpu = cpuStrategy.decide(dueSnapshot)!;
  expect(
    (expectedPlayer.sourceIslandId, expectedPlayer.destinationIslandId),
    (0, 1),
  );
  expect(
    (expectedCpu.sourceIslandId, expectedCpu.destinationIslandId),
    (2, 3),
  );

  // A sequential decide-and-apply loop would see 1P's troop and change the
  // 2P decision to defense. This assertion makes the fairness regression
  // observable rather than checking only that two troops exist.
  final afterPlayer = playerStrategy.applyDecision(
    dueSnapshot,
    expectedPlayer,
    movingForceId: 0,
  );
  final sequentialCpu = cpuStrategy.decide(afterPlayer)!;
  expect(sequentialCpu.kind, CpuDecisionKind.defense);
  expect(sequentialCpu.destinationIslandId, 1);

  for (var index = 0; index < 15; index++) {
    localLoop.tick();
  }
  final forces = localContainer.read(gameControllerProvider).movingForces;

  expect(forces.map((force) => force.faction), [Faction.player, Faction.cpu]);
  expect(forces.map((force) => force.id).toSet(), hasLength(forces.length));
  expect(
    forces.map((force) => (force.sourceIslandId, force.destinationIslandId)),
    [(0, 1), (2, 3)],
  );
});

List<IslandState> _simultaneousDecisionBoard(
  List<IslandState> generated,
) => [
  generated[0].copyWith(
    faction: Faction.player,
    currentForces: 100,
    durability: 0,
    x: -0.8,
    y: 0,
  ),
  generated[1].copyWith(
    faction: Faction.cpu,
    currentForces: 10,
    durability: 0,
    x: 0.8,
    y: 0,
  ),
  generated[2].copyWith(
    faction: Faction.cpu,
    currentForces: 100,
    durability: 0,
    x: 0.7,
    y: 0,
  ),
  generated[3].copyWith(
    faction: Faction.player,
    currentForces: 10,
    durability: 0,
    x: -0.7,
    y: 0,
  ),
];

test('one null simultaneous decision does not block the other CPU', () {
  final localLoop = ManualGameLoop();
  final localContainer = ProviderContainer(
    overrides: [
      gameLoopProvider.overrideWithValue(localLoop),
      randomProvider.overrideWithValue(Random(7)),
      playerCpuStrategyProvider.overrideWithValue(
        CpuStrategy.noop(controlledFaction: Faction.player),
      ),
      cpuStrategyProvider.overrideWithValue(
        CpuStrategy(
          controlledFaction: Faction.cpu,
          random: ZeroRandom(),
          viewport: GameRules.defaultMapViewport,
        ),
      ),
    ],
  );
  addTearDown(localContainer.dispose);
  final controller = localContainer.read(gameControllerProvider.notifier);
  controller.selectGameMode(GameMode.cpuVsCpu);
  controller.selectPlayerCpuDifficulty(CpuDifficulty.hard);
  controller.selectCpuDifficulty(CpuDifficulty.hard);
  controller.startGame();
  completeStartCountdown(localLoop);

  for (var index = 0; index < 15; index++) {
    localLoop.tick();
  }
  expect(
    localContainer
        .read(gameControllerProvider)
        .movingForces
        .where((force) => force.faction == Faction.cpu),
    hasLength(1),
  );
  for (var index = 0; index < 15; index++) {
    localLoop.tick();
  }
  expect(
    localContainer
        .read(gameControllerProvider)
        .movingForces
        .where((force) => force.faction == Faction.cpu),
    hasLength(2),
  );
});
```

盤面は、逐次判断なら2Pが`2 -> 1`防衛へ変わる一方、同一スナップショットなら`2 -> 3`攻撃を維持する構成で固定する。部隊の適用順も1P、2Pで固定されることを同じテストで確認する。

- [ ] **Step 7: pause・resume・resultの両期限回帰を追加する**

```dart
test('preserves both spectator deadlines across pause and stops at result', () {
  final localLoop = ManualGameLoop();
  final localContainer = ProviderContainer(
    overrides: [
      gameLoopProvider.overrideWithValue(localLoop),
      randomProvider.overrideWithValue(Random(7)),
      playerCpuStrategyProvider.overrideWithValue(
        CpuStrategy(
          controlledFaction: Faction.player,
          random: ZeroRandom(),
          viewport: GameRules.defaultMapViewport,
        ),
      ),
      cpuStrategyProvider.overrideWithValue(
        CpuStrategy(
          controlledFaction: Faction.cpu,
          random: ZeroRandom(),
          viewport: GameRules.defaultMapViewport,
        ),
      ),
    ],
  );
  addTearDown(localContainer.dispose);
  final controller = localContainer.read(gameControllerProvider.notifier);
  controller.selectGameMode(GameMode.cpuVsCpu);
  controller.selectPlayerCpuDifficulty(CpuDifficulty.hard);
  controller.selectCpuDifficulty(CpuDifficulty.easy);
  controller.startGame();
  completeStartCountdown(localLoop);

  for (var index = 0; index < 14; index++) {
    localLoop.tick();
  }
  final beforePause = localContainer.read(gameControllerProvider);
  expect(beforePause.elapsedMs, 700);
  expect(beforePause.movingForces, isEmpty);

  controller.pauseGame();
  controller.resumeGame();
  completeStartCountdown(localLoop);
  expect(localContainer.read(gameControllerProvider).elapsedMs, 700);
  expect(localContainer.read(gameControllerProvider).movingForces, isEmpty);

  localLoop.tick();
  expect(
    localContainer
        .read(gameControllerProvider)
        .movingForces
        .where((force) => force.faction == Faction.player),
    hasLength(1),
  );
  for (var index = 0; index < 44; index++) {
    localLoop.tick();
  }
  expect(
    localContainer
        .read(gameControllerProvider)
        .movingForces
        .where((force) => force.faction == Faction.cpu),
    isEmpty,
  );
  localLoop.tick();
  expect(
    localContainer
        .read(gameControllerProvider)
        .movingForces
        .where((force) => force.faction == Faction.cpu),
    isNotEmpty,
  );

  controller.finish(const GameResult.victory(elapsedMs: 3000));
  final result = localContainer.read(gameControllerProvider);
  localLoop.tick();
  expect(localContainer.read(gameControllerProvider), same(result));
});
```

- [ ] **Step 8: 再戦と設定復帰で設定を保持し期限を作り直すテストを書く**

```dart
test('replays spectator settings with fresh CPU deadlines', () {
  final localLoop = ManualGameLoop();
  final localContainer = ProviderContainer(
    overrides: [
      gameLoopProvider.overrideWithValue(localLoop),
      randomProvider.overrideWithValue(Random(7)),
      playerCpuStrategyProvider.overrideWithValue(
        CpuStrategy(
          controlledFaction: Faction.player,
          random: ZeroRandom(),
          viewport: GameRules.defaultMapViewport,
        ),
      ),
      cpuStrategyProvider.overrideWithValue(
        CpuStrategy(
          controlledFaction: Faction.cpu,
          random: ZeroRandom(),
          viewport: GameRules.defaultMapViewport,
        ),
      ),
    ],
  );
  addTearDown(localContainer.dispose);
  final controller = localContainer.read(gameControllerProvider.notifier);
  controller.selectGameMode(GameMode.cpuVsCpu);
  controller.selectPlayerCpuDifficulty(CpuDifficulty.hard);
  controller.selectCpuDifficulty(CpuDifficulty.easy);
  controller.startGame();
  completeStartCountdown(localLoop);
  controller.finish(const GameResult.victory(elapsedMs: 0));

  controller.replayGame();
  final replayCountdown = localContainer.read(gameControllerProvider);
  expect(replayCountdown.phase, GamePhase.startCountdown);
  expect(replayCountdown.configuration.gameMode, GameMode.cpuVsCpu);
  expect(
    replayCountdown.configuration.playerCpuDifficulty,
    CpuDifficulty.hard,
  );
  expect(replayCountdown.configuration.cpuDifficulty, CpuDifficulty.easy);
  expect(replayCountdown.movingForces, isEmpty);
  completeStartCountdown(localLoop);
  for (var index = 0; index < 14; index++) {
    localLoop.tick();
  }
  expect(
    localContainer
        .read(gameControllerProvider)
        .movingForces
        .where((force) => force.faction == Faction.player),
    isEmpty,
  );
  localLoop.tick();
  expect(
    localContainer
        .read(gameControllerProvider)
        .movingForces
        .where((force) => force.faction == Faction.player),
    hasLength(1),
  );

  controller.finish(const GameResult.victory(elapsedMs: 750));
  controller.returnToConfiguration();
  final settings = localContainer.read(gameControllerProvider);
  expect(settings.phase, GamePhase.configuration);
  expect(settings.configuration.gameMode, GameMode.cpuVsCpu);
  expect(settings.configuration.playerCpuDifficulty, CpuDifficulty.hard);
  expect(settings.configuration.cpuDifficulty, CpuDifficulty.easy);
  expect(settings.movingForces, isEmpty);
  expect(localLoop.isRunning, isFalse);
});
```

- [ ] **Step 9: Controller関連テストを通す**

Run: `fvm flutter test test/game_controller_test.dart test/cpu_controller_integration_test.dart`

Expected: PASS。通常CPU戦と観戦モードの期限テストがすべて成功する。

- [ ] **Step 10: formatしてコミットする**

```bash
fvm dart format lib/game/game_controller.dart test/game_controller_test.dart test/cpu_controller_integration_test.dart
git diff --check
git add lib/game/game_controller.dart test/game_controller_test.dart test/cpu_controller_integration_test.dart
git commit -m "feat: run independent spectator CPUs"
```

---

### Task 5: 設定パネルへ観戦モードと個別難易度を追加する

**Files:**
- Modify: `lib/home.dart:314-453`
- Test: `test/widget_test.dart:45-145,560-590`

**Interfaces:**
- Consumes: Task 1の`GameMode`と両難易度、Task 3の設定API。
- Produces: `game-mode-player-vs-cpu` / `game-mode-cpu-vs-cpu` keys、`player-cpu-difficulty-<name>` keys、既存`cpu-difficulty-<name>` keys、モード対応開始Semantics。

- [ ] **Step 1: モード選択と条件付き難易度の失敗Widgetテストを書く**

```dart
testWidgets('switches between standard and spectator settings', (tester) async {
  final semantics = tester.ensureSemantics();
  addTearDown(semantics.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [randomProvider.overrideWithValue(Random(1))],
      child: const MyApp(),
    ),
  );

  expect(find.byKey(const ValueKey('game-mode-player-vs-cpu')), findsOneWidget);
  expect(find.byKey(const ValueKey('game-mode-cpu-vs-cpu')), findsOneWidget);
  expect(
    find.byKey(const ValueKey('player-cpu-difficulty-normal')),
    findsNothing,
  );
  expect(find.byKey(const ValueKey('cpu-difficulty-normal')), findsOneWidget);
  final standardMode = find.byKey(
    const ValueKey('game-mode-player-vs-cpu'),
  );
  final spectatorMode = find.byKey(
    const ValueKey('game-mode-cpu-vs-cpu'),
  );
  expect(tester.widget<ChoiceChip>(standardMode).selected, isTrue);
  expect(
    tester.getSemantics(standardMode).getSemanticsData().flagsCollection.isSelected,
    Tristate.isTrue,
  );
  expect(tester.widget<ChoiceChip>(spectatorMode).selected, isFalse);

  await tester.tap(spectatorMode);
  await tester.pump();

  expect(
    find.byKey(const ValueKey('player-cpu-difficulty-normal')),
    findsOneWidget,
  );
  expect(
    tester
        .getSemantics(
          find.byKey(const ValueKey('player-cpu-difficulty-normal')),
        )
        .label,
    '1P Normal CPU difficulty',
  );
  expect(
    tester
        .getSemantics(find.byKey(const ValueKey('cpu-difficulty-normal')))
        .label,
    '2P Normal CPU difficulty',
  );
  expect(
    tester.getSemantics(find.byKey(const ValueKey('start-game'))).label,
    contains('Watch CPU versus CPU'),
  );
});
```

- [ ] **Step 2: 新規mode keyがなく失敗することを確認する**

Run: `fvm flutter test test/widget_test.dart --plain-name "switches between standard and spectator settings"`

Expected: 新規mode ChoiceChipが見つからずFAIL。

- [ ] **Step 3: 設定パネルの表示順とconditional rowsを実装する**

```dart
Widget _modeChoices(BuildContext context) {
  return Wrap(
    alignment: WrapAlignment.center,
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final mode in GameMode.values)
        ChoiceChip(
          key: ValueKey('game-mode-${_modeKey(mode)}'),
          label: Text(_modeLabel(mode)),
          selected: state.configuration.gameMode == mode,
          onSelected: (_) => _selectMode(context, mode),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          tooltip: _modeLabel(mode),
        ),
    ],
  );
}

Widget _difficultyHeading(String label) {
  return Semantics(
    header: true,
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

Widget _difficultyChoices({
  required String keyPrefix,
  required CpuDifficulty selected,
  required ValueChanged<CpuDifficulty> onSelected,
  String? semanticOwner,
}) {
  return Wrap(
    alignment: WrapAlignment.center,
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final difficulty in CpuDifficulty.values)
        ChoiceChip(
          key: ValueKey('$keyPrefix-${difficulty.name}'),
          label: Semantics(
            excludeSemantics: true,
            label: [
              if (semanticOwner != null) semanticOwner,
              _difficultyLabel(difficulty),
              'CPU difficulty',
            ].join(' '),
            child: Text(_difficultyLabel(difficulty)),
          ),
          selected: selected == difficulty,
          onSelected: (_) => onSelected(difficulty),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          tooltip: [
            if (semanticOwner != null) semanticOwner,
            _difficultyLabel(difficulty),
            'CPU difficulty',
          ].join(' '),
        ),
    ],
  );
}

String _modeKey(GameMode mode) => switch (mode) {
  GameMode.playerVsCpu => 'player-vs-cpu',
  GameMode.cpuVsCpu => 'cpu-vs-cpu',
};

String _modeLabel(GameMode mode) => switch (mode) {
  GameMode.playerVsCpu => 'PLAY VS CPU',
  GameMode.cpuVsCpu => 'WATCH CPU VS CPU',
};

void _selectMode(BuildContext context, GameMode mode) {
  ProviderScope.containerOf(
    context,
  ).read(gameControllerProvider.notifier).selectGameMode(mode);
}

void _selectPlayerDifficulty(
  BuildContext context,
  CpuDifficulty difficulty,
) {
  ProviderScope.containerOf(context)
      .read(gameControllerProvider.notifier)
      .selectPlayerCpuDifficulty(difficulty);
}
```

`Column`内の既存島数選択の直後へ`_modeChoices(context)`を置き、その後を次の条件分岐にする。

```dart

if (state.configuration.gameMode == GameMode.cpuVsCpu) ...[
  _difficultyHeading('1P CPU difficulty'),
  _difficultyChoices(
    keyPrefix: 'player-cpu-difficulty',
    selected: state.configuration.playerCpuDifficulty,
    semanticOwner: '1P',
    onSelected: (difficulty) =>
        _selectPlayerDifficulty(context, difficulty),
  ),
  _difficultyHeading('2P CPU difficulty'),
] else
  _difficultyHeading('Choose CPU difficulty'),

_difficultyChoices(
  keyPrefix: 'cpu-difficulty',
  selected: state.configuration.cpuDifficulty,
  semanticOwner: state.configuration.gameMode == GameMode.cpuVsCpu
      ? '2P'
      : null,
  onSelected: (difficulty) => _selectDifficulty(context, difficulty),
),
```

通常モードの既存`cpu-difficulty-<name>` keyと`Normal CPU difficulty`形式のlabelを維持する。観戦モードでは1P / 2PをchipのSemantics labelとtooltipにも含める。

- [ ] **Step 4: 開始ボタンSemanticsをモード別に実装する**

```dart
String _startLabel(GameConfiguration configuration) {
  final islands = configuration.totalIslandCount.toString() + ' islands';
  return switch (configuration.gameMode) {
    GameMode.playerVsCpu =>
      'Start game with ' + islands + ' on ' +
      _difficultyLabel(configuration.cpuDifficulty) +
      ' CPU difficulty',
    GameMode.cpuVsCpu =>
      'Watch CPU versus CPU with ' + islands +
      ', 1P ' + _difficultyLabel(configuration.playerCpuDifficulty) +
      ', 2P ' + _difficultyLabel(configuration.cpuDifficulty),
  };
}
```

- [ ] **Step 5: 280 x 500のスクロール回帰テストを書く**

```dart
testWidgets('keeps spectator controls operable on a 280 by 500 screen', (
  tester,
) async {
  await tester.binding.setSurfaceSize(const Size(280, 500));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [randomProvider.overrideWithValue(Random(1))],
      child: const MyApp(),
    ),
  );

  await tester.tap(find.byKey(const ValueKey('game-mode-cpu-vs-cpu')));
  await tester.pump();
  expect(tester.takeException(), isNull);
  await tester.ensureVisible(find.byKey(const ValueKey('start-game')));
  await tester.tap(
    find.byKey(const ValueKey('player-cpu-difficulty-hard')),
  );
  await tester.tap(find.byKey(const ValueKey('cpu-difficulty-easy')));
  await tester.pump();

  final container = ProviderScope.containerOf(
    tester.element(find.byKey(const ValueKey('start-game'))),
  );
  final configuration = container
      .read(gameControllerProvider)
      .configuration;
  expect(configuration.gameMode, GameMode.cpuVsCpu);
  expect(configuration.playerCpuDifficulty, CpuDifficulty.hard);
  expect(configuration.cpuDifficulty, CpuDifficulty.easy);
  expect(find.byKey(const ValueKey('start-game')), findsOneWidget);
  expect(tester.takeException(), isNull);
});
```

設定パネルの外側を`SingleChildScrollView`で包み、Safe Area内で全設定へ到達できるようにする。mapのStack構造と設定時の背景表示は維持する。

- [ ] **Step 6: resizeで設定と両CPU期限を保持するWidget回帰を書く**

```dart
testWidgets('preserves spectator deadlines across a viewport rebuild', (
  tester,
) async {
  final loop = ManualWidgetGameLoop();
  await tester.binding.setSurfaceSize(const Size(320, 500));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
        playerCpuStrategyProvider.overrideWithValue(
          CpuStrategy(
            controlledFaction: Faction.player,
            random: _WidgetZeroRandom(),
            viewport: GameRules.defaultMapViewport,
          ),
        ),
        cpuStrategyProvider.overrideWithValue(
          CpuStrategy(
            controlledFaction: Faction.cpu,
            random: _WidgetZeroRandom(),
            viewport: GameRules.defaultMapViewport,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('game-mode-cpu-vs-cpu')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('player-cpu-difficulty-hard')));
  await tester.tap(find.byKey(const ValueKey('cpu-difficulty-easy')));
  await tester.tap(find.byKey(const ValueKey('start-game')));
  for (var index = 0; index < 60; index++) {
    loop.tick();
  }
  for (var index = 0; index < 9; index++) {
    loop.tick();
  }
  await tester.pump();

  final before = ProviderScope.containerOf(
    tester.element(find.byKey(const ValueKey('island-0'))),
  ).read(gameControllerProvider);
  expect(before.elapsedMs, 450);
  expect(before.configuration.gameMode, GameMode.cpuVsCpu);
  expect(before.configuration.playerCpuDifficulty, CpuDifficulty.hard);
  expect(before.configuration.cpuDifficulty, CpuDifficulty.easy);

  await tester.binding.setSurfaceSize(const Size(321, 500));
  await tester.pump();
  final afterContainer = ProviderScope.containerOf(
    tester.element(find.byKey(const ValueKey('island-0'))),
  );
  final after = afterContainer.read(gameControllerProvider);
  expect(after.elapsedMs, 450);
  expect(after.configuration, before.configuration);
  expect(loop.isRunning, isTrue);

  for (var index = 0; index < 5; index++) {
    loop.tick();
  }
  expect(afterContainer.read(gameControllerProvider).movingForces, isEmpty);
  loop.tick();
  expect(
    afterContainer
        .read(gameControllerProvider)
        .movingForces
        .where((force) => force.faction == Faction.player),
    hasLength(1),
  );
  expect(
    afterContainer
        .read(gameControllerProvider)
        .movingForces
        .where((force) => force.faction == Faction.cpu),
    isEmpty,
  );
  for (var index = 0; index < 44; index++) {
    loop.tick();
  }
  expect(
    afterContainer
        .read(gameControllerProvider)
        .movingForces
        .where((force) => force.faction == Faction.cpu),
    isEmpty,
  );
  loop.tick();
  expect(
    afterContainer
        .read(gameControllerProvider)
        .movingForces
        .where((force) => force.faction == Faction.cpu),
    isNotEmpty,
  );
});
```

- [ ] **Step 7: 設定Widget testsを通す**

Run: `fvm flutter test test/widget_test.dart --plain-name "switches between standard and spectator settings" && fvm flutter test test/widget_test.dart --plain-name "keeps spectator controls operable on a 280 by 500 screen" && fvm flutter test test/widget_test.dart --plain-name "preserves spectator deadlines across a viewport rebuild"`

Expected: 3テストPASS。

- [ ] **Step 8: formatしてコミットする**

```bash
fvm dart format lib/home.dart test/widget_test.dart
git diff --check
git add lib/home.dart test/widget_test.dart
git commit -m "feat: add spectator match settings UI"
```

---

### Task 6: 1P / 2P表示、観戦Semantics、結果表示を実装する

**Files:**
- Create: `lib/faction_presentation.dart`
- Modify: `lib/base.dart:11-188`
- Modify: `lib/moving_force.dart:11-116`
- Modify: `lib/home.dart:68-131,248-311`
- Test: `test/widget_test.dart:180-220,380-445,980-1005`

**Interfaces:**
- Consumes: Task 1の`GameMode`、既存`Faction`、`GameResult.winner`。
- Produces: `FactionPresentation.forMode(GameMode, Faction)`、`Base(presentation:)`、`MovingForceWidget(presentation:)`、モード対応ResultPanel。

- [ ] **Step 1: モード別陣営表示の失敗テストを書く**

```dart
testWidgets('uses 1P and 2P presentation only while spectating', (tester) async {
  final semantics = tester.ensureSemantics();
  addTearDown(semantics.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        randomProvider.overrideWithValue(Random(1)),
        gameConfigurationProvider.overrideWithValue(
          GameConfiguration(gameMode: GameMode.cpuVsCpu),
        ),
      ],
      child: const MyApp(),
    ),
  );
  expect(
    tester.getSemantics(
      find.byKey(const ValueKey('island-button-0')),
    ).label,
    contains('1P'),
  );
  expect(
    tester.getSemantics(
      find.byKey(const ValueKey('island-button-1')),
    ).label,
    contains('2P'),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        randomProvider.overrideWithValue(Random(1)),
        gameConfigurationProvider.overrideWithValue(
          GameConfiguration(gameMode: GameMode.playerVsCpu),
        ),
      ],
      child: const MyApp(),
    ),
  );
  expect(
    tester.getSemantics(
      find.byKey(const ValueKey('island-button-0')),
    ).label,
    contains('Player'),
  );
});

testWidgets('uses spectator presentation for moving troops', (tester) async {
  final semantics = tester.ensureSemantics();
  addTearDown(semantics.dispose);
  final force = MovingForce(
    id: 7,
    faction: Faction.player,
    sourceIslandId: 0,
    destinationIslandId: 1,
    strength: 20,
    arrivalTimeMs: 1000,
    durationMs: 1000,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: MovingForceWidget(
        force: force,
        presentation: FactionPresentation.forMode(
          GameMode.cpuVsCpu,
          Faction.player,
        ),
      ),
    ),
  );

  expect(find.text('1P'), findsOneWidget);
  expect(
    tester.getSemantics(find.byType(MovingForceWidget)).label,
    contains('1P'),
  );
});
```

- [ ] **Step 2: 観戦表示が未実装で失敗することを確認する**

Run: `fvm flutter test test/widget_test.dart --plain-name "uses 1P and 2P presentation only while spectating"`

Expected: 観戦モードでもPlayer / CPUが読み上げられてFAIL。

- [ ] **Step 3: `FactionPresentation`を実装する**

```dart
import 'game/game_state.dart';

final class FactionPresentation {
  const FactionPresentation({
    required this.marker,
    required this.semanticName,
  });

  factory FactionPresentation.forMode(GameMode mode, Faction faction) {
    return switch ((mode, faction)) {
      (GameMode.cpuVsCpu, Faction.player) =>
        const FactionPresentation(marker: '1P', semanticName: '1P'),
      (GameMode.cpuVsCpu, Faction.cpu) =>
        const FactionPresentation(marker: '2P', semanticName: '2P'),
      (_, Faction.player) =>
        const FactionPresentation(marker: 'P', semanticName: 'Player'),
      (_, Faction.cpu) =>
        const FactionPresentation(marker: 'C', semanticName: 'CPU'),
      (_, Faction.neutral) =>
        const FactionPresentation(marker: 'N', semanticName: 'Neutral'),
    };
  }

  final String marker;
  final String semanticName;
}
```

- [ ] **Step 4: 島と移動部隊へpresentationを注入する**

```dart
// base.dart
const Base({
  required this.base,
  required this.onPressed,
  this.presentation,
  this.selected = false,
  this.destinationCandidate = false,
  super.key,
});

final FactionPresentation? presentation;

// moving_force.dart
const MovingForceWidget({
  required this.force,
  this.presentation,
  this.semanticsKey,
  super.key,
});

final FactionPresentation? presentation;

FactionPresentation get _effectivePresentation =>
    presentation ??
    FactionPresentation.forMode(GameMode.playerVsCpu, force.faction);

String get _marker => _effectivePresentation.marker;
String get _factionName => _effectivePresentation.semanticName;

// home.dart
final presentation = FactionPresentation.forMode(
  state.configuration.gameMode,
  island.faction,
);

Base(
  base: island,
  presentation: presentation,
  onPressed: isPlayerInteractionEnabled
      ? () => controller.tapBase(island.id)
      : null,
);

MovingForceWidget(
  force: force,
  presentation: FactionPresentation.forMode(
    state.configuration.gameMode,
    force.faction,
  ),
);
```

`Base`側も`_marker`と`_factionName`を`_effectivePresentation`へ委譲する。省略時は`GameMode.playerVsCpu`の既存表示を使い、色とoutline shapeのswitchは変更しない。

- [ ] **Step 5: 観戦中のSemantics actionを拒否する失敗テストを書く**

```dart
testWidgets('spectator islands expose no actionable semantics', (tester) async {
  final semanticsHandle = tester.ensureSemantics();
  addTearDown(semanticsHandle.dispose);
  final loop = ManualWidgetGameLoop();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
        gameConfigurationProvider.overrideWithValue(
          GameConfiguration(gameMode: GameMode.cpuVsCpu),
        ),
      ],
      child: const MyApp(),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('start-game')));
  for (var index = 0; index < 60; index++) {
    loop.tick();
  }
  await tester.pump();

  final semantics = tester.getSemantics(
    find.byKey(const ValueKey('island-button-0')),
  ).getSemanticsData();
  expect(semantics.hasAction(SemanticsAction.tap), isFalse);
  expect(semantics.flagsCollection.isButton, Tristate.isFalse);
  expect(semantics.hint, isEmpty);
  expect(semantics.label, isNot(contains('dispatch source')));
});
```

- [ ] **Step 6: `Base`のSemanticsを`onPressed`へ同期する**

```dart
final interactive = onPressed != null;
return Semantics(
  container: true,
  excludeSemantics: true,
  button: interactive,
  enabled: interactive,
  onTap: onPressed,
  selected: interactive && selected,
  label: _semanticLabel,
  hint: interactive ? _semanticHint : null,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: _backgroundColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.all(3),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: _shape,
    ),
    onPressed: onPressed,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _effectivePresentation.marker,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        if (base.faction == Faction.neutral)
          Text(
            base.currentDurability.toString(),
            key: ValueKey('island-${base.id}-value'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          )
        else ...[
          Text(
            base.currentForces.toString(),
            key: ValueKey('island-${base.id}-current'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          Text(
            '/${base.capacity}',
            key: ValueKey('island-${base.id}-capacity'),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ],
    ),
  ),
);
```

非interactive labelは所属、島種別、現在値、上限または耐久力だけを含める。通常モードのselected source、destination、unavailable source表現は維持する。

```dart
String get _semanticLabel {
  final value = base.faction == Faction.neutral
      ? 'durability ${base.currentDurability}'
      : 'forces ${base.currentForces} of ${base.capacity}';
  final identity = '${_effectivePresentation.semanticName} $_sizeName, '
      '$value, current value ${base.currentValue}';
  if (onPressed == null) return identity;
  final action = selected
      ? 'selected dispatch source'
      : destinationCandidate
      ? 'valid dispatch destination'
      : base.canDispatch
      ? 'available dispatch source'
      : 'not available as dispatch source';
  return '$identity, $action';
}

FactionPresentation get _effectivePresentation =>
    presentation ??
    FactionPresentation.forMode(GameMode.playerVsCpu, base.faction);
```

- [ ] **Step 7: 結果表示のモード別テストを書く**

```dart
testWidgets('labels spectator winners as 1P and 2P', (tester) async {
  final loop = ManualWidgetGameLoop();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
      ],
      child: const MyApp(),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('game-mode-cpu-vs-cpu')));
  await tester.pump();
  final container = ProviderScope.containerOf(
    tester.element(find.byKey(const ValueKey('island-0'))),
  );
  final controller = container.read(gameControllerProvider.notifier);
  controller.startGame();
  for (var index = 0; index < 60; index++) {
    loop.tick();
  }

  controller.finish(
    const GameResult.victory(elapsedMs: 1, winner: Faction.player),
  );
  await tester.pump();
  expect(find.text('1P WIN'), findsOneWidget);

  controller.returnToConfiguration();
  controller.startGame();
  for (var index = 0; index < 60; index++) {
    loop.tick();
  }
  controller.finish(
    const GameResult.defeat(elapsedMs: 2, winner: Faction.cpu),
  );
  await tester.pump();
  expect(find.text('2P WIN'), findsOneWidget);
});

testWidgets('uses mode-specific draw labels', (tester) async {
  for (final entry in const [
    (mode: GameMode.playerVsCpu, title: 'Draw'),
    (mode: GameMode.cpuVsCpu, title: 'DRAW'),
  ]) {
    final loop = ManualWidgetGameLoop();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLoopProvider.overrideWithValue(loop),
          randomProvider.overrideWithValue(Random(1)),
          gameConfigurationProvider.overrideWithValue(
            GameConfiguration(gameMode: entry.mode),
          ),
        ],
        child: const MyApp(),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('island-0'))),
    );
    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame();
    for (var index = 0; index < 60; index++) {
      loop.tick();
    }
    controller.finish(const GameResult.draw(elapsedMs: 1));
    await tester.pump();

    expect(find.text(entry.title), findsOneWidget);
  }
});
```

既存通常モードのVictory / Defeat / Draw testは削除せず、観戦モードの結果分岐を追加する。

- [ ] **Step 8: ResultPanelを設定とwinnerで切り替える**

```dart
String _resultTitle(GameConfiguration configuration, GameResult result) {
  if (configuration.gameMode == GameMode.playerVsCpu) {
    return switch (result.type) {
      GameResultType.victory => 'Victory',
      GameResultType.defeat => 'Defeat',
      GameResultType.draw => 'Draw',
    };
  }
  return switch (result.winner) {
    Faction.player => '1P WIN',
    Faction.cpu => '2P WIN',
    Faction.neutral || null => 'DRAW',
  };
}
```

`_ResultPanel`へ`GameConfiguration`を渡し、再戦と設定復帰callbackは変更しない。

- [ ] **Step 9: Widget tests全体を通す**

Run: `fvm flutter test test/widget_test.dart`

Expected: PASS。通常CPU戦の既存Semantics、操作、結果テストも成功する。

- [ ] **Step 10: formatしてコミットする**

```bash
fvm dart format lib/faction_presentation.dart lib/base.dart lib/moving_force.dart lib/home.dart test/widget_test.dart
git diff --check
git add lib/faction_presentation.dart lib/base.dart lib/moving_force.dart lib/home.dart test/widget_test.dart
git commit -m "feat: present spectator factions and results"
```

---

### Task 7: 観戦モードの統合QAと文書を完成させる

**Files:**
- Modify: `test/integration_qa_test.dart`
- Modify: `docs/game-rules.md`
- Modify: `docs/integration-qa.md`

**Interfaces:**
- Consumes: Task 1-6の完成した設定、両strategy、Controller、UI。
- Produces: 全島数開始と決定論的試合の回帰証跡、更新済みルール・QA文書。

- [ ] **Step 1: 全島数で両CPUが動く統合テストを書く**

```dart
ProviderContainer _createSpectatorContainer({
  required _QaManualLoop loop,
  required int islandCount,
  required int mapSeed,
  required int playerCpuSeed,
  required int cpuSeed,
}) {
  return ProviderContainer(
    overrides: [
      gameConfigurationProvider.overrideWithValue(
        GameConfiguration(
          totalIslandCount: islandCount,
          gameMode: GameMode.cpuVsCpu,
        ),
      ),
      gameLoopProvider.overrideWithValue(loop),
      randomProvider.overrideWithValue(Random(mapSeed)),
      playerCpuStrategyProvider.overrideWithValue(
        CpuStrategy(
          controlledFaction: Faction.player,
          random: Random(playerCpuSeed),
          viewport: GameRules.defaultMapViewport,
        ),
      ),
      cpuStrategyProvider.overrideWithValue(
        CpuStrategy(
          controlledFaction: Faction.cpu,
          random: Random(cpuSeed),
          viewport: GameRules.defaultMapViewport,
        ),
      ),
    ],
  );
}

test('starts spectator CPUs on every supported island count', () {
  for (final islandCount in GameConfiguration.allowedIslandCounts) {
    final loop = _QaManualLoop();
    final container = _createSpectatorContainer(
      loop: loop,
      islandCount: islandCount,
      mapSeed: 3200 + islandCount,
      playerCpuSeed: 10,
      cpuSeed: 20,
    );
    try {
      _startMatch(container, loop);
      final observedFactions = <Faction>{};
      for (var tick = 0; tick < 120; tick++) {
        loop.tick();
        observedFactions.addAll(
          container
              .read(gameControllerProvider)
              .movingForces
              .map((force) => force.faction),
        );
      }
      final state = container.read(gameControllerProvider);
      expect(state.configuration.gameMode, GameMode.cpuVsCpu);
      expect(observedFactions, contains(Faction.player));
      expect(observedFactions, contains(Faction.cpu));
    } finally {
      container.dispose();
    }
  }
});
```

- [ ] **Step 2: 決定論的CPU対CPU結果の統合テストを書く**

```dart
_MatchTrace _runSpectatorMatch({
  required int islandCount,
  required int mapSeed,
  required int playerCpuSeed,
  required int cpuSeed,
}) {
  final loop = _QaManualLoop();
  final container = _createSpectatorContainer(
    loop: loop,
    islandCount: islandCount,
    mapSeed: mapSeed,
    playerCpuSeed: playerCpuSeed,
    cpuSeed: cpuSeed,
  );
  try {
    final controller = container.read(gameControllerProvider.notifier);
    final started = _startMatch(container, loop);
    controller.state = started.copyWith(
      islands: [
        for (final island in started.islands)
          if (island.id == 0)
            island.copyWith(
              faction: Faction.player,
              currentForces: 100,
              durability: 0,
            )
          else if (island.id == 1)
            island.copyWith(
              faction: Faction.cpu,
              currentForces: 1,
              durability: 0,
            )
          else
            island.copyWith(
              faction: Faction.player,
              currentForces: 1,
              durability: 0,
            ),
      ],
    );

    var ticks = 0;
    while (container.read(gameControllerProvider).phase != GamePhase.result &&
        ticks < 600) {
      loop.tick();
      ticks++;
    }
    final resultState = container.read(gameControllerProvider);
    expect(resultState.phase, GamePhase.result);
    expect(resultState.result, isNotNull);
    final trace = _MatchTrace(
      resultType: resultState.result!.type,
      winner: resultState.result!.winner,
      elapsedMs: resultState.result!.elapsedMs,
      ticks: ticks,
    );

    loop.tickMany(10);
    expect(container.read(gameControllerProvider), same(resultState));
    return trace;
  } finally {
    container.dispose();
  }
}

test('replays the same spectator result with fixed CPU seeds', () {
  final first = _runSpectatorMatch(
    islandCount: 6,
    mapSeed: 3206,
    playerCpuSeed: 41,
    cpuSeed: 42,
  );
  final second = _runSpectatorMatch(
    islandCount: 6,
    mapSeed: 3206,
    playerCpuSeed: 41,
    cpuSeed: 42,
  );

  expect(second, first);
  expect(first.resultType, GameResultType.victory);
  expect(first.winner, Faction.player);
});
```

既存`_MatchTrace`を再利用する。固定盤面は1Pが有限tickで勝つ一方、Task 7 Step 1の生成mapテストでは両陣営の実出兵を別途確認する。

- [ ] **Step 3: focused integration testsを実行する**

Run: `fvm flutter test test/integration_qa_test.dart --plain-name "starts spectator CPUs on every supported island count" && fvm flutter test test/integration_qa_test.dart --plain-name "replays the same spectator result with fixed CPU seeds"`

Expected: 両テストPASS。

- [ ] **Step 4: `docs/game-rules.md`へ確定仕様を追記する**

```markdown
- ゲーム開始前に通常CPU戦とCPU対CPU観戦モードを選択できる。
- 観戦モードでは1P CPUと2P CPUの難易度を個別に選択する。初期値は両方Normalとする。
- 両CPUが同時刻に判断する場合は、同じ更新後状態から両方の判断を決めてから適用する。
- 観戦中は島を選択・出兵できない。
- 観戦モードでは両陣営を1P・2Pとして表示し、結果を1P WIN・2P WIN・DRAWとして表示する。
```

通常CPU戦のPlayer / CPUルールとIssue #4 / #5の対象外境界を削除しない。

- [ ] **Step 5: `docs/integration-qa.md`へ自動・端末QA項目を追加する**

```markdown
| CPU対CPU観戦モード | 自動PASS | 全島数の開始、個別難易度、同時判断、結果停止を固定乱数とManualGameLoopで確認。 |
| 観戦モードの1P / 2P表示 | 自動PASS・端末未確認 | 島、移動部隊、結果、Semanticsをwidget testで確認。 |
```

実端末で未実施の項目をPASSと記録しない。

- [ ] **Step 6: 全自動テストと静的解析を実行する**

Run: `fvm flutter analyze && fvm flutter test`

Expected: analyze `No issues found`、全tests PASS。

- [ ] **Step 7: formatとdiff checkを実行する**

Run: `fvm dart format lib test && git diff --check`

Expected: format完了、whitespace errorなし。

- [ ] **Step 8: 統合QAと文書をコミットする**

```bash
git add test/integration_qa_test.dart docs/game-rules.md docs/integration-qa.md
git commit -m "test: cover CPU spectator matches"
```

---

### Task 8: 最新HEADの最終検証とレビュー準備を行う

**Files:**
- Verify: `lib/`
- Verify: `test/`
- Verify: `docs/game-rules.md`
- Verify: `docs/integration-qa.md`
- Verify: `docs/superpowers/specs/2026-08-08-cpu-spectator-mode-design.md`

**Interfaces:**
- Consumes: Task 1-7の全成果物。
- Produces: 現在HEADに紐づく検証証跡とIssue #32の受け入れ条件対応表。

- [ ] **Step 1: 生成物の必要性を確認する**

Run: `git diff origin/main...HEAD -- lib/game/game_controller.dart lib/game/game_controller.g.dart`

Expected: 新しい`@riverpod`宣言を追加していなければ生成物変更不要。生成宣言を変更した場合だけ`fvm dart run build_runner build --delete-conflicting-outputs`を実行し、意図した生成差分だけを残す。

- [ ] **Step 2: focused testsをまとめて再実行する**

Run: `fvm flutter test test/game_rules_test.dart test/cpu_strategy_test.dart test/game_controller_test.dart test/cpu_controller_integration_test.dart test/widget_test.dart test/integration_qa_test.dart`

Expected: 全focused tests PASS。

- [ ] **Step 3: 全検証ゲートを現在HEADで実行する**

Run: `fvm dart format --output=none --set-exit-if-changed lib test && fvm flutter analyze && fvm flutter test && git diff --check`

Expected: formatter差分なし、analyze `No issues found`、全tests PASS、diff check成功。

- [ ] **Step 4: Issue #32の受け入れ条件を差分とテストへ対応付ける**

Run: `gh issue view 32 --repo yuto90/conquest --json body --jq .body`

Expected: 各checkboxについて実装ファイルまたは成功したテスト名をPR本文へ記載でき、対象外機能の差分がない。

- [ ] **Step 5: 作業ツリーとコミット列を確認する**

Run: `git status --short --branch && git log --oneline origin/main..HEAD && git diff --stat origin/main...HEAD`

Expected: 作業ツリーがクリーンで、Task 1-7の意図したコミットとファイルだけが含まれる。

- [ ] **Step 6: 最終差分が発生した場合だけコミットする**

formatまたは生成物確認で差分が発生した場合だけ実行する。差分がなければ空コミットは作らない。

```bash
git add lib test docs
git commit -m "chore: finalize CPU spectator mode"
```

---

## Delivery Handoff

この計画の承認後は`deliver-approved-issue`を使用する。

- Issue: `https://github.com/yuto90/conquest/issues/32`
- Design: `docs/superpowers/specs/2026-08-08-cpu-spectator-mode-design.md`
- Plan: `docs/superpowers/plans/2026-08-08-cpu-spectator-mode.md`
- Repository: `yuto90/conquest`
- Base: `main`
- PRはReadyで作成し、mergeしない。
- PR全体で`@codex review`は1回だけ依頼する。
- 最新HEADのローカル検証、`final_reviewer`承認、GitHub Codex指摘対応、required checks成功、構造化振り返り、`@yuto90`への完了通知まで`issue_orchestrator`が管理する。
