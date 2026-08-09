# CPU Difficulty Gradient Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Very Easyを追加し、CPUの判断間隔・見送り率・候補選択品質だけで、Very Easy・Easy・Normal・Hardが滑らかに強くなる4段階の難易度へ再調整する。

**Architecture:** `CpuDifficulty`と`CpuDifficultyProfile`を難易度設定の正本とし、既存の合法候補生成・戦略優先順位・ゲームルールは全難易度で共有する。`GameController`は既存の独立したタイミング用乱数と品質用乱数を利用し、設定されたプロファイルで判断期限と候補選択を行う。設定UIはenum順の4択を表示し、`GameConfiguration`が選択値を試合ライフサイクル全体で保持する。

**Tech Stack:** Flutter 3.44.8、Dart 3.12.2、Riverpod 3、riverpod_annotation、flutter_test、FVM

## Global Constraints

- 設計の正本は`docs/superpowers/specs/2026-08-09-cpu-difficulty-gradient-design.md`とする。
- この変更はIssue #35 / PR #39のEasy品質調整を前提とする。`origin/main`にPR #39が未反映の間は、同じ実装を複製せずdelivery preflightを停止する。
- ユーザー指定のベースは`origin/main`である。PR #39が`origin/main`へ入った後、最新`origin/main`から新しいfollow-up Issue専用branch/worktreeを作る。
- PR #39をbaseにしたstacked PRへ変更しない。必要ならユーザーからベース変更の明示承認を得る。
- 実装開始前に、Very Easy追加と4段階再調整を本文に含む新しいGitHub follow-up Issueを作成し、この計画書と設計書への明示承認を記録する。
- 承認済みプロファイルは次の値から変更しない。

| 難易度 | 最小判断間隔 | 最大判断間隔 | 見送り率 | 最優先候補選択率 |
| --- | ---: | ---: | ---: | ---: |
| Very Easy | 5500ms | 7000ms | 55% | 20% |
| Easy | 4000ms | 5500ms | 35% | 50% |
| Normal | 2750ms | 4000ms | 15% | 80% |
| Hard | 1500ms | 2750ms | 0% | 100% |

- 難易度差は判断間隔、判断見送り率、判断実行時の最優先候補選択率だけで作る。
- CPUとプレイヤーの兵力、増加量、移動速度、上限、出兵、戦闘、勝敗ルールは変更しない。
- 合法候補生成、防衛優先、攻撃優先順位、到着時予測は難易度別に分岐させない。
- 動的難易度、隠れ補正、学習AI、途中変更、CPU対CPU観戦モードは追加しない。
- 判断間隔用乱数と判断品質用乱数の独立性、固定seed再現性、1判断最大1部隊を維持する。
- 一時停止・再開・resize・Provider再構築で期限または乱数系列を初期化しない。
- 見送り時も現在のゲーム内時刻から次の期限を1回だけ設定し、catch-up判断を行わない。
- `game_controller.g.dart`は対応する注釈付きsource変更とcodegen結果が一致する場合だけ含める。hashだけの無関係な差分はコミットしない。
- 各実装タスクはred-green-refactorで進め、focused test成功後にタスク単位でコミットする。
- deliveryはReady PR、1回のGitHub Codex review、全指摘解消、required checks成功まで行い、mergeは行わない。

---

## File Structure

### Modify

- `lib/game/game_state.dart`: `CpuDifficulty`を易しい順の4値へ拡張する。
- `lib/game/cpu_strategy.dart`: 4つの型付きプロファイルと網羅switchを定義する。
- `lib/home.dart`: Very Easyの表示、key、Semantics、tooltipを追加する。
- `docs/game-rules.md`: 4段階の数値、共有ルール、乱数・見送り挙動を記載する。
- `docs/integration-qa.md`: 自動検証と6・8・10・12島の手動QA手順・結果欄を記載する。

### Test

- `test/cpu_strategy_test.dart`: プロファイル、勾配不変条件、境界、合法性、再現性、乱数独立性。
- `test/cpu_controller_integration_test.dart`: 4段階の期限、見送り後の再スケジュール、行動数順序。
- `test/game_rules_test.dart`: Normal初期値、Very Easyのcopy/equality保持。
- `test/game_controller_test.dart`: Very Easyの設定、再戦、設定復帰、pause/resume保持。
- `test/widget_test.dart`: 4択、表示、操作、Semantics、280×500、resize保持。
- `test/integration_qa_test.dart`: 全島数の開始とVery Easyのライフサイクル保持。
- `test/tactical_ui_test.dart`: 既存設定画面のレイアウト回帰がある場合だけ期待値を4択へ更新する。

