// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get settingsStep => 'Match Setup / 01';

  @override
  String get settingsTitle => 'Match Setup';

  @override
  String get settingsDescription =>
      'Choose the battlefield size and CPU decision speed.';

  @override
  String get settingsDescriptionLocal =>
      'Choose the battlefield size for a shared-screen match.';

  @override
  String get islandCountLabel => 'Island Count';

  @override
  String get gameModeLabel => 'Game Mode';

  @override
  String get cpuDifficultyLabel => 'CPU Difficulty';

  @override
  String get playerCpuDifficultyLabel => '1P CPU Difficulty';

  @override
  String get opponentCpuDifficultyLabel => '2P CPU Difficulty';

  @override
  String get startGame => 'Start Game';

  @override
  String selectedSummary({
    required int islandCount,
    required String difficulty,
  }) {
    return 'Selected: $islandCount islands / $difficulty';
  }

  @override
  String selectedSummarySpectator({
    required int islandCount,
    required String playerDifficulty,
    required String cpuDifficulty,
  }) {
    return 'Selected: $islandCount islands / 1P $playerDifficulty / 2P $cpuDifficulty';
  }

  @override
  String selectedSummaryLocal({required int islandCount}) {
    return 'Selected: $islandCount islands / 2P LOCAL';
  }

  @override
  String get modePlayerVsCpu => 'PLAY VS CPU';

  @override
  String get modePlayerVsPlayer => '2P LOCAL';

  @override
  String get modeCpuVsCpu => 'WATCH CPU VS CPU';

  @override
  String startGameSemantics({
    required int islandCount,
    required String difficulty,
  }) {
    return 'Start game with $islandCount islands on $difficulty CPU difficulty';
  }

  @override
  String startSpectatorSemantics({
    required int islandCount,
    required String playerDifficulty,
    required String cpuDifficulty,
  }) {
    return 'Watch CPU versus CPU with $islandCount islands, 1P $playerDifficulty, 2P $cpuDifficulty';
  }

  @override
  String startLocalSemantics({required int islandCount}) {
    return 'Start local two-player game with $islandCount islands';
  }

  @override
  String islandCountChoice({required int count}) {
    return '$count islands';
  }

  @override
  String difficultyChoice({required String owner, required String difficulty}) {
    return '$owner$difficulty CPU difficulty';
  }

  @override
  String boardMapSemantics({required int islandCount}) {
    return 'Island map, $islandCount islands';
  }

  @override
  String boardTitle({required int islandCount}) {
    return 'Tactical Chart / $islandCount islands';
  }

  @override
  String get boardStatusUnselected => 'Select one of your islands';

  @override
  String get boardStatusSelected => 'Dispatch source selected';

  @override
  String get boardStatusUnselectedDetail =>
      'Tap an island to select it\nRequires at least 2 forces';

  @override
  String get boardStatusSelectedDetail =>
      'Tap to choose a target\nDispatch half your forces';

  @override
  String get spectatorStatus => 'Watching CPU match';

  @override
  String get spectatorDetail => 'CPU versus CPU match in progress';

  @override
  String get pauseGame => 'Pause game';

  @override
  String get pauseHeading => 'Match Paused';

  @override
  String get pauseTitle => 'Paused';

  @override
  String get pauseDescription => 'You can review the current battlefield.';

  @override
  String get resume => 'Resume';

  @override
  String get returnSettings => 'Return to Settings';

  @override
  String get quitTitle => 'Quit match?';

  @override
  String get quitDescription => 'Your current match will not be saved.';

  @override
  String get cancel => 'Cancel';

  @override
  String get quit => 'Quit';

  @override
  String get resultHeading => 'Battle Complete';

  @override
  String get victory => 'Victory';

  @override
  String get defeat => 'Defeat';

  @override
  String get draw => 'Draw';

  @override
  String get spectatorPlayerWin => '1P WIN';

  @override
  String get spectatorCpuWin => '2P WIN';

  @override
  String get spectatorDraw => 'DRAW';

  @override
  String get replay => 'Play Again';

  @override
  String countdownSemantics({required String countdown}) {
    return 'Game start $countdown';
  }

  @override
  String get prepareToDeploy => 'Prepare to Deploy';

  @override
  String get sourceBadge => 'SOURCE';

  @override
  String get factionPlayer => 'Player';

  @override
  String get factionCpu => 'CPU';

  @override
  String get factionNeutral => 'Neutral';

  @override
  String get factionPlayerOne => '1P';

  @override
  String get factionPlayerTwo => '2P';

  @override
  String get islandSizeSmall => 'small island';

  @override
  String get islandSizeMedium => 'medium island';

  @override
  String get islandSizeLarge => 'large island';

  @override
  String get islandSizeHeadquarters => 'headquarters';

  @override
  String islandOwnedSemantics({
    required String faction,
    required String size,
    required int forces,
    required int capacity,
    required int value,
  }) {
    return '$faction $size, forces $forces of $capacity, current value $value';
  }

  @override
  String islandNeutralSemantics({
    required String faction,
    required String size,
    required int durability,
    required int value,
  }) {
    return '$faction $size, durability $durability, current value $value';
  }

  @override
  String get islandActionSelected => 'selected dispatch source';

  @override
  String get islandActionDestination => 'valid dispatch destination';

  @override
  String get islandActionAvailable => 'available dispatch source';

  @override
  String get islandActionUnavailable => 'not available as dispatch source';

  @override
  String get islandHintSelected =>
      'Tap again to cancel selection, or choose a valid destination.';

  @override
  String get islandHintDestination => 'Tap to dispatch troops here.';

  @override
  String get islandHintAvailable =>
      'Tap to select this island as a dispatch source.';

  @override
  String get islandHintUnavailable =>
      'This island cannot be selected as a dispatch source.';

  @override
  String movingForceSemantics({
    required String faction,
    required int strength,
    required int value,
    required int source,
    required int destination,
  }) {
    return '$faction moving troop, strength $strength, current value $value, from island $source to island $destination, action unavailable, not tappable';
  }

  @override
  String get feedbackUnavailableSource =>
      'Choose a player island with more than 1 force.';

  @override
  String get feedbackInvalidatedSource =>
      'Dispatch unavailable: the source must be player-owned and have more than 1 force.';
}
