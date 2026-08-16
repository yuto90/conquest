# 同一端末2人対戦モード Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 通常CPU戦とCPU対CPU観戦を維持しながら、同一端末の1画面で1Pと2Pが独立に選択・出兵できるローカル2人対戦を追加する。

**Architecture:** `GameMode.playerVsPlayer`を追加し、`Faction.player`を1P、`Faction.cpu`を2Pの内部IDとして維持する。人間入力は陣営付き`tapBase`へ一般化し、2人対戦のポインター帰属は盤面`Listener`が解決する。選択は`selectedIslandId`（1P）と`opponentSelectedIslandId`（2P）に分離する。戦闘・増加・移動・勝敗アルゴリズムは変更しない。

**Tech Stack:** Flutter 3.44.8、Dart 3.12.2、Riverpod 3、riverpod_annotation、flutter_test、FVM

## Global Constraints

- 対象Issueは [GitHub Issue #4](https://github.com/yuto90/conquest/issues/4)。
- 設計の正本は`docs/superpowers/specs/2026-08-16-local-two-player-design.md`と`docs/game-rules.md`とする。矛盾がある場合はIssue #4の明示要件を優先する。
- ベースブランチは最新`main`とする。本プランは設計PRと同じ作業ブランチへ追加してよい。実装コードは本プラン承認後に別タスクで進める。
- 初期モードは`playerVsCpu`のままとする。
- 2人対戦へ切り替えても非表示のCPU難易度を破棄しない。
- 通常CPU戦の2タップ出兵、P / Player、C / CPU、Victory / Defeat / Drawを維持する。
- 2人対戦と観戦は島・移動部隊・結果を1P / 2P、1P WIN / 2P WIN / DRAWと表示する。
- 2人対戦の出兵は自軍島から目標へのドラッグだけとする。開始島のない単独タップを宛先出兵に使わない。
- 人間入力はCPU同時判断のようなスナップショット一括処理をせず、ポインターイベント到着順で逐次適用する。
- 2人対戦ではCPU判断期限を作らず、CPU strategyを実行しない。
- 戦闘、増加、移動、勝敗、map生成アルゴリズムは変更しない。
- オンライン対戦、180度回転HUD、ホットシート、画面分割、3人以上は追加しない。
- `GameMode`と`Faction`のswitchにdefaultを置かない。
- `enum GameMode`へ値を足すと既存の網羅switchが壊れる。Task 1はenum追加とswitch更新・3モードレイアウトを同じコミットに含め、その時点でanalyzeと既存widget testsが通る状態を保つ。
- 各実装タスクはred-green-refactorで進め、focused tests成功後にタスク単位でコミットする。

---

## File Structure

### Create

- `lib/local_multiplayer_input.dart`: ポインターIDごとのドラッグセッションと島ヒット判定。Flutter依存を`Listener`側に残し、ヒット判定は`IslandMapViewport.rectFor`を使う。

### Modify

- `lib/game/game_state.dart`: `GameMode.playerVsPlayer`、人間/CPU導出、`opponentSelectedIslandId`、選択クリア、`canDispatchAs`。
- `lib/game/game_rules.dart`: `IslandMapRect`の点内判定、両選択の維持・無効化。`_initialState`へ2P選択を通す。
- `lib/game/game_controller.dart`: 陣営付き`tapBase`、2人対戦でCPU空、両選択の無効化フィードバック。
- `lib/faction_presentation.dart`: 2人対戦を1P / 2P表示へ。
- `lib/home.dart`: 3モードUI、Listener入力、両選択表示、ステータス、結果、Semantics。
- `lib/base.dart`: 陣営色の選択バッジと選択リング、2人対戦時の`onPressed`抑制。
- `lib/l10n/app_en.arb` / `app_ja.arb`（生成物含む）: モード名、サマリー、開始Semantics、盤面案内、設定説明。
- `docs/game-rules.md`、`docs/integration-qa.md`: 2人対戦の本文とQA項目。

### Test

- `test/game_rules_test.dart`: 3モード導出、両選択のcopy/equality、2P選択無効化。
- `test/game_controller_test.dart`: 陣営付き出兵、CPU停止、同時逐次出兵、ライフサイクル。
- `test/widget_test.dart`: 設定UI、280 x 500、1P / 2P表示、ドラッグ出兵、結果。
- `test/integration_qa_test.dart`: 全島数開始、1Pと2Pの手動出兵、結果停止。
- `test/localization_test.dart`: 追加文字列が英日で解決すること。必要なら追記する。

---

### Task 1: 3モードを設定モデルと設定UIへ追加する

**Files:**
- Modify: `lib/game/game_state.dart`
- Modify: `lib/faction_presentation.dart`
- Modify: `lib/l10n/app_en.arb`、`lib/l10n/app_ja.arb`（生成後`lib/l10n/generated/`）
- Modify: `lib/home.dart`
- Test: `test/game_rules_test.dart`、`test/widget_test.dart`

**Interfaces:**
- Consumes: 既存`GameMode.playerVsCpu` / `cpuVsCpu`、設定パネルのChoiceChip。
- Produces: `GameMode.playerVsPlayer`、`humanFactions` / `cpuFactions`、`usesVersusPresentation`、`game-mode-player-vs-player`、2行モードレイアウト、2人対戦時の難易度非表示。

- [ ] **Step 1: モード導出と設定保持の失敗テストを書く**

```dart
test('game modes expose human and CPU factions', () {
  expect(GameMode.playerVsCpu.humanFactions, [Faction.player]);
  expect(GameMode.playerVsCpu.cpuFactions, [Faction.cpu]);
  expect(GameMode.playerVsPlayer.humanFactions, [
    Faction.player,
    Faction.cpu,
  ]);
  expect(GameMode.playerVsPlayer.cpuFactions, isEmpty);
  expect(GameMode.cpuVsCpu.humanFactions, isEmpty);
  expect(GameMode.cpuVsCpu.cpuFactions, [Faction.player, Faction.cpu]);
  expect(GameMode.playerVsPlayer.usesVersusPresentation, isTrue);
  expect(GameMode.playerVsCpu.usesVersusPresentation, isFalse);
});

test('configuration copy retains hidden CPU difficulties in local two-player', () {
  final local = GameConfiguration(
    totalIslandCount: 8,
    gameMode: GameMode.playerVsPlayer,
    playerCpuDifficulty: CpuDifficulty.hard,
    cpuDifficulty: CpuDifficulty.easy,
  );
  final restored = local.copyWith(gameMode: GameMode.playerVsCpu);

  expect(local.gameMode, GameMode.playerVsPlayer);
  expect(restored.playerCpuDifficulty, CpuDifficulty.hard);
  expect(restored.cpuDifficulty, CpuDifficulty.easy);
});
```

- [ ] **Step 2: 3モード設定UIの失敗Widgetテストを書く**

```dart
testWidgets('switches to local two-player settings without CPU difficulty', (
  tester,
) async {
  final semantics = tester.ensureSemantics();
  addTearDown(semantics.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [randomProvider.overrideWithValue(Random(1))],
      child: const MyApp(locale: Locale('ja')),
    ),
  );

  expect(find.byKey(const ValueKey('game-mode-player-vs-cpu')), findsOneWidget);
  expect(
    find.byKey(const ValueKey('game-mode-player-vs-player')),
    findsOneWidget,
  );
  expect(find.byKey(const ValueKey('game-mode-cpu-vs-cpu')), findsOneWidget);
  expect(find.byKey(const ValueKey('cpu-difficulty-normal')), findsOneWidget);

  await tester.tap(find.byKey(const ValueKey('game-mode-player-vs-player')));
  await tester.pump();

  expect(find.byKey(const ValueKey('cpu-difficulty-normal')), findsNothing);
  expect(
    find.byKey(const ValueKey('player-cpu-difficulty-normal')),
    findsNothing,
  );
  expect(
    tester.getSemantics(find.byKey(const ValueKey('start-game'))).label,
    contains('2人対戦'),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byKey(const ValueKey('start-game'))),
  );
  expect(
    container.read(gameControllerProvider).configuration.gameMode,
    GameMode.playerVsPlayer,
  );
});

testWidgets('keeps local two-player controls operable on a 280 by 500 screen', (
  tester,
) async {
  await tester.binding.setSurfaceSize(const Size(280, 500));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [randomProvider.overrideWithValue(Random(1))],
      child: const MyApp(locale: Locale('ja')),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('game-mode-player-vs-player')));
  await tester.pump();
  expect(tester.takeException(), isNull);
  await tester.ensureVisible(find.byKey(const ValueKey('start-game')));
  await tester.tap(find.byKey(const ValueKey('start-game')));
  await tester.pump();
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 3: 未定義APIで失敗することを確認する**

Run: `fvm flutter test test/game_rules_test.dart --plain-name "game modes expose human and CPU factions"`

Expected: `playerVsPlayer`または`humanFactions`が未定義でコンパイルFAIL。

- [ ] **Step 4: GameModeへ3値と導出を追加する**

```dart
enum GameMode {
  playerVsCpu,
  playerVsPlayer,
  cpuVsCpu;

  List<Faction> get humanFactions => switch (this) {
    playerVsCpu => const [Faction.player],
    playerVsPlayer => const [Faction.player, Faction.cpu],
    cpuVsCpu => const [],
  };

  List<Faction> get cpuFactions => switch (this) {
    playerVsCpu => const [Faction.cpu],
    playerVsPlayer => const [],
    cpuVsCpu => const [Faction.player, Faction.cpu],
  };

  bool get usesVersusPresentation => this != playerVsCpu;
}
```

宣言順は設定UIの優先順と一致させる。`GameConfiguration`のフィールドは増やさない。

- [ ] **Step 5: 網羅switchとFactionPresentationを同時更新する**

`FactionPresentation.forMode`は通常CPU戦だけP / Cとし、それ以外は1P / 2Pにする。

```dart
factory FactionPresentation.forMode(GameMode mode, Faction faction) {
  return switch ((mode, faction)) {
    (GameMode.playerVsCpu, Faction.player) => const FactionPresentation(
      marker: 'P',
      semanticName: 'Player',
    ),
    (GameMode.playerVsCpu, Faction.cpu) => const FactionPresentation(
      marker: 'C',
      semanticName: 'CPU',
    ),
    (_, Faction.player) => const FactionPresentation(
      marker: '1P',
      semanticName: '1P',
    ),
    (_, Faction.cpu) => const FactionPresentation(
      marker: '2P',
      semanticName: '2P',
    ),
    (_, Faction.neutral) => const FactionPresentation(
      marker: 'N',
      semanticName: 'Neutral',
    ),
  };
}
```

`home.dart`の`_modeKey` / `_modeLabel` / `_startLabel` / `_selectionSummary`へ`playerVsPlayer`腕を追加する。結果タイトルは既存の「`playerVsCpu`以外はwinner」分岐のままで2人対戦に使える。

- [ ] **Step 6: l10nを追加して生成する**

英語:

```json
"modePlayerVsPlayer": "2P LOCAL",
"selectedSummaryLocal": "Selected: {islandCount} islands / 2P LOCAL",
"startLocalSemantics": "Start local two-player game with {islandCount} islands",
"settingsDescriptionLocal": "Choose the battlefield size for a shared-screen match."
```

日本語:

```json
"modePlayerVsPlayer": "2人対戦",
"selectedSummaryLocal": "選択中：{islandCount}島 / 2人対戦",
"startLocalSemantics": "{islandCount}島の2人対戦を開始",
"settingsDescriptionLocal": "1画面で対戦する海域の規模を選択してください。"
```

placeholder属性は既存`selectedSummary`に合わせる。実行:

```bash
fvm flutter gen-l10n
```

設定説明は`playerVsPlayer`のとき`settingsDescriptionLocal`、それ以外は既存文にする。

- [ ] **Step 7: モードUIを2行にし、2人対戦で難易度を隠す**

1行3列の`GameMode.values`ループは使わない。

```dart
Column(
  children: [
    Row(
      children: [
        Expanded(
          child: _GameModeChoice(
            state: state,
            mode: GameMode.playerVsCpu,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _GameModeChoice(
            state: state,
            mode: GameMode.playerVsPlayer,
          ),
        ),
      ],
    ),
    const SizedBox(height: 9),
    _GameModeChoice(state: state, mode: GameMode.cpuVsCpu),
  ],
)
```

難易度見出しとChoiceChip行は`gameMode != GameMode.playerVsPlayer`のときだけ出す。観戦時の1P / 2P難易度2段は既存どおり。

- [ ] **Step 8: focused testsを通す**

Run:

```bash
fvm flutter test test/game_rules_test.dart test/widget_test.dart --plain-name "game modes expose human and CPU factions" --plain-name "configuration copy retains hidden CPU difficulties in local two-player" --plain-name "switches to local two-player settings without CPU difficulty" --plain-name "keeps local two-player controls operable on a 280 by 500 screen" --plain-name "keeps spectator controls operable on a 280 by 500 screen"
```

Expected: PASS。観戦の280 x 500回帰も成功する。

- [ ] **Step 9: formatしてコミットする**

```bash
fvm dart format lib/game/game_state.dart lib/faction_presentation.dart lib/home.dart lib/l10n test/game_rules_test.dart test/widget_test.dart
git diff --check
git add lib/game/game_state.dart lib/faction_presentation.dart lib/home.dart lib/l10n test/game_rules_test.dart test/widget_test.dart
git commit -m "feat: add local two-player game mode setting"
```

---

### Task 2: 2P選択状態とRulesの無効化を追加する

**Files:**
- Modify: `lib/game/game_state.dart`
- Modify: `lib/game/game_rules.dart`
- Test: `test/game_rules_test.dart`

**Interfaces:**
- Consumes: Task 1の`GameMode.playerVsPlayer`。
- Produces: `opponentSelectedIslandId`、`selectedIslandIdFor`、`clearOpponentSelection`、`clearAllSelections`、`selectIslandFor`、`canDispatchAs`、両選択のtick無効化。

- [ ] **Step 1: 選択APIと2P無効化の失敗テストを書く**

```dart
test('island canDispatchAs is faction-specific', () {
  const player = IslandState(
    id: 0,
    faction: Faction.player,
    currentForces: 10,
    size: IslandSize.headquarters,
    capacity: 200,
  );
  const cpu = IslandState(
    id: 1,
    faction: Faction.cpu,
    currentForces: 10,
    size: IslandSize.headquarters,
    capacity: 200,
  );
  expect(player.canDispatch, isTrue);
  expect(player.canDispatchAs(Faction.player), isTrue);
  expect(player.canDispatchAs(Faction.cpu), isFalse);
  expect(cpu.canDispatch, isFalse);
  expect(cpu.canDispatchAs(Faction.cpu), isTrue);
  expect(cpu.canDispatchAs(Faction.neutral), isFalse);
});

test('game state stores independent player and opponent selections', () {
  final state = GameState(
    phase: GamePhase.playing,
    elapsedMs: 0,
    selectedIslandId: 0,
    opponentSelectedIslandId: 1,
    islands: const [
      IslandState(id: 0, faction: Faction.player, currentForces: 10),
      IslandState(id: 1, faction: Faction.cpu, currentForces: 10),
    ],
  );
  expect(state.selectedIslandIdFor(Faction.player), 0);
  expect(state.selectedIslandIdFor(Faction.cpu), 1);
  expect(state.clearSelection().opponentSelectedIslandId, 1);
  expect(state.clearOpponentSelection().selectedIslandId, 0);
  expect(state.clearAllSelections().selectedIslandId, isNull);
  expect(state.clearAllSelections().opponentSelectedIslandId, isNull);
});

test('invalidates only the opponent selection when 2P source is lost', () {
  const player = IslandState(
    id: 0,
    faction: Faction.player,
    currentForces: 10,
    size: IslandSize.headquarters,
    capacity: 200,
  );
  const cpu = IslandState(
    id: 1,
    faction: Faction.cpu,
    currentForces: 10,
    size: IslandSize.headquarters,
    capacity: 200,
  );
  final captured = GameState(
    phase: GamePhase.playing,
    elapsedMs: 100,
    selectedIslandId: 0,
    opponentSelectedIslandId: 1,
    islands: [player, cpu.copyWith(faction: Faction.player)],
  );
  final next = const GameRules().tick(captured, deltaMs: 0);
  expect(next.selectedIslandId, 0);
  expect(next.opponentSelectedIslandId, isNull);
});
```

既存の1P無効化テストは残す。

- [ ] **Step 2: テストが未定義フィールドで失敗することを確認する**

Run: `fvm flutter test test/game_rules_test.dart --plain-name "game state stores independent player and opponent selections"`

Expected: `opponentSelectedIslandId`が未定義でコンパイルFAIL。

- [ ] **Step 3: GameStateへ2P選択を通す**

- コンストラクタ、`copyWith`、`==`、`hashCode`へ`opponentSelectedIslandId`を追加する。
- `copyWith`ではnullを設定できないため、`clearOpponentSelection()`と`clearAllSelections()`を追加する。
- `clearSelection()`は1Pだけ消す（既存互換）。
- `finishWithResult`、`transitionToPhase`、`clearMovingForces`、`clearResult`、`clearInteractionFeedback`は既存選択を両方保持する。
- ヘルパー:

```dart
int? selectedIslandIdFor(Faction faction) => switch (faction) {
  Faction.player => selectedIslandId,
  Faction.cpu => opponentSelectedIslandId,
  Faction.neutral => null,
};

GameState selectIslandFor(Faction faction, int islandId) { /* ... */ }

GameState clearSelectionFor(Faction faction) => switch (faction) {
  Faction.player => clearSelection(),
  Faction.cpu => clearOpponentSelection(),
  Faction.neutral => this,
};
```

`IslandState.canDispatch`は1P用のまま残し、次を追加する。

```dart
bool canDispatchAs(Faction faction) =>
    faction != Faction.neutral &&
    this.faction == faction &&
    currentForces > 1;
```

- [ ] **Step 4: GameRulesの選択無効化を両陣営へ拡張する**

`_stateAtTime`とtick開始時検証を、1Pは`Faction.player`、2Pは`Faction.cpu`で独立に判定する。片方の無効化が他方の選択や移動部隊を消さない。

`_initialState`は`opponentSelectedIslandId: null`を渡す。マップ生成・戦闘・増加は変更しない。

`IslandMapRect`へ点内判定を追加する（Task 5のヒット判定が使う）。

```dart
bool containsPoint(double x, double y) {
  return x >= left && x <= right && y >= top && y <= bottom;
}
```

- [ ] **Step 5: focused testsを通す**

Run: `fvm flutter test test/game_rules_test.dart`

Expected: PASS。既存1P選択テストも成功する。

- [ ] **Step 6: formatしてコミットする**

```bash
fvm dart format lib/game/game_state.dart lib/game/game_rules.dart test/game_rules_test.dart
git add lib/game/game_state.dart lib/game/game_rules.dart test/game_rules_test.dart
git commit -m "feat: track independent local two-player selections"
```

---

### Task 3: 陣営付き出兵と2人対戦のCPU停止

**Files:**
- Modify: `lib/game/game_controller.dart`
- Test: `test/game_controller_test.dart`

**Interfaces:**
- Consumes: Task 1の`cpuFactions`、Task 2の選択API。
- Produces: `tapBase(int baseId, {Faction actor = Faction.player})`、2人対戦で空のCPU集合、両選択クリア時のフィードバック。

- [ ] **Step 1: 2P出兵とCPU停止の失敗テストを書く**

既存の`ProviderContainer`セットアップを再利用する。playingへ入るには`startGame`と`completeStartCountdown(loop)`を使う。

```dart
test('local two-player dispatches from each human faction independently', () {
  final controller = container.read(gameControllerProvider.notifier);
  controller.selectGameMode(GameMode.playerVsPlayer);
  controller.startGame();
  completeStartCountdown(loop);

  controller.tapBase(0, actor: Faction.player);
  controller.tapBase(2, actor: Faction.player);
  controller.tapBase(1, actor: Faction.cpu);
  controller.tapBase(2, actor: Faction.cpu);

  final state = container.read(gameControllerProvider);
  expect(state.movingForces, hasLength(2));
  expect(state.movingForces[0].faction, Faction.player);
  expect(state.movingForces[0].sourceIslandId, 0);
  expect(state.movingForces[1].faction, Faction.cpu);
  expect(state.movingForces[1].sourceIslandId, 1);
  expect(state.movingForces[0].id, isNot(state.movingForces[1].id));
  expect(state.selectedIslandId, isNull);
  expect(state.opponentSelectedIslandId, isNull);
});

test('local two-player rejects the other faction as a source', () {
  final controller = container.read(gameControllerProvider.notifier);
  controller.selectGameMode(GameMode.playerVsPlayer);
  controller.startGame();
  completeStartCountdown(loop);

  controller.tapBase(1, actor: Faction.player);
  expect(container.read(gameControllerProvider).selectedIslandId, isNull);
  expect(
    container.read(gameControllerProvider).interactionFeedback,
    InteractionFeedbackType.unavailableSource,
  );

  controller.tapBase(0, actor: Faction.cpu);
  expect(
    container.read(gameControllerProvider).opponentSelectedIslandId,
    isNull,
  );
});

test('does not schedule CPU decisions in local two-player', () {
  final counting = _CountingMaximumRandom();
  final cpuContainer = ProviderContainer(
    overrides: [
      gameLoopProvider.overrideWithValue(loop),
      randomProvider.overrideWithValue(Random(1)),
      cpuTimingRandomProvider.overrideWithValue(counting),
      cpuQualityRandomProvider.overrideWithValue(counting),
      playerCpuRandomProvider.overrideWithValue(counting),
      playerCpuQualityRandomProvider.overrideWithValue(counting),
    ],
  );
  addTearDown(cpuContainer.dispose);
  final controller = cpuContainer.read(gameControllerProvider.notifier);
  controller.selectGameMode(GameMode.playerVsPlayer);
  controller.startGame();
  completeStartCountdown(loop);
  final before = counting.callCount;
  loop.tickMany(40);
  expect(cpuContainer.read(gameControllerProvider).movingForces, isEmpty);
  expect(counting.callCount, before);
});

test('standard mode still ignores opponent actor taps', () {
  final controller = container.read(gameControllerProvider.notifier);
  controller.startGame();
  completeStartCountdown(loop);
  final before = container.read(gameControllerProvider);
  controller.tapBase(1, actor: Faction.cpu);
  expect(container.read(gameControllerProvider), same(before));
});
```

観戦の`ignores direct island taps while spectating`は残す。

- [ ] **Step 2: 署名変更前に失敗することを確認する**

Run: `fvm flutter test test/game_controller_test.dart --plain-name "local two-player dispatches from each human faction independently"`

Expected: named `actor`が未定義でコンパイルFAIL。

- [ ] **Step 3: tapBaseを陣営付きへ一般化する**

```dart
void tapBase(int baseId, {Faction actor = Faction.player}) {
  if (_disposed || state.phase != GamePhase.playing) {
    return;
  }
  final mode = state.configuration.gameMode;
  if (!mode.humanFactions.contains(actor)) {
    return;
  }
  // 既存の選択・解除・出兵機械。参照欄とMovingForce.factionだけをactorにする。
}
```

- 選択欄は`state.selectedIslandIdFor(actor)`。
- 出兵元所有は`tappedIsland.faction == actor`。
- 出兵後は`clearSelectionFor(actor)`。`clearAllSelections`は呼ばない。
- 既存`tapBase(id)`は1Pのまま通る。

- [ ] **Step 4: CPU集合とtickフィードバックを更新する**

```dart
Iterable<Faction> get _activeCpuFactions =>
    state.configuration.gameMode.cpuFactions;
```

`_tick`は1P選択解除に加え、2P選択がこのtickで消えたときも`invalidatedSource`を出す。フィードバック枠は1つのまま、後に検出した方を表示する。

- [ ] **Step 5: focused testsを通す**

Run: `fvm flutter test test/game_controller_test.dart test/cpu_controller_integration_test.dart`

Expected: PASS。通常CPU戦の2タップと観戦のtap拒否・CPU期限が回帰しない。

- [ ] **Step 6: formatしてコミットする**

```bash
fvm dart format lib/game/game_controller.dart test/game_controller_test.dart
git add lib/game/game_controller.dart test/game_controller_test.dart
git commit -m "feat: dispatch local two-player moves by faction"
```

---

### Task 4: 両選択の盤面表示と結果

**Files:**
- Modify: `lib/base.dart`
- Modify: `lib/home.dart`
- Modify: `lib/l10n/app_en.arb`、`lib/l10n/app_ja.arb`（生成物含む）
- Test: `test/widget_test.dart`

**Interfaces:**
- Consumes: Task 1の1P / 2P presentation、Task 2の両選択。
- Produces: 陣営色SOURCEと選択リング、両ルート、1P左/2P右ステータス、2人対戦結果の明示テスト。

- [ ] **Step 1: 表示と結果の失敗Widgetテストを書く**

playing中の盤面を出すため、既存の`ManualWidgetGameLoop`パターンでカウントダウンを完了し、Controllerから両選択を入れる。

```dart
testWidgets('shows both local selections and 1P 2P markers', (tester) async {
  final loop = ManualWidgetGameLoop();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
      ],
      child: const MyApp(locale: Locale('ja')),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('game-mode-player-vs-player')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('start-game')));
  for (var index = 0; index < 60; index++) {
    loop.tick();
  }
  await tester.pump();

  expect(find.text('1P'), findsWidgets);
  expect(find.text('2P'), findsWidgets);
  expect(find.text('P'), findsNothing);
  expect(find.text('C'), findsNothing);

  final container = ProviderScope.containerOf(
    tester.element(find.byKey(const ValueKey('island-0'))),
  );
  final controller = container.read(gameControllerProvider.notifier);
  controller.tapBase(0, actor: Faction.player);
  controller.tapBase(1, actor: Faction.cpu);
  await tester.pump();

  expect(find.text('出兵元'), findsNWidgets(2));
  expect(find.byKey(const ValueKey('board-status-label')), findsOneWidget);
});

