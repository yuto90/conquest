import 'dart:async';
import 'dart:math' as math;

import 'package:conquest/game/cpu_strategy.dart';
import 'package:conquest/game/game_rules.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/game/very_hard_cpu.dart';

/// Constants for the repository-managed local Very Hard comparison.
///
/// The case list is deliberately part of the repository contract. Changing a
/// seed, viewport, timing bound, or scoring rule changes the meaning of a
/// comparison and therefore belongs in a separately reviewed change.
abstract final class VeryHardBenchmarkConfig {
  static const islandCounts = <int>[6, 8, 10, 12];
  static const seedsByIslandCount = <int, List<int>>{
    6: <int>[6001, 6002, 6003, 6004, 6005, 6006, 6007, 6008, 6009, 6010],
    8: <int>[8001, 8002, 8003, 8004, 8005, 8006, 8007, 8008, 8009, 8010],
    10: <int>[
      10001,
      10002,
      10003,
      10004,
      10005,
      10006,
      10007,
      10008,
      10009,
      10010,
    ],
    12: <int>[
      12001,
      12002,
      12003,
      12004,
      12005,
      12006,
      12007,
      12008,
      12009,
      12010,
    ],
  };
  static const maxGameTimeMs = 10 * 60 * 1000;
  static const simulationStepMs = 50;
  static const decisionTimeout = VeryHardCpuConfig.decisionTimeout;
  static const transportGrace = Duration(seconds: 5);
  static const decisionIntervalMinMs = VeryHardCpuConfig.minDecisionIntervalMs;
  static const decisionIntervalMaxMs = VeryHardCpuConfig.maxDecisionIntervalMs;

  /// The map geometry used by deterministic local comparisons.
  ///
  /// This is the existing renderer reference viewport, not a benchmark-only
  /// rules implementation. It gives map generation and movement timing a
  /// stable geometry while remaining independent of the local monitor size.
  static const viewport = GameRules.referenceMapViewport;
}

/// One fixed match in the 80-match comparison matrix.
final class BenchmarkCase {
  const BenchmarkCase({
    required this.islandCount,
    required this.seed,
    required this.veryHardFaction,
  });

  final int islandCount;
  final int seed;
  final Faction veryHardFaction;

  Faction get hardFaction => switch (veryHardFaction) {
    Faction.player => Faction.cpu,
    Faction.cpu => Faction.player,
    Faction.neutral => throw StateError('Very Hard cannot control neutral'),
  };

  String get id => '$islandCount-$seed-${veryHardFaction.name}';
}

/// Returns the exact 4 × 10 × 2 comparison matrix.
Iterable<BenchmarkCase> benchmarkCases() sync* {
  for (final islandCount in VeryHardBenchmarkConfig.islandCounts) {
    for (final seed
        in VeryHardBenchmarkConfig.seedsByIslandCount[islandCount]!) {
      yield BenchmarkCase(
        islandCount: islandCount,
        seed: seed,
        veryHardFaction: Faction.player,
      );
      yield BenchmarkCase(
        islandCount: islandCount,
        seed: seed,
        veryHardFaction: Faction.cpu,
      );
    }
  }
}

enum BenchmarkOutcome { win, draw, loss, uncompleted }

/// Safe, aggregateable result of one match. No board or candidate body is
/// retained so reports cannot accidentally disclose game state.
final class BenchmarkMatchResult {
  const BenchmarkMatchResult({
    required this.islandCount,
    required this.seed,
    required this.veryHardFaction,
    required this.outcome,
    required this.elapsedMs,
    this.fallbackCount = 0,
    this.decisionRequestCount = 0,
    this.decisionLatenciesMs = const <int>[],
    this.providerApiErrors = const <String, int>{},
    this.modelAliases = const <String>[],
    this.resolvedModels = const <String>[],
    this.promptVersions = const <String>[],
    this.staleResponseCount = 0,
    this.fallbackStrategyFactions = const <Faction>[],
  });