---

### Task 1: 4段階の型とプロファイルを定義する

**Files:**
- Modify: `lib/game/game_state.dart:27`
- Modify: `lib/game/cpu_strategy.dart:35-105`
- Test: `test/cpu_strategy_test.dart:107-167,338-397`

**Interfaces:**
- Consumes: `GameConfiguration.cpuDifficulty`、`CpuStrategy.nextDecisionDelayMs`、`CpuStrategy.selectCandidate`。
- Produces: `CpuDifficulty.veryEasy`、`CpuDifficultyProfile.veryEasy`、4値を網羅する`forDifficulty`。
- Preserves: `GameConfiguration.initial.cpuDifficulty == CpuDifficulty.normal`。

- [ ] **Step 1: 4プロファイルの正確な値を要求する失敗テストを書く**

```dart
test('difficulty profiles match the approved four-tier gradient', () {
  const expected = <CpuDifficulty, CpuDifficultyProfile>{
    CpuDifficulty.veryEasy: CpuDifficultyProfile(
      difficulty: CpuDifficulty.veryEasy,
      minDecisionIntervalMs: 5500,
      maxDecisionIntervalMs: 7000,
      skipDecisionRatePercent: 55,
      primaryCandidateRatePercent: 20,
    ),
    CpuDifficulty.easy: CpuDifficultyProfile(
      difficulty: CpuDifficulty.easy,
      minDecisionIntervalMs: 4000,
      maxDecisionIntervalMs: 5500,
      skipDecisionRatePercent: 35,
      primaryCandidateRatePercent: 50,
    ),
    CpuDifficulty.normal: CpuDifficultyProfile(
      difficulty: CpuDifficulty.normal,
      minDecisionIntervalMs: 2750,
      maxDecisionIntervalMs: 4000,
      skipDecisionRatePercent: 15,
      primaryCandidateRatePercent: 80,
    ),
    CpuDifficulty.hard: CpuDifficultyProfile(
      difficulty: CpuDifficulty.hard,
      minDecisionIntervalMs: 1500,
      maxDecisionIntervalMs: 2750,
      skipDecisionRatePercent: 0,
      primaryCandidateRatePercent: 100,
    ),
  };

  expect(CpuDifficulty.values, expected.keys.toList());
  for (final entry in expected.entries) {
    expect(CpuDifficultyProfile.forDifficulty(entry.key), entry.value);
  }
});
```

- [ ] **Step 2: enumとプロファイルが未実装のため失敗することを確認する**

Run: `fvm flutter test test/cpu_strategy_test.dart --plain-name "difficulty profiles match the approved four-tier gradient"`

Expected: `CpuDifficulty.veryEasy`が未定義、または既存Easy/Normal/Hard値の不一致でFAIL。

- [ ] **Step 3: enumを易しい順へ拡張し、4つのconst profileを最小実装する**

```dart
enum CpuDifficulty { veryEasy, easy, normal, hard }
```

```dart
static const veryEasy = CpuDifficultyProfile(
  difficulty: CpuDifficulty.veryEasy,
  minDecisionIntervalMs: 5500,
  maxDecisionIntervalMs: 7000,
  skipDecisionRatePercent: 55,
  primaryCandidateRatePercent: 20,
);

static const easy = CpuDifficultyProfile(
  difficulty: CpuDifficulty.easy,
  minDecisionIntervalMs: 4000,
  maxDecisionIntervalMs: 5500,
  skipDecisionRatePercent: 35,
  primaryCandidateRatePercent: 50,
);

static const normal = CpuDifficultyProfile(
  difficulty: CpuDifficulty.normal,
  minDecisionIntervalMs: 2750,
  maxDecisionIntervalMs: 4000,
  skipDecisionRatePercent: 15,
  primaryCandidateRatePercent: 80,
);

static const hard = CpuDifficultyProfile(
  difficulty: CpuDifficulty.hard,
  minDecisionIntervalMs: 1500,
  maxDecisionIntervalMs: 2750,
  skipDecisionRatePercent: 0,
  primaryCandidateRatePercent: 100,
);
```