testWidgets('labels local two-player winners as 1P and 2P', (tester) async {
  // 観戦テストと同じくfinish(winner:)を使い、2人対戦モードで
  // 「1P 勝利」「2P 勝利」を確認する。
});
```

既存`uses mode-specific draw labels`へ`GameMode.playerVsPlayer`を足す。

盤面ステータス用l10n:

```json
"boardStatusLocalPlayer": "1P: {status}",
"boardStatusLocalOpponent": "2P: {status}",
"boardStatusLocalUnselected": "自軍島からドラッグ",
"boardStatusLocalSelected": "出兵元を選択中",
"boardStatusLocalDetail": "目標の島で指を離して出兵"
```

英語も同じ役割で追加する。

- [ ] **Step 2: Baseの選択色を陣営に合わせる**

`SOURCE`バッジと選択リングは`base.faction == Faction.cpu`なら`TacticalPalette.cpu` / `cpuDeep`、それ以外の選択は既存のplayer色とする。通常CPU戦の1Pバッジは既存色のまま。

- [ ] **Step 3: Homeの選択表示を両陣営対応にする**

```dart
selected: state.selectedIslandId == island.id ||
    state.opponentSelectedIslandId == island.id,
destinationCandidate:
    humanInteraction &&
    (state.selectedIslandId != null ||
        state.opponentSelectedIslandId != null) &&
    state.selectedIslandId != island.id &&
    state.opponentSelectedIslandId != island.id,