  final int islandCount;
  final int seed;
  final Faction veryHardFaction;
  final BenchmarkOutcome outcome;
  final int elapsedMs;
  final int fallbackCount;
  final int decisionRequestCount;
  final List<int> decisionLatenciesMs;
  final Map<String, int> providerApiErrors;
  final List<String> modelAliases;
  final List<String> resolvedModels;
  final List<String> promptVersions;
  final int staleResponseCount;

  /// Aggregate-safe trace used to verify fallbacks stay on the Very Hard side.
  final List<Faction> fallbackStrategyFactions;
}

/// Aggregate metrics for either one island-count bucket or all matches.
final class BenchmarkAggregate {
  BenchmarkAggregate._({required this.matches})
    : wins = matches
          .where((match) => match.outcome == BenchmarkOutcome.win)
          .length,
      draws = matches
          .where((match) => match.outcome == BenchmarkOutcome.draw)
          .length,
      losses = matches
          .where((match) => match.outcome == BenchmarkOutcome.loss)
          .length,
      uncompleted = matches
          .where((match) => match.outcome == BenchmarkOutcome.uncompleted)
          .length,
      fallbackCount = matches.fold<int>(
        0,
        (total, match) => total + match.fallbackCount,
      ),
      decisionRequestCount = matches.fold<int>(
        0,
        (total, match) => total + match.decisionRequestCount,
      ),
      decisionLatenciesMs = List.unmodifiable([
        for (final match in matches) ...match.decisionLatenciesMs,
      ]),
      providerApiErrors = _mergeErrors(matches);

  factory BenchmarkAggregate.fromMatches(Iterable<BenchmarkMatchResult> input) {
    return BenchmarkAggregate._(matches: List.unmodifiable(input));
  }

  final List<BenchmarkMatchResult> matches;
  final int wins;
  final int draws;
  final int losses;
  final int uncompleted;
  final int fallbackCount;
  final int decisionRequestCount;
  final List<int> decisionLatenciesMs;
  final Map<String, int> providerApiErrors;

  int get matchCount => matches.length;

  double get score => wins + draws * 0.5;

  double get scoreRate => matchCount == 0 ? 0 : score / matchCount;

  double get fallbackRate =>
      decisionRequestCount == 0 ? 0 : fallbackCount / decisionRequestCount;

  double get latencyMedianMs => _percentile(decisionLatenciesMs, 0.5);

  double get latencyP95Ms => _nearestRank(decisionLatenciesMs, 0.95);

  static Map<String, int> _mergeErrors(Iterable<BenchmarkMatchResult> matches) {
    final result = <String, int>{};
    for (final match in matches) {
      for (final entry in match.providerApiErrors.entries) {
        result[entry.key] = (result[entry.key] ?? 0) + entry.value;
      }
    }
    return Map.unmodifiable(result);
  }
}

/// Markdown-ready result of the complete local comparison.
final class BenchmarkReport {
  BenchmarkReport._({
    required this.pullRequestNumber,
    required this.headSha,
    required this.executedAtUtc,
    required this.matches,
  }) : total = BenchmarkAggregate.fromMatches(matches),
       byIslandCount = {
         for (final islandCount in VeryHardBenchmarkConfig.islandCounts)
           islandCount: BenchmarkAggregate.fromMatches(
             matches.where((match) => match.islandCount == islandCount),
           ),
       };

  factory BenchmarkReport.fromMatches({
    required int pullRequestNumber,
    required String headSha,
    required DateTime executedAtUtc,
    required Iterable<BenchmarkMatchResult> matches,
  }) {
    return BenchmarkReport._(
      pullRequestNumber: pullRequestNumber,
      headSha: headSha,
      executedAtUtc: executedAtUtc.toUtc(),
      matches: List.unmodifiable(matches),
    );
  }

  final int pullRequestNumber;
  final String headSha;
  final DateTime executedAtUtc;
  final List<BenchmarkMatchResult> matches;
  final BenchmarkAggregate total;
  final Map<int, BenchmarkAggregate> byIslandCount;