```dart
static CpuDifficultyProfile forDifficulty(CpuDifficulty difficulty) {
  return switch (difficulty) {
    CpuDifficulty.veryEasy => veryEasy,
    CpuDifficulty.easy => easy,
    CpuDifficulty.normal => normal,
    CpuDifficulty.hard => hard,
  };
}
```

- [ ] **Step 4: プロファイルの妥当性と滑らかさを要求するテストを書く**

```dart
test('difficulty profiles form a bounded monotonic gradient', () {
  final profiles = CpuDifficulty.values
      .map(CpuDifficultyProfile.forDifficulty)
      .toList();

  for (final profile in profiles) {
    expect(profile.minDecisionIntervalMs, greaterThan(0));
    expect(
      profile.maxDecisionIntervalMs,
      greaterThanOrEqualTo(profile.minDecisionIntervalMs),
    );
    expect(profile.skipDecisionRatePercent, inInclusiveRange(0, 100));
    expect(profile.primaryCandidateRatePercent, inInclusiveRange(0, 100));
  }

  for (var index = 0; index < profiles.length - 1; index += 1) {
    final easier = profiles[index];
    final harder = profiles[index + 1];
    final easierMidpoint =
        (easier.minDecisionIntervalMs + easier.maxDecisionIntervalMs) / 2;
    final harderMidpoint =
        (harder.minDecisionIntervalMs + harder.maxDecisionIntervalMs) / 2;
    final easierExpectedActionInterval =
        easierMidpoint / (1 - easier.skipDecisionRatePercent / 100);
    final harderExpectedActionInterval =
        harderMidpoint / (1 - harder.skipDecisionRatePercent / 100);

    expect(easierMidpoint, greaterThan(harderMidpoint));
    expect(easierMidpoint - harderMidpoint, lessThanOrEqualTo(1500));
    expect(
      easier.skipDecisionRatePercent,
      greaterThan(harder.skipDecisionRatePercent),
    );
    expect(
      easier.skipDecisionRatePercent - harder.skipDecisionRatePercent,
      lessThanOrEqualTo(20),
    );
    expect(
      easier.primaryCandidateRatePercent,
      lessThan(harder.primaryCandidateRatePercent),
    );
    expect(
      harder.primaryCandidateRatePercent -
          easier.primaryCandidateRatePercent,
      lessThanOrEqualTo(30),
    );
    expect(
      easierExpectedActionInterval / harderExpectedActionInterval,
      lessThan(2),
    );
  }
});
```

- [ ] **Step 5: profile、inclusive interval、seed再現性のfocused testsを成功させる**

Run: `fvm flutter test test/cpu_strategy_test.dart --plain-name "difficulty profiles"`

Expected: PASS。

Run: `fvm flutter test test/cpu_strategy_test.dart --plain-name "each CPU difficulty uses its inclusive decision interval"`

Expected: Very Easy 5500/7000、Easy 4000/5500、Normal 2750/4000、Hard 1500/2750でPASS。

Run: `fvm flutter test test/cpu_strategy_test.dart --plain-name "the same seed reproduces delays for every difficulty"`

Expected: 4難易度でPASS。

- [ ] **Step 6: Task 1をコミットする**

```bash
git add lib/game/game_state.dart lib/game/cpu_strategy.dart test/cpu_strategy_test.dart
git commit -m "feat: define four-tier CPU difficulty profiles"
```

---

### Task 2: 見送り・候補品質・行動頻度の境界を固定する

**Files:**
- Modify: `test/cpu_strategy_test.dart:168-337`
- Modify: `test/cpu_controller_integration_test.dart:1-330`
- Modify only if a failing test exposes a generic scheduling defect: `lib/game/game_controller.dart`

**Interfaces:**
- Consumes: `CpuStrategy.selectCandidate`の半開区間判定、独立`timingRandom` / `qualityRandom`、`GameController.selectCpuDifficulty`。
- Produces: 4難易度すべての境界・再スケジュール・順序回帰テスト。
- Preserves: 候補0件は`null`、候補1件も見送り対象、複数件の代替選択は先頭以外、1判断最大1部隊。