```

`_RoutePainter`は1P選択に加え2P選択からも破線を出す。既存の`.take(4)`プレビューは各選択に適用する。

`_BoardChrome`は2人対戦で下部を「1P左 / 2P右」にする。観戦は既存の観戦文、通常CPU戦は既存の単一ステータス。

通常CPU戦の島`onPressed`は維持する。2人対戦の`onPressed`はこのTaskではまだnullのままでよい（Task 5でListenerを載せる）。表示確認はControllerから選択を入れる。

- [ ] **Step 4: focused testsを通す**

Run: `fvm flutter test test/widget_test.dart --plain-name "shows both local selections and 1P 2P markers" --plain-name "labels local two-player winners as 1P and 2P" --plain-name "uses mode-specific draw labels" --plain-name "labels spectator winners as 1P and 2P"`

Expected: PASS。観戦と通常結果が回帰しない。

- [ ] **Step 5: formatしてコミットする**

```bash
fvm flutter gen-l10n
fvm dart format lib/base.dart lib/home.dart lib/l10n test/widget_test.dart
git add lib/base.dart lib/home.dart lib/l10n test/widget_test.dart
git commit -m "feat: present both local two-player selections"
```

---

### Task 5: ドラッグ出兵のマルチタッチ入力

**Files:**
- Create: `lib/local_multiplayer_input.dart`
- Modify: `lib/home.dart`
- Test: `test/widget_test.dart`、必要なら`test/game_rules_test.dart`（`containsPoint`）

**Interfaces:**
- Consumes: Task 3の`tapBase(actor:)`、`IslandMapViewport.rectFor`、`IslandMapRect.containsPoint`。
- Produces: pointerIdごとのジェスチャー、2人対戦playing中だけの盤面`Listener`、通常CPU戦InkWellの維持。

- [ ] **Step 1: ヒット判定とドラッグ出兵の失敗テストを書く**

ヒット判定はviewport座標で、Flutterを使わず検証できる。

```dart
test('viewport island rect contains its center and not a far point', () {
  const viewport = IslandMapViewport(width: 390, height: 844);
  final hq = rules.initialState(viewport: viewport).islands.first;
  final rect = viewport.rectFor(hq);
  expect(rect.containsPoint((rect.left + rect.right) / 2, (rect.top + rect.bottom) / 2), isTrue);
  expect(rect.containsPoint(0, 0), isFalse);
});
```

Widget側:

```dart
testWidgets('local two-player drags dispatch and taps on enemy do not', (
  tester,
) async {
  final loop = ManualWidgetGameLoop();
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameLoopProvider.overrideWithValue(loop),
        randomProvider.overrideWithValue(Random(1)),
      ],
      child: const MyApp(locale: Locale('ja')),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('game-mode-player-vs-player')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('start-game')));
  for (var index = 0; index < 60; index++) {
    loop.tick();
  }
  await tester.pump();

  final container = ProviderScope.containerOf(
    tester.element(find.byKey(const ValueKey('island-0'))),
  );
  expect(container.read(gameControllerProvider).phase, GamePhase.playing);

  await tester.tap(find.byKey(const ValueKey('island-button-1')));
  await tester.pump();
  expect(container.read(gameControllerProvider).movingForces, isEmpty);
  expect(container.read(gameControllerProvider).selectedIslandId, isNull);

  final playerHq = tester.getCenter(find.byKey(const ValueKey('island-0')));
  final target = tester.getCenter(find.byKey(const ValueKey('island-2')));
  final gesture = await tester.startGesture(playerHq);
  await tester.pump();
  await gesture.moveTo(target);
  await gesture.up();
  await tester.pump();

  final dispatched = container.read(gameControllerProvider);
  expect(dispatched.movingForces, hasLength(1));
  expect(dispatched.movingForces.single.faction, Faction.player);
  expect(dispatched.movingForces.single.sourceIslandId, 0);
});