  String toJapaneseMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Very Hard / Hard ローカル比較')
      ..writeln()
      ..writeln('- PR: #$pullRequestNumber')
      ..writeln('- HEAD: `$headSha`')
      ..writeln('- 実行日時（UTC）: ${executedAtUtc.toIso8601String()}')
      ..writeln(
        '- モデル（サーバー固定）: `${_joinOrFallback(_modelAliases, VeryHardCpuConfig.model)}`',
      )
      ..writeln(
        '- 解決済みモデル: ${_joinOrFallback(_resolvedModels, 'Function応答のdiagnostics未返却')}',
      )
      ..writeln('- プロンプト版: ${_joinOrFallback(_promptVersions, '未返却')}')
      ..writeln('- スキーマ版: `${VeryHardCpuConfig.schemaVersion}`')
      ..writeln(
        '- 条件: 各島数10 seed × Very Hardの1P/2P入替、固定step ${VeryHardBenchmarkConfig.simulationStepMs}ms、上限10ゲーム分',
      )
      ..writeln()
      ..writeln('## 集計')
      ..writeln()
      ..writeln('| 島数 | 試合 | 勝利 | 引分 | 敗北 | 未完了 | 勝点率 | フォールバック | 率 |')
      ..writeln(
        '| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |',
      );

    for (final islandCount in VeryHardBenchmarkConfig.islandCounts) {
      final aggregate = byIslandCount[islandCount]!;
      buffer.writeln(
        '| $islandCount | ${aggregate.matchCount} | ${aggregate.wins} | ${aggregate.draws} | ${aggregate.losses} | ${aggregate.uncompleted} | ${_percent(aggregate.scoreRate)} | ${aggregate.fallbackCount} | ${_percent(aggregate.fallbackRate)} |',
      );
    }
    buffer
      ..writeln(
        '| **合計** | **${total.matchCount}** | **${total.wins}** | **${total.draws}** | **${total.losses}** | **${total.uncompleted}** | **${_percent(total.scoreRate)}** | **${total.fallbackCount}** | **${_percent(total.fallbackRate)}** |',
      )
      ..writeln()
      ..writeln('勝利=1点、引分=0.5点、敗北=0点、未完了=0点。未完了は引分と別集計。')
      ..writeln()
      ..writeln('## レイテンシとエラー')
      ..writeln()
      ..writeln('- 判断リクエスト数: ${total.decisionRequestCount}')
      ..writeln('- 応答レイテンシ中央値: ${_milliseconds(total.latencyMedianMs)} ms')
      ..writeln('- 応答レイテンシ95パーセンタイル: ${_milliseconds(total.latencyP95Ms)} ms')
      ..writeln('- Provider/APIエラー: ${_formatErrors(total.providerApiErrors)}')
      ..writeln()
      ..writeln('## 観察事項')
      ..writeln()
      ..writeln('- 固定seed、既存GameRules、既存Hard戦略、実Preview APIの応答を使った観測です。')
      ..writeln('- フォールバックは製品と同じ1.2秒期限を基準に数え、応答待ち時間もゲーム内時刻へ反映しています。')
      ..writeln('- 目標の勝点率60%は観測基準であり、未達でも結果を隠さず記録します。')
      ..writeln()
      ..writeln('## 残存リスク')
      ..writeln()
      ..writeln(
        '- 80試合はモデル更新、Previewのリージョン、ネットワーク、非決定論性を含むサンプルであり、Hard超過の数学的保証ではありません。',
      )
      ..writeln(
        '- 未認証Previewのレート制限・予算・Provider状態は実行時に変動します。資格情報や盤面本文はこのレポートへ出力しません。',
      )
      ..writeln(
        '- 応答が1.2秒を超えて解放されない場合、その試合の以後のVery Hardリクエストは重ねず、Hardフォールバックで継続します。',
      );
    return buffer.toString();
  }

  Iterable<String> get _resolvedModels sync* {
    final values = <String>{};
    for (final match in matches) {
      values.addAll(match.resolvedModels);
    }
    yield* values;
  }

  Iterable<String> get _modelAliases sync* {
    final values = <String>{};
    for (final match in matches) {
      values.addAll(match.modelAliases);
    }
    yield* values;
  }

  Iterable<String> get _promptVersions sync* {
    final values = <String>{};
    for (final match in matches) {
      values.addAll(match.promptVersions);
    }
    yield* values;
  }
}