- [ ] **Step 1: 率の境界直前と境界値を表形式で検証する失敗テストを書く**

`SequenceRandom`へ、見送り判定値、最優先判定値、代替indexの順で値を渡す。既存`_multipleCandidateState`と候補先頭を再利用する。

```dart
test('quality boundaries use half-open percentage ranges', () {
  const cases = <(
    CpuDifficulty,
    int,
    int,
    int,
    bool,
    bool
  )>[
    (CpuDifficulty.veryEasy, 54, 0, 0, true, false),
    (CpuDifficulty.veryEasy, 55, 19, 0, false, true),
    (CpuDifficulty.veryEasy, 55, 20, 0, false, false),
    (CpuDifficulty.easy, 34, 0, 0, true, false),
    (CpuDifficulty.easy, 35, 49, 0, false, true),
    (CpuDifficulty.easy, 35, 50, 0, false, false),
    (CpuDifficulty.normal, 14, 0, 0, true, false),
    (CpuDifficulty.normal, 15, 79, 0, false, true),
    (CpuDifficulty.normal, 15, 80, 0, false, false),
  ];

  for (final testCase in cases) {
    final (difficulty, skipRoll, primaryRoll, alternativeRoll, skipped, primary) =
        testCase;
    final strategy = CpuStrategy(
      qualityRandom: _SequenceRandom([
        skipRoll,
        primaryRoll,
        alternativeRoll,
      ]),
    );
    final candidates = strategy.generateCandidates(
      _multipleCandidateState(difficulty: difficulty),
    );
    final decision = strategy.selectCandidate(
      candidates,
      difficulty: difficulty,
    );

    expect(decision == null, skipped, reason: '$difficulty skip boundary');
    if (!skipped) {
      expect(
        decision == candidates.first,
        primary,
        reason: '$difficulty primary boundary',
      );
    }
  }
});
```

Hardは品質乱数を消費せず必ず先頭候補になる別testを追加する。`SequenceRandom`の既存APIがlist以外の場合は、同じ値列を返す既存helperのconstructorへ合わせる。

- [ ] **Step 2: 旧3段階値またはVery Easy未対応で失敗することを確認する**

Run: `fvm flutter test test/cpu_strategy_test.dart --plain-name "quality boundaries use half-open percentage ranges"`

Expected: Task 1だけでは既存境界testの期待値競合、または追加case未対応でFAIL。

- [ ] **Step 3: 既存の個別Easy境界testを4段階の表形式へ統合する**

実装の比較演算`nextInt(100) < rate`は維持する。Normalの見送りと代替候補、Very Easyの55%/20%、Easyの35%/50%を追加し、Hardは見送りなし・先頭100%を明示する。候補0件・1件・複数件の既存testを4難易度でloopし、返却された判断が常に`generateCandidates`内にあることを検証する。

- [ ] **Step 4: 品質乱数消費が期限列を変えない回帰testを4難易度へ拡張する**

同じtiming seedの2 strategyを作り、一方だけ`decide`で品質乱数を消費させた後、各難易度で次の20期限が一致することを検証する。別testで同じtiming seedとquality seedから同一判断列を再現する。

- [ ] **Step 5: 4難易度の初回期限を要求するcontroller integration testを更新する**

50ms tickと`ZeroRandom`では最小間隔を使う。

```dart
const dueTicks = <CpuDifficulty, int>{
  CpuDifficulty.veryEasy: 110,
  CpuDifficulty.easy: 80,
  CpuDifficulty.normal: 55,
  CpuDifficulty.hard: 30,
};
```

各entryで期限直前まで部隊0、期限到達で最大1部隊を検証する。Very Easy/Easy/Normalは、行動を確実に発生させる品質乱数を注入する。Hardは品質乱数を消費しないことも検証する。

- [ ] **Step 6: 見送り後にcatch-upしない失敗testを4段階で追加する**

各難易度について最初の期限ではskipする品質列、次の期限では実行する品質列を注入する。最初の期限到達後の部隊数が0、同じtickを追加処理しても0、現在時刻から新しい最小期限が経過した時だけ1になることを検証する。

- [ ] **Step 7: 固定観測時間の実行判断数が単調になる決定論的testを追加する**