testWidgets('two pointers can dispatch in the same frame order', (
  tester,
) async {
  // 1P HQから中立、2P HQから同じまたは別の中立へ同時ドラッグ。
  // movingForces.length == 2、factionがplayerとcpuであることを確認する。
});
```

- [ ] **Step 2: 入力セッション型を実装する**

`lib/local_multiplayer_input.dart`:

```dart
final class LocalDispatchSession {
  const LocalDispatchSession({
    required this.pointerId,
    required this.actor,
    required this.sourceIslandId,
    required this.startedOnSelectedSource,
  });

  final int pointerId;
  final Faction actor;
  final int sourceIslandId;
  final bool startedOnSelectedSource;
}

IslandState? hitTestIsland({
  required GameState state,
  required IslandMapViewport viewport,
  required Offset local,
}) {
  IslandState? best;
  var bestDistance = double.infinity;
  for (final island in state.islands) {
    final rect = viewport.rectFor(island);
    if (!rect.containsPoint(local.dx, local.dy)) continue;
    final centerX = (rect.left + rect.right) / 2;
    final centerY = (rect.top + rect.bottom) / 2;
    final dx = local.dx - centerX;
    final dy = local.dy - centerY;
    final distance = dx * dx + dy * dy;
    if (distance < bestDistance) {
      best = island;
      bestDistance = distance;
    }
  }
  return best;
}
```

マップ生成は島を重ねない。矩形境界の同時ヒットだけ中心距離で解消する。

- [ ] **Step 3: `_GameSurfaceState`へListenerを載せる**

2人対戦かつ`playing`のときだけ盤面`Listener`を有効にする。このとき各`Base.onPressed`はnull。通常CPU戦は既存`InkWell.onTap`。

ポインター規則（設計どおり）:

1. Downが自軍かつ`canDispatchAs(actor)`: 未選択なら`tapBase(source, actor:)`で選択。`startedOnSelectedSource`はダウン前の選択一致。
2. Upが同じ島: `startedOnSelectedSource`なら`tapBase`で解除。そうでなければ維持。
3. Upが別島: `tapBase(dest, actor:)`で出兵。
4. Upが島外、cancel、pause、result: 出兵しない。ダウンで付けた選択は維持する。
5. Downが敵・中立・兵力不足: セッションを作らない。
6. 同一`pointerId`は1セッション。2本まで同時。

ドラッグ中の仮ラインと指の下の島強調は`_GameSurfaceState`のローカル状態とし、`GameState`に入れない。pause/resultでセッションmapをclearする。

`Listener`の座標は盤面Stackのローカルとし、`mapViewportProvider`と同じサイズで`rectFor`する。

- [ ] **Step 4: focused testsを通す**

Run: `fvm flutter test test/widget_test.dart --plain-name "local two-player drags dispatch and taps on enemy do not" --plain-name "two pointers can dispatch in the same frame order" test/game_rules_test.dart --plain-name "viewport island rect contains its center"`

Expected: PASS。敵島単独タップでは部隊が増えない。

- [ ] **Step 5: 通常CPU戦タップ回帰を確認する**

Run: `fvm flutter test test/widget_test.dart --plain-name "selects a source island from the board"` および既存の島タップ系。ファイル内の名前が違う場合は`island-button`を含むテストを実行する。

Expected: 通常CPU戦の2タップ出兵が残る。

- [ ] **Step 6: formatしてコミットする**

```bash
fvm dart format lib/local_multiplayer_input.dart lib/home.dart test/widget_test.dart test/game_rules_test.dart
git add lib/local_multiplayer_input.dart lib/home.dart test/widget_test.dart test/game_rules_test.dart
git commit -m "feat: dispatch local two-player attacks by dragging"
```

---

### Task 6: 統合QAとルール文書

**Files:**
- Modify: `test/integration_qa_test.dart`
- Modify: `docs/game-rules.md`
- Modify: `docs/integration-qa.md`

**Interfaces:**
- Consumes: Task 1-5の完成したモード、選択、Controller、ドラッグ入力。
- Produces: 全島数開始、1P/2P手動出兵、結果停止、ルール本文、QA表。

- [ ] **Step 1: 統合テストを書く**

```dart
test('starts local two-player on every supported island count', () {
  for (final count in GameConfiguration.allowedIslandCounts) {
    final loop = _QaManualLoop();
    final container = _createContainer(
      loop: loop,
      islandCount: count,
      seed: 1,
    );
    addTearDown(container.dispose);
    final controller = container.read(gameControllerProvider.notifier);
    controller.selectGameMode(GameMode.playerVsPlayer);
    controller.startGame();
    completeCountdownLikeExistingHelper(loop);
    final playing = container.read(gameControllerProvider);
    expect(playing.phase, GamePhase.playing);
    expect(playing.configuration.gameMode, GameMode.playerVsPlayer);
    expect(playing.islands, hasLength(count));

    controller.tapBase(0, actor: Faction.player);
    controller.tapBase(2, actor: Faction.player);
    controller.tapBase(1, actor: Faction.cpu);
    controller.tapBase(2, actor: Faction.cpu);
    expect(container.read(gameControllerProvider).movingForces, hasLength(2));
    loop.tickMany(200);
    expect(
      container.read(gameControllerProvider).configuration.gameMode,
      GameMode.playerVsPlayer,
    );
  }
});