final class BenchmarkHeadMismatch implements Exception {
  const BenchmarkHeadMismatch({required this.expected, required this.actual});

  final String expected;
  final String actual;

  @override
  String toString() =>
      'BenchmarkHeadMismatch(expected: $expected, actual: $actual)';
}

final class BenchmarkPreflightUnavailable implements Exception {
  const BenchmarkPreflightUnavailable();

  @override
  String toString() => 'BenchmarkPreflightUnavailable';
}

final class BenchmarkTransportUnsettled implements Exception {
  const BenchmarkTransportUnsettled();

  @override
  String toString() => 'BenchmarkTransportUnsettled';
}

/// Runs the fixed comparison matrix against an injected gateway.
///
/// The CLI supplies [HttpVeryHardCpuGateway] pointed at a Preview URL. Tests
/// inject a fake [VeryHardCpuGateway], so ordinary test and CI runs never
/// contact Jev.
final class VeryHardBenchmarkRunner {
  VeryHardBenchmarkRunner({
    required this.gateway,
    this.rules = const GameRules(),
    this.viewport = VeryHardBenchmarkConfig.viewport,
  });

  final VeryHardCpuGateway gateway;
  final GameRules rules;
  final IslandMapViewport viewport;

  Future<BenchmarkReport> run({
    required int pullRequestNumber,
    required String expectedHead,
    required String localHead,
    Iterable<BenchmarkCase>? cases,
    int maxGameTimeMs = VeryHardBenchmarkConfig.maxGameTimeMs,
    int simulationStepMs = VeryHardBenchmarkConfig.simulationStepMs,
    Duration decisionTimeout = VeryHardBenchmarkConfig.decisionTimeout,
    Duration transportGrace = VeryHardBenchmarkConfig.transportGrace,
    DateTime Function()? nowUtc,
  }) async {
    if (expectedHead != localHead) {
      throw BenchmarkHeadMismatch(expected: expectedHead, actual: localHead);
    }
    if (pullRequestNumber <= 0) {
      throw ArgumentError.value(
        pullRequestNumber,
        'pullRequestNumber',
        'must be positive',
      );
    }
    if (maxGameTimeMs <= 0 || simulationStepMs <= 0) {
      throw ArgumentError('simulation bounds must be positive');
    }
    if (decisionTimeout <= Duration.zero || transportGrace < Duration.zero) {
      throw ArgumentError('transport durations are invalid');
    }

    final selectedCases = List<BenchmarkCase>.unmodifiable(
      cases ?? benchmarkCases(),
    );
    if (selectedCases.isEmpty) {
      throw ArgumentError('at least one benchmark case is required');
    }

    final preflight = await gateway.preflight(
      matchId: 'very-hard-benchmark-pr-$pullRequestNumber',
    );
    if (!preflight.available) {
      throw const BenchmarkPreflightUnavailable();
    }

    final results = <BenchmarkMatchResult>[];
    for (final comparisonCase in selectedCases) {
      results.add(
        await _MatchSimulation(
          gateway: gateway,
          rules: rules,
          viewport: viewport,
          comparisonCase: comparisonCase,
          maxGameTimeMs: maxGameTimeMs,
          simulationStepMs: simulationStepMs,
          decisionTimeout: decisionTimeout,
          transportGrace: transportGrace,
        ).run(),
      );
    }
    return BenchmarkReport.fromMatches(
      pullRequestNumber: pullRequestNumber,
      headSha: expectedHead,
      executedAtUtc: (nowUtc ?? () => DateTime.now().toUtc())(),
      matches: results,
    );
  }
}