候補が常に複数存在する固定state、各難易度で同じ周期を表現するtiming/quality乱数列、十分長い観測時間を使う。部隊適用によるboard変化で候補が消える場合は`CpuStrategy.selectCandidate`を直接繰り返し、期限と見送りを組み合わせた実行数を数える。期待値は`veryEasy <= easy <= normal <= hard`とし、全tierが同数になるfixtureは不採用とする。

- [ ] **Step 8: focused testsを成功させる**

Run: `fvm flutter test test/cpu_strategy_test.dart test/cpu_controller_integration_test.dart`

Expected: 全件PASS、uncaught `RangeError`なし、既存防衛・攻撃優先testもPASS。

- [ ] **Step 9: production変更の必要性を確認してTask 2をコミットする**

`lib/game/game_controller.dart`が既にprofileをgenericに参照し、testがproduction変更なしで通る場合は変更しない。変更した場合は`git diff -- lib/game/game_controller.dart`でスケジュール修正だけであることを確認する。

```bash
git add test/cpu_strategy_test.dart test/cpu_controller_integration_test.dart
git add lib/game/game_controller.dart
git commit -m "test: lock CPU difficulty quality boundaries"
```

`lib/game/game_controller.dart`が未変更なら2つのtest fileだけをstageする。

---

### Task 3: 設定UI・表示・アクセシビリティを4択へ拡張する

**Files:**
- Modify: `lib/home.dart:570-790`
- Modify: `test/widget_test.dart:81-145,563-600,705-765`
- Modify: `test/game_rules_test.dart:1-80`
- Inspect and modify only if assertions enumerate choices: `test/tactical_ui_test.dart`

**Interfaces:**
- Consumes: `CpuDifficulty.values`、`GameController.selectCpuDifficulty`、`GameConfiguration.cpuDifficulty`。
- Produces: 表示`Very Easy`、key`cpu-difficulty-veryEasy`、label/tooltip`Very Easy CPU difficulty`。
- Preserves: Normal初期選択、設定中だけ変更可能、開始後の選択値、開始ボタンSemantics。

- [ ] **Step 1: 明示ラベルmapで4択を要求するwidget失敗testを書く**

```dart
const expectedLabels = <CpuDifficulty, String>{
  CpuDifficulty.veryEasy: 'Very Easy',
  CpuDifficulty.easy: 'Easy',
  CpuDifficulty.normal: 'Normal',
  CpuDifficulty.hard: 'Hard',
};

for (final entry in expectedLabels.entries) {
  final chip = find.byKey(
    ValueKey('cpu-difficulty-${entry.key.name}'),
  );
  expect(chip, findsOneWidget);
  expect(
    tester.getSemantics(chip).label,
    '${entry.value} CPU difficulty',
  );
}
```

既存のenum name先頭だけ大文字化する期待値は`VeryEasy`を生成するため削除し、この明示mapを正本にする。

- [ ] **Step 2: Very Easy選択・表示・開始Semanticsの失敗testを書く**

`cpu-difficulty-veryEasy`をtapし、controller stateが`CpuDifficulty.veryEasy`、選択中表示が`選択中：10島 / Very Easy`、開始ボタンSemanticsが`Start game with 10 islands on Very Easy CPU difficulty`になることを検証する。

- [ ] **Step 3: 既存3値switchの網羅性エラーを確認する**

Run: `fvm flutter test test/widget_test.dart --plain-name "offers CPU difficulty choices with Normal selected initially"`

Expected: `_difficultyLabel`が`CpuDifficulty.veryEasy`を扱わないためcompile FAIL、またはVery Easyの表示期待でFAIL。

- [ ] **Step 4: label switchをdefaultなしで4値へ拡張する**

```dart
String _difficultyLabel(CpuDifficulty difficulty) => switch (difficulty) {
  CpuDifficulty.veryEasy => 'Very Easy',
  CpuDifficulty.easy => 'Easy',
  CpuDifficulty.normal => 'Normal',
  CpuDifficulty.hard => 'Hard',
};
```

既存`CpuDifficulty.values` loop、`ValueKey('cpu-difficulty-${difficulty.name}')`、Semantics/tooltip生成は再利用する。

- [ ] **Step 5: 設定モデルの初期値と保持を4値で検証する**

