// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get brandName => 'CONQUEST';

  @override
  String get startWord => 'START';

  @override
  String get difficultyVeryEasy => 'Very Easy';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyNormal => 'Normal';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get settingsStep => '対戦設定 / 01';

  @override
  String get settingsTitle => '対戦設定';

  @override
  String get settingsDescription => '海域の規模とCPUの判断速度を選択してください。';

  @override
  String get islandCountLabel => '島数';

  @override
  String get gameModeLabel => 'ゲームモード';

  @override
  String get cpuDifficultyLabel => 'CPU難易度';

  @override
  String get playerCpuDifficultyLabel => '1P CPU難易度';

  @override
  String get opponentCpuDifficultyLabel => '2P CPU難易度';

  @override
  String get startGame => 'ゲーム開始';

  @override
  String selectedSummary({
    required int islandCount,
    required String difficulty,
  }) {
    return '選択中：$islandCount島 / $difficulty';
  }

  @override
  String selectedSummarySpectator({
    required int islandCount,
    required String playerDifficulty,
    required String cpuDifficulty,
  }) {
    return '選択中：$islandCount島 / 1P $playerDifficulty / 2P $cpuDifficulty';
  }

  @override
  String get modePlayerVsCpu => 'CPU対戦';

  @override
  String get modeCpuVsCpu => 'CPU同士を観戦';

  @override
  String startGameSemantics({
    required int islandCount,
    required String difficulty,
  }) {
    return '$islandCount島、$difficulty CPUでゲームを開始';
  }

  @override
  String startSpectatorSemantics({
    required int islandCount,
    required String playerDifficulty,
    required String cpuDifficulty,
  }) {
    return '$islandCount島、1P $playerDifficulty、2P $cpuDifficultyのCPU対戦を観戦';
  }

  @override
  String islandCountChoice({required int count}) {
    return '$count島';
  }

  @override
  String difficultyChoice({required String owner, required String difficulty}) {
    return '$owner$difficulty CPU難易度';
  }

  @override
  String boardMapSemantics({required int islandCount}) {
    return '島のマップ、$islandCount島';
  }

  @override
  String boardTitle({required int islandCount}) {
    return '戦術海図 / $islandCount島';
  }

  @override
  String get boardStatusUnselected => '自軍の島を選択';

  @override
  String get boardStatusSelected => '出兵元を選択中';

  @override
  String get boardStatusUnselectedDetail => '島をタップして選択\n兵力2以上で出兵可能';

  @override
  String get boardStatusSelectedDetail => 'タップで目標を指定\n兵力の半分を派遣';

  @override
  String get spectatorStatus => '観戦中';

  @override
  String get spectatorDetail => 'CPU同士の対戦を表示中';

  @override
  String get pauseGame => '対戦を一時停止';

  @override
  String get pauseHeading => '対戦を一時停止';

  @override
  String get pauseTitle => '一時停止';

  @override
  String get pauseDescription => '現在の盤面を確認できます。';

  @override
  String get resume => '再開';

  @override
  String get returnSettings => '設定へ戻る';

  @override
  String get quitTitle => '対戦を終了しますか？';

  @override
  String get quitDescription => '現在の対戦内容は保存されません。';

  @override
  String get cancel => 'キャンセル';

  @override
  String get quit => '終了';

  @override
  String get resultHeading => '戦闘終了';

  @override
  String get victory => '勝利';

  @override
  String get defeat => '敗北';

  @override
  String get draw => '引き分け';

  @override
  String get spectatorPlayerWin => '1P 勝利';

  @override
  String get spectatorCpuWin => '2P 勝利';

  @override
  String get spectatorDraw => '引き分け';

  @override
  String get replay => '再戦';

  @override
  String countdownSemantics({required String countdown}) {
    return 'ゲーム開始 $countdown';
  }

  @override
  String get prepareToDeploy => '出撃準備';

  @override
  String get sourceBadge => '出兵元';

  @override
  String get factionPlayer => 'プレイヤー';

  @override
  String get factionCpu => 'CPU';

  @override
  String get factionNeutral => '中立';

  @override
  String get factionPlayerOne => '1P';

  @override
  String get factionPlayerTwo => '2P';

  @override
  String get islandSizeSmall => '小島';

  @override
  String get islandSizeMedium => '中島';

  @override
  String get islandSizeLarge => '大島';

  @override
  String get islandSizeHeadquarters => '本拠地';

  @override
  String islandOwnedSemantics({
    required String faction,
    required String size,
    required int forces,
    required int capacity,
    required int value,
  }) {
    return '$factionの$size、兵力$forces/$capacity、現在値$value';
  }

  @override
  String islandNeutralSemantics({
    required String faction,
    required String size,
    required int durability,
    required int value,
  }) {
    return '$factionの$size、耐久力$durability、現在値$value';
  }

  @override
  String get islandActionSelected => '出兵元を選択中';

  @override
  String get islandActionDestination => '出兵可能な目標';

  @override
  String get islandActionAvailable => '出兵元として選択可能';

  @override
  String get islandActionUnavailable => '出兵元として選択不可';

  @override
  String get islandHintSelected => 'もう一度タップして選択を解除するか、出兵可能な目標を選択してください。';

  @override
  String get islandHintDestination => 'タップしてここへ出兵します。';

  @override
  String get islandHintAvailable => 'タップしてこの島を出兵元に選択します。';

  @override
  String get islandHintUnavailable => 'この島は出兵元に選択できません。';

  @override
  String movingForceSemantics({
    required String faction,
    required int strength,
    required int value,
    required int source,
    required int destination,
  }) {
    return '$factionの移動部隊、兵力$strength、現在値$value、島$sourceから島$destinationへ移動中、操作不可、タップ不可';
  }

  @override
  String get feedbackUnavailableSource => '兵力が2以上ある自軍の島を選択してください。';

  @override
  String get feedbackInvalidatedSource => '出兵できません。出兵元は自軍が所有し、兵力が2以上必要です。';
}