final class _MatchSimulation {
  _MatchSimulation({
    required this.gateway,
    required this.rules,
    required this.viewport,
    required this.comparisonCase,
    required this.maxGameTimeMs,
    required this.simulationStepMs,
    required this.decisionTimeout,
    required this.transportGrace,
  }) {
    final configuration = GameConfiguration(
      totalIslandCount: comparisonCase.islandCount,
      gameMode: GameMode.cpuVsCpu,
      playerCpuDifficulty: comparisonCase.veryHardFaction == Faction.player
          ? CpuDifficulty.veryHard
          : CpuDifficulty.hard,
      cpuDifficulty: comparisonCase.veryHardFaction == Faction.cpu
          ? CpuDifficulty.veryHard
          : CpuDifficulty.hard,
    );
    _state = rules.initialState(
      configuration: configuration,
      random: math.Random(comparisonCase.seed),
      viewport: viewport,
    );
    _state = rules.tick(
      rules.startCountdown(_state),
      deltaMs: GameRules.startCountdownDurationMs,
    );
    _veryHardStrategy = CpuStrategy(
      controlledFaction: comparisonCase.veryHardFaction,
      timingRandom: math.Random(_randomSeed(11)),
      qualityRandom: math.Random(_randomSeed(12)),
      rules: rules,
      viewport: viewport,
    );
    _hardStrategy = CpuStrategy(
      controlledFaction: comparisonCase.hardFaction,
      timingRandom: math.Random(_randomSeed(21)),
      qualityRandom: math.Random(_randomSeed(22)),
      rules: rules,
      viewport: viewport,
    );
    _nextVeryHardDecisionAtMs =
        _state.elapsedMs +
        _veryHardStrategy.nextDecisionDelayMs(
          difficulty: CpuDifficulty.veryHard,
        );
    _nextHardDecisionAtMs =
        _state.elapsedMs +
        _hardStrategy.nextDecisionDelayMs(difficulty: CpuDifficulty.hard);
  }

  final VeryHardCpuGateway gateway;
  final GameRules rules;
  final IslandMapViewport viewport;
  final BenchmarkCase comparisonCase;
  final int maxGameTimeMs;
  final int simulationStepMs;
  final Duration decisionTimeout;
  final Duration transportGrace;

  late GameState _state;
  late CpuStrategy _veryHardStrategy;
  late CpuStrategy _hardStrategy;
  late int _nextVeryHardDecisionAtMs;
  late int _nextHardDecisionAtMs;
  var _nextDecisionSerial = 0;
  var _nextMovingForceId = 0;
  var _fallbackCount = 0;
  var _decisionRequestCount = 0;
  var _staleResponseCount = 0;
  final _decisionLatenciesMs = <int>[];
  final _providerApiErrors = <String, int>{};
  final _modelAliases = <String>{};
  final _resolvedModels = <String>{};
  final _promptVersions = <String>{};
  final _fallbackStrategyFactions = <Faction>[];

  Future<BenchmarkMatchResult> run() async {
    while (_state.phase == GamePhase.playing &&
        _state.elapsedMs < maxGameTimeMs) {
      final remaining = maxGameTimeMs - _state.elapsedMs;
      _advanceFixed(math.min(simulationStepMs, remaining));
      if (_state.phase != GamePhase.playing) break;

      if (_state.elapsedMs >= _nextVeryHardDecisionAtMs) {
        await _runVeryHardDecision();
        if (_state.phase == GamePhase.playing) {
          _nextVeryHardDecisionAtMs =
              _state.elapsedMs +
              _veryHardStrategy.nextDecisionDelayMs(
                difficulty: CpuDifficulty.veryHard,
              );
        }
      }
    }

    return BenchmarkMatchResult(
      islandCount: comparisonCase.islandCount,
      seed: comparisonCase.seed,
      veryHardFaction: comparisonCase.veryHardFaction,
      outcome: _outcome(),
      elapsedMs: _state.elapsedMs,
      fallbackCount: _fallbackCount,
      decisionRequestCount: _decisionRequestCount,
      decisionLatenciesMs: List.unmodifiable(_decisionLatenciesMs),
      providerApiErrors: Map.unmodifiable(_providerApiErrors),
      modelAliases: List.unmodifiable(_modelAliases),
      resolvedModels: List.unmodifiable(_resolvedModels),
      promptVersions: List.unmodifiable(_promptVersions),
      staleResponseCount: _staleResponseCount,
      fallbackStrategyFactions: List.unmodifiable(_fallbackStrategyFactions),
    );
  }