`test/game_rules_test.dart`へ、`GameConfiguration.initial`がNormalのまま、`GameConfiguration(cpuDifficulty: CpuDifficulty.veryEasy)`の`copyWith(totalIslandCount: 12)`とequality/hashがVery Easyを保持するtestを追加する。

- [ ] **Step 6: 280×500の4択操作testを更新する**

Very Easy/Easy/Normal/Hardの4keyと開始ボタンが存在し、各chipの矩形と開始ボタンの矩形がSafe Area内にあることを検証する。Very EasyとHardを順にtapでき、最終stateがHardになることを確認する。固定scaled pixelではなくviewport境界と相対位置をassertする。

- [ ] **Step 7: resize保持testの選択値をVery Easyへ変更する**

Very Easyを選択して試合開始後、pending deadlineを持つ状態でviewportを変更し、`configuration.cpuDifficulty`とdeadlineが変化しないことを検証する。

- [ ] **Step 8: UI focused testsを成功させる**

Run: `fvm flutter test test/game_rules_test.dart test/widget_test.dart test/tactical_ui_test.dart`

Expected: 4択、Normal初期値、Very Easy表示、Semantics、280×500、resizeを含め全件PASS。overflow exceptionなし。

- [ ] **Step 9: Task 3をコミットする**

```bash
git add lib/home.dart test/widget_test.dart test/game_rules_test.dart test/tactical_ui_test.dart
git commit -m "feat: add Very Easy difficulty selection"
```

`test/tactical_ui_test.dart`が未変更ならstageしない。

---

### Task 4: ライフサイクル回帰と統合QAを追加する

**Files:**
- Modify: `test/game_controller_test.dart:100-150,650-710`
- Modify: `test/integration_qa_test.dart:580-650`
- Modify: `docs/game-rules.md`
- Modify: `docs/integration-qa.md`

**Interfaces:**
- Consumes: `selectCpuDifficulty`、`startGame`、pause/resume、`replay`、`returnToConfiguration`、島数変更。
- Produces: Very Easyの全ライフサイクル保持証拠と4段階QA手順。
- Preserves: configuration phase以外の難易度変更拒否、map非再生成、結果停止。

- [ ] **Step 1: Very Easy保持の失敗testをcontroller suiteへ追加する**

設定中にVery Easyを選び、島数を6→12へ変更してもVery Easyを保持し、map seed以外の不要な再生成がないことを検証する。試合開始後の難易度変更は拒否されることを既存testで維持する。

- [ ] **Step 2: pause/resume、replay、設定復帰のVery Easy testを追加する**

Very Easyで試合を開始し、pause/resume countdownで設定とpending deadlineを保持する。結果stateからreplayしたstateと設定へ戻ったstateがどちらもVery Easyを保持することを検証する。開始countdown、一時停止、resume countdown、result中に品質乱数が消費されないことも、注入randomのcall countで検証する。

- [ ] **Step 3: 6・8・10・12島の統合testを4難易度へ拡張する**

各島数と各`CpuDifficulty.values`について設定、開始countdown完了、playing到達、合法な島数・HQ数を検証する。全組合せでCPUの最初の判断が期限前に発生せず、判断後も1判断最大1部隊であることを確認する。

- [ ] **Step 4: lifecycle focused testsを成功させる**

Run: `fvm flutter test test/game_controller_test.dart test/integration_qa_test.dart`

Expected: 全件PASS。Very Easyがpause/resume/replay/settings/island-count changeで保持される。

- [ ] **Step 5: `docs/game-rules.md`を4段階の正確なルールへ更新する**

次を明記する。

- 4プロファイルの承認済み数値表。
- 全難易度で候補生成・戦略・プレイヤーとの能力値が同じ。
- 見送りと代替候補選択だけが品質差。
- 見送り後は現在時刻から1回だけ再スケジュールしcatch-upしない。
- timing RNGとquality RNGは独立し固定seedで再現可能。
- 初期選択はNormal。

- [ ] **Step 6: `docs/integration-qa.md`へ自動・手動QAプロトコルを記載する**

自動検証欄にはfocused/all tests、analyze、build、4段階勾配testを記録する。手動比較欄には6・8・10・12島×4難易度の初動、判断頻度、候補品質、順序逆転、急変の有無を記録する。