test('local two-player stops after a result and keeps mode on replay', () {
  // 既存観戦のreplay helperに合わせ、finish後にloopとmovingForcesが止まり、
  // replayGame後もplayerVsPlayerが残ることを確認する。
});
```

既存のCPU戦・観戦統合は削除しない。カウントダウン完了はファイル内の既存ヘルパー名に合わせる。

- [ ] **Step 2: `docs/game-rules.md`を本文へ繰り上げる**

「初期版の対象外」から同一端末2人対戦を外す。本文へ次を書く。

- 開始前に通常CPU戦、2人対戦、観戦を選べる。
- 2人対戦の1Pは右下緑、2Pは左上赤。
- 出兵は自軍島から目標へのドラッグで、兵力は半分。
- 2人対戦ではCPU判断を行わない。
- 結果は`1P WIN` / `2P WIN` / `DRAW`（日本語は既存の`1P 勝利`など）。
- オンライン対戦は対象外のままIssue #5へ残す。

文書先頭の「初期版は1人用」も、3モードを選べる旨に更新する。

- [ ] **Step 3: `docs/integration-qa.md`へ表を追加する**

観戦の表と同じ形式で、自動テスト名とPASS/未実行を書く。実端末の2人同時ドラッグは実施するまで未実行とし、自動PASSから推定しない。

- [ ] **Step 4: 検証ゲートを実行する**

```bash
fvm dart format lib test
fvm flutter gen-l10n
fvm flutter analyze
fvm flutter test
git diff --check
```

Expected: analyze指摘なし、全テストPASS。`game_controller.g.dart`に無関係なhash差分があれば捨てる。

- [ ] **Step 5: formatしてコミットする**

```bash
git add test/integration_qa_test.dart docs/game-rules.md docs/integration-qa.md
git commit -m "docs: record local two-player rules and QA"
```

---

## 検証ゲート（全体）

- 変更対象のfocused tests（各Task）
- `fvm flutter gen-l10n`（arb変更時）
- Dart format
- `fvm flutter analyze`
- `fvm flutter test`
- `git diff --check`

## 完了条件

- Issue #4のモード選択、両陣営操作、同時入力、勝敗と再戦、既存ルール維持をテストへ対応付けられる。
- 通常CPU戦と観戦が回帰していない。
- 2人対戦でCPUが動かず、`tapBase(actor:)`とドラッグの両方で1P/2Pが出兵できる。
- 敵島の単独タップが出兵にならない。
- 2本のポインターが両方の部隊を生成する。
- 280 x 500で3モードと開始に到達できる。
- 文書、format、analyze、全テスト、diff checkが成功する。