  void _advanceFixed(int durationMs) {
    var remaining = math.min(
      math.max(0, durationMs),
      math.max(0, maxGameTimeMs - _state.elapsedMs),
    );
    while (remaining > 0 && _state.phase == GamePhase.playing) {
      final step = math.min(simulationStepMs, remaining);
      _state = rules.tick(_state, deltaMs: step);
      remaining -= step;
      if (_state.phase == GamePhase.playing) _runHardDecisionIfDue();
    }
  }

  void _runHardDecisionIfDue() {
    if (_state.elapsedMs < _nextHardDecisionAtMs) return;
    final decision = _hardStrategy.decide(
      _state,
      difficulty: CpuDifficulty.hard,
    );
    if (decision != null) {
      _state = _hardStrategy.applyDecision(
        _state,
        decision,
        movingForceId: _takeMovingForceId(),
      );
    }
    _nextHardDecisionAtMs =
        _state.elapsedMs +
        _hardStrategy.nextDecisionDelayMs(difficulty: CpuDifficulty.hard);
  }

  Future<void> _runVeryHardDecision() async {
    final request = VeryHardDecisionRequest.fromState(
      _state,
      matchId: 'benchmark-${comparisonCase.id}',
      requestId: 'decision-${_nextDecisionSerial++}',
      factions: [comparisonCase.veryHardFaction],
      viewport: viewport,
    );
    _decisionRequestCount++;
    final transport = Future<VeryHardDecisionResponse>.sync(
      () => gateway.decide(request),
    );
    final transportSettled = transport.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    final stopwatch = Stopwatch()..start();
    try {
      final response = await transport.timeout(decisionTimeout);
      final elapsedMs = stopwatch.elapsedMilliseconds;
      _recordLatency(elapsedMs);
      _advanceFixed(elapsedMs);
      _recordDiagnostics(response);
      _applyResponse(request, response);
      return;
    } on TimeoutException {
      _recordLatency(
        math.max(decisionTimeout.inMilliseconds, stopwatch.elapsedMilliseconds),
      );
      _recordError('timeout');
      _advanceFixed(decisionTimeout.inMilliseconds);
      _applyHardFallback(errorCode: 'timeout');

      try {
        await transportSettled.timeout(transportGrace);
      } on TimeoutException {
        _recordError('timeout_pending');
        throw const BenchmarkTransportUnsettled();
      }
      final totalElapsedMs = stopwatch.elapsedMilliseconds;
      final extraElapsedMs = totalElapsedMs - decisionTimeout.inMilliseconds;
      if (extraElapsedMs > 0) _advanceFixed(extraElapsedMs);
    } on Object catch (error) {
      final elapsedMs = stopwatch.elapsedMilliseconds;
      _recordLatency(elapsedMs);
      _advanceFixed(elapsedMs);
      _recordError(_providerErrorCode(error));
      _applyHardFallback(errorCode: 'provider_error');
    }
  }