Very Easy初心者向け確認は次の操作を固定する。

1. 操作間隔を3秒以上空ける。
2. 1回につき1部隊だけ送る。
3. 最も兵力の多い自軍島から、最寄りの占領可能な島を狙う。
4. 相手の出兵に合わせた反応的防衛を行わない。
5. 各島数を最大3試合観察し、実行した試合の勝敗と観察事項を記録する。未実行は未実行とし、特定の勝利数を保証条件にしない。

結果欄は実際に実行した日付、commit SHA、島数、各試合の勝敗、観察事項を記入する構造にする。未実行を成功として記載せず、勝率と操作感は残存する調整リスクとして扱う。

#### 受け入れ条件の更新（2026-08-10）

ユーザー承認により、Very Easyの最終プロファイルは
5500〜7000ms・見送り55%・最優先候補選択率20%のまま採用する。再調整後の6島Very Easyの
初心者向け手順では`敗北/敗北/敗北`（0勝）を観察したが、従来の「各島数で最大3試合以内に
最低1勝」という条件は受入れをブロックする保証条件から外す。未実行の島数・難易度を成功と
推定せず、実測された勝敗と観察事項だけを記録する。「クリアしやすい」はプロダクト意図として
維持し、勝率と操作感は残存するキャリブレーションリスクとして扱う。

- [ ] **Step 7: Task 4をコミットする**

```bash
git add test/game_controller_test.dart test/integration_qa_test.dart docs/game-rules.md docs/integration-qa.md
git commit -m "test: cover four-tier CPU difficulty lifecycle"
```

---

### Task 5: codegen差分を統制し、完全検証を行う

**Files:**
- Verify: `lib/game/game_controller.g.dart`
- Verify: all changed production, test, and documentation files

- [ ] **Step 1: formatと静的なdiff hygieneを実行する**

Run: `fvm dart format lib/game/game_state.dart lib/game/cpu_strategy.dart lib/home.dart test/cpu_strategy_test.dart test/cpu_controller_integration_test.dart test/game_rules_test.dart test/game_controller_test.dart test/widget_test.dart test/integration_qa_test.dart test/tactical_ui_test.dart`

Expected: formatter成功。

Run: `git diff --check`

Expected: outputなし、exit 0。

- [ ] **Step 2: codegenを実行し生成物の根拠を確認する**

Run: `fvm dart run build_runner build --delete-conflicting-outputs`

Expected: codegen成功。

Run: `git diff -- lib/game/game_controller.g.dart`

Expected: `lib/game/game_controller.dart`の注釈付きprovider signatureが変わっていなければoutputなし。hashだけの差分が出た場合は、toolchainとsourceの対応を確認し、このIssue由来でない生成差分をPRへ含めない。source signatureを変更した場合だけ生成差分をstageする。

- [ ] **Step 3: focused suitesを再実行する**

Run: `fvm flutter test test/cpu_strategy_test.dart test/cpu_controller_integration_test.dart test/game_rules_test.dart test/game_controller_test.dart test/widget_test.dart test/integration_qa_test.dart test/tactical_ui_test.dart`

Expected: 全件PASS。

- [ ] **Step 4: repository-wide verificationを実行する**

Run: `fvm flutter analyze`

Expected: `No issues found!`。

Run: `fvm flutter test`

Expected: 全test PASS。実行件数をQA記録へ転記する。

Run: `fvm flutter build web`

Expected: exit 0、`build/web`生成。

Run: `fvm flutter build apk --debug`

Expected: exit 0、debug APK生成。

Run: `fvm flutter build ios --simulator --no-codesign`

Expected: exit 0、Simulator application bundle生成。ローカルXcode環境に起因する失敗はログと環境情報を記録し、required checkと混同しない。

- [ ] **Step 5: 4段階の手動QAを観察・記録する**

同一build、同一map条件で6・8・10・12島のVery Easy、Easy、Normal、Hardを順に比較する。Very EasyはTask 4の初心者操作プロトコルを各島数最大3試合観察し、実行した各試合の勝敗を記録する。Easy→Normal→Hardでは初動・判断頻度・最優先候補品質が段階的に上がり、隣接tierで体感が急変しないことを観察する。勝利数は保証条件ではなく、未実行の行は未実行のまま記録する。

