// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CONQUEST ISLES';

  @override
  String get titleStart => 'Start';

  @override
  String get titleHowToPlay => 'How to Play';

  @override
  String get titleHowToGoal =>
      'Capture the islands and defeat the opposing army.';

  @override
  String get titleHowToSelect =>
      '1. Select one of your green islands with at least 2 forces.';

  @override
  String get titleHowToSend =>
      '2. Tap another island to send half your forces. Send them to a friendly island to reinforce it.';

  @override
  String get titleHowToCapture =>
      '3. Send more forces than the island\'s defenders to capture it. Eliminate all enemy islands and moving forces to win.';

  @override
  String get titleSound => 'Sound';

  @override
  String get titleSoundDescription =>
      'Background music can be controlled in match setup and while paused.';

  @override
  String get titleClose => 'Close';

  @override
  String get returnTitle => 'Back to Title';

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
  String get rankTitleRecruit => 'Recruit';

  @override
  String get rankTitlePrivateFirstClass => 'Private First Class';

  @override
  String get rankTitleLanceCorporal => 'Lance Corporal';

  @override
  String get rankTitleCorporal => 'Corporal';

  @override
  String get rankTitleSergeant => 'Sergeant';

  @override
  String get rankTitleStaffSergeant => 'Staff Sergeant';

  @override
  String get rankTitleGunnerySergeant => 'Gunnery Sergeant';

  @override
  String get rankTitleMasterSergeant => 'Master Sergeant';

  @override
  String get rankTitleFirstSergeant => 'First Sergeant';

  @override
  String get rankTitleMasterGunnerySergeant => 'Master Gunnery Sergeant';

  @override
  String get rankTitleSergeantMajor => 'Sergeant Major';

  @override
  String get rankTitleWarrantOfficerOne => 'Warrant Officer One';

  @override
  String get rankTitleChiefWarrantOfficerTwo => 'Chief Warrant Officer Two';

  @override
  String get rankTitleChiefWarrantOfficerThree => 'Chief Warrant Officer Three';

  @override
  String get rankTitleChiefWarrantOfficerFour => 'Chief Warrant Officer Four';

  @override
  String get rankTitleChiefWarrantOfficerFive => 'Chief Warrant Officer Five';

  @override
  String get rankTitleSecondLieutenant => 'Second Lieutenant';

  @override
  String get rankTitleFirstLieutenant => 'First Lieutenant';

  @override
  String get rankTitleCaptain => 'Captain';

  @override
  String get rankTitleMajor => 'Major';

  @override
  String get rankTitleLieutenantColonel => 'Lieutenant Colonel';

  @override
  String get rankTitleColonel => 'Colonel';

  @override
  String get rankTitleBrigadierGeneral => 'Brigadier General';

  @override
  String get rankTitleMajorGeneral => 'Major General';

  @override
  String get rankTitleLieutenantGeneral => 'Lieutenant General';

  @override
  String get rankTitleGeneral => 'General';

  @override
  String rankDisplay({required int rank, required String title}) {
    return 'Rank $rank · $title';
  }

  @override
  String rankProgress({required int xp}) {
    return '$xp XP to next rank';
  }

  @override
  String get rankMax => 'MAX';

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
  String get bgmLabel => 'BGM';

  @override
  String get bgmOn => 'ON';

  @override
  String get bgmOff => 'OFF';

  @override
  String bgmToggleSemantics({required String state}) {
    return 'Background music: $state';
  }

  @override
  String get startGame => 'Start Game';

  @override
  String get mapUnavailableMessage =>
      'The map cannot be prepared at this screen size. Enlarge the window or reopen in portrait orientation.';

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
  String get modePlayerVsCpu => 'PLAY VS CPU';

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
  String get boardStatusSelected => 'Dispatch source selected';

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
  String get matchSummaryHeading => 'Match Summary';

  @override
  String matchSummarySettings({
    required int islandCount,
    required String difficulty,
  }) {
    return '$islandCount islands / $difficulty CPU';
  }

  @override
  String matchSummaryTime({required String time}) {
    return 'Match Duration $time';
  }

  @override
  String matchSummaryDispatches({required int count}) {
    return 'Number of Troop Dispatches $count';
  }

  @override
  String matchSummaryForces({required int forces}) {
    return 'Troops Dispatched $forces';
  }

  @override
  String matchSummaryCaptures({required int count}) {
    return 'Islands Captured $count';
  }

  @override
  String matchSummarySemantics({
    required String settings,
    required String time,
    required String dispatches,
    required String forces,
    required String captures,
  }) {
    return 'Match summary. $settings. $time. $dispatches. $forces. $captures.';
  }

  @override
  String xpEarned({required int xp}) {
    return '+$xp XP';
  }

  @override
  String rankUp({required int rank, required String title}) {
    return 'Rank Up! Rank $rank · $title';
  }

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

  @override
  String get bgmUnavailableMessage =>
      'BGM could not be played. The match continues without music.';

  @override
  String get bgmRetry => 'Play BGM';
}