  void _applyResponse(
    VeryHardDecisionRequest request,
    VeryHardDecisionResponse response,
  ) {
    final candidateId =
        response.candidateIdsByFaction[comparisonCase.veryHardFaction];
    if (candidateId == null) {
      _recordError('invalid_response');
      _applyHardFallback(errorCode: 'invalid_response');
      return;
    }
    final subject = request.subjectFor(comparisonCase.veryHardFaction);
    VeryHardCandidate? selected;
    for (final candidate in subject.candidates) {
      if (candidate.id == candidateId) {
        selected = candidate;
        break;
      }
    }
    if (selected == null) {
      _recordError('invalid_response');
      _applyHardFallback(errorCode: 'invalid_response');
      return;
    }
    final decision = selected.decision;
    if (decision == null || _state.phase != GamePhase.playing) return;
    final before = _state;
    final next = _veryHardStrategy.applyDecision(
      _state,
      decision,
      movingForceId: _takeMovingForceId(),
    );
    if (identical(before, next) || before == next) {
      _staleResponseCount++;
    } else {
      _state = next;
    }
  }

  void _applyHardFallback({required String errorCode}) {
    _fallbackCount++;
    if (_state.phase != GamePhase.playing) return;
    _fallbackStrategyFactions.add(_veryHardStrategy.controlledFaction);
    final decision = _veryHardStrategy.decide(
      _state,
      difficulty: CpuDifficulty.hard,
    );
    if (decision != null) {
      _state = _veryHardStrategy.applyDecision(
        _state,
        decision,
        movingForceId: _takeMovingForceId(),
      );
    }
    // The concrete fallback reason is already represented in the provider or
    // timeout error map. Keep this parameter explicit to make the product
    // fallback boundary visible to the simulator without logging board data.
    if (errorCode.isEmpty) _recordError('provider_error');
  }

  void _recordDiagnostics(VeryHardDecisionResponse response) {
    if (response.model != null) {
      _modelAliases.add(response.model!);
    }
    if (response.resolvedModel != null) {
      _resolvedModels.add(response.resolvedModel!);
    }
    if (response.promptVersion == VeryHardCpuConfig.promptVersion) {
      _promptVersions.add(response.promptVersion!);
    }
  }

  void _recordLatency(int latencyMs) {
    _decisionLatenciesMs.add(math.max(0, latencyMs));
  }

  void _recordError(String code) {
    _providerApiErrors[code] = (_providerApiErrors[code] ?? 0) + 1;
  }

  int _takeMovingForceId() => _nextMovingForceId++;

  BenchmarkOutcome _outcome() {
    final result = _state.result;
    if (result == null) return BenchmarkOutcome.uncompleted;
    if (result.type == GameResultType.draw || result.winner == null) {
      return BenchmarkOutcome.draw;
    }
    return result.winner == comparisonCase.veryHardFaction
        ? BenchmarkOutcome.win
        : BenchmarkOutcome.loss;
  }

  int _randomSeed(int stream) => comparisonCase.seed * 100 + stream;
}

String _providerErrorCode(Object error) {
  if (error is VeryHardCpuProtocolException) return 'invalid_response';
  if (error is VeryHardCpuHttpException) {
    final status = error.statusCode;
    if (status == 402) return 'http_402';
    if (status == 429) return 'http_429';
    if (status >= 500) return 'http_5xx';
    return 'http_$status';
  }
  if (error is TimeoutException) return 'timeout';
  return 'provider_error';
}

double _percentile(List<int> values, double fraction) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  if (sorted.length.isOdd) return sorted[sorted.length ~/ 2].toDouble();
  final upper = sorted.length ~/ 2;
  return (sorted[upper - 1] + sorted[upper]) / 2;
}

double _nearestRank(List<int> values, double fraction) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final rank = math.max(1, (sorted.length * fraction).ceil());
  return sorted[rank - 1].toDouble();
}

String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

String _milliseconds(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}

String _joinOrFallback(Iterable<String> values, String fallback) {
  final list = values.toList();
  return list.isEmpty ? fallback : list.join(', ');
}

String _formatErrors(Map<String, int> errors) {
  if (errors.isEmpty) return 'なし';
  final entries = errors.entries.toList()
    ..sort((first, second) => first.key.compareTo(second.key));
  return entries.map((entry) => '${entry.key}=${entry.value}').join(', ');
}