勝率または操作感に調整余地が見つかった場合は残存キャリブレーションリスクとして報告し、承認済み3軸の定数を変更する場合だけユーザー承認を得る。戦略分岐または能力補正は追加しない。

- [ ] **Step 6: 最終diffとscopeを監査する**

Run: `git status --short`

Expected: 意図したpathだけがmodified/untracked。

Run: `git diff --stat origin/main...HEAD`

Expected: Very Easy、4段階profile、関連test/docsだけ。

Run: `git diff origin/main...HEAD -- lib/game/game_rules.dart lib/game/movement_timing.dart`

Expected: outputなし。兵力・増加・移動・戦闘ルールに差分なし。

Run: `git diff --check origin/main...HEAD`

Expected: outputなし、exit 0。

- [ ] **Step 7: 検証・QA記録をコミットする**

`docs/integration-qa.md`へ実際のcommand、結果、commit SHA、手動試合結果を反映する。

```bash
git add docs/integration-qa.md
git add lib/game/game_controller.g.dart
git commit -m "docs: record CPU difficulty verification"
```

`game_controller.g.dart`に根拠ある差分がない場合はstageしない。QA文書がTask 4から変わらなかった場合は空commitを作らない。

---

### Task 6: Ready PR、レビュー、required checksを完了する

**Files:**
- Verify: branch全体とGitHub PR state

- [ ] **Step 1: completion前verificationをcurrent HEADで再実行する**

`superpowers:verification-before-completion`を使用し、`git rev-parse HEAD`を記録した直後に少なくとも`fvm flutter analyze`、`fvm flutter test`、`git diff --check origin/main...HEAD`を再実行する。古いSHAの結果を流用しない。

- [ ] **Step 2: implementation reviewとfinal reviewを通す**

Issue実装担当以外のreviewで設計適合、correctness、回帰、アクセシビリティ、test gap、生成物scopeを確認する。actionable findingは同じbranchで修正し、focused/full verificationを再実行する。実害のある指摘が0件になるまで繰り返す。

- [ ] **Step 3: 意図したpathだけをpushする**

Run: `git status --short --branch`

Expected: clean worktree、Issue専用branchが最新`origin/main`をbaseにしている。

Run: `git push -u origin HEAD`

Expected: 現在のIssue専用branchを同名のremote branchへpushし、upstream設定に成功する。

- [ ] **Step 4: Ready PRを作成する**

PR本文へ、follow-up Issueのclose reference、設計/計画、4段階profile表、実装概要、テスト証拠、手動QA、非対象、`game_controller.g.dart`の扱いを記載する。DraftではなくReady for reviewにし、baseは`main`、headはIssue専用branchとする。mergeは行わない。

- [ ] **Step 5: GitHub Codex reviewを1回だけ依頼する**

トップレベルのreview markerを記録し、同じPRで再依頼しない。review完了後、最新review本文、inline comments、unresolved threadsを確認する。既存conversation commentをreview成功として扱わない。

- [ ] **Step 6: 全レビュー指摘を解消する**

actionable findingごとに再現・根拠確認・修正・focused test・full test・pushを行い、該当threadへcommit SHAと検証結果を返信してresolveする。指摘を採用しない場合は技術的根拠を返信し、未解決threadを残さない。

- [ ] **Step 7: required checksをcurrent HEADで成功させる**

PR head SHAとcheck suite SHAが一致することを確認する。required checkがpendingなら完了まで監視し、failure/cancelled/timed_outはlogから原因を特定して同一branchで修正する。successまたは明示的neutral/skippedがbranch protection上許容されることを確認する。

- [ ] **Step 8: completion evidenceと振り返りを記録する**

次を満たした時点だけ完了とする。

- PRがOpenかつReady。
- mergeable stateにblockがない。
- unresolved review threadsが0。
- GitHub Codex reviewのactionable findingが0。
- required checksが最新head SHAで全成功。
- Issue acceptance criteria、manual QA、generated diff scopeがPR本文またはcompletion commentから追跡可能。

実装中に得た改善点を、再利用可能なworkflow、test、ドキュメントの観点で振り返り、必要なら非破壊のfollow-up提案として記録する。PRはmergeしない。
