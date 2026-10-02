// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get myPageTitle => 'My Page / PROFILE';

  @override
  String get myPageStats => 'STATS';

  @override
  String get myPageHistory => 'HISTORY';

  @override
  String get myPageDefaultName => 'Commander';

  @override
  String get myPageEdit => 'Edit profile';

  @override
  String get myPageLocalDevice => 'Saved on this device. No cloud sync.';

  @override
  String get myPageProfileSaved => 'Profile saved on this device.';

  @override
  String get myPageLoading => 'Loading saved profile data…';

  @override
  String get myPageReadError =>
      'Could not load saved data. Your records have not been cleared.';

  @override
  String get myPageRetry => 'Retry';

  @override
  String get myPageName => 'Display name';

  @override
  String get myPageNameHint =>
      '1–20 characters after trimming spaces. Leave unchanged to keep the default name.';

  @override
  String get myPageInvalidName =>
      'Use 1–20 characters without control characters.';

  @override
  String get myPageAvatar => 'Profile icon';

  @override
  String get myPageSave => 'Save';

  @override
  String get myPageSaving => 'Saving profile…';

  @override
  String get myPageSaveError =>
      'Not saved. Your edits are still here; retry saving.';

  @override
  String get myPageUnsavedChanges => 'Unsaved changes';

  @override
  String get myPageDiscardTitle => 'Discard profile edits?';

  @override
  String get myPageKeepEditing => 'Keep editing';

  @override
  String get myPageDiscard => 'Discard';

  @override
  String get myPageCompleted => 'Completed matches';

  @override
  String get myPageWins => 'Wins';

  @override
  String get myPageLosses => 'Losses';

  @override
  String get myPageDraws => 'Draws';

  @override
  String get myPageWinRate => 'Win rate';

  @override
  String get myPageCompletedTime => 'Completed match time (h:mm:ss)';

  @override
  String get myPageDispatches => 'Dispatches';

  @override
  String get myPageForces => 'Forces sent';

  @override
  String get myPageCaptures => 'Captures';

  @override
  String get myPageAbandoned => 'Abandoned';

  @override
  String get myPageInterrupted => 'Result unknown';

  @override
  String get myPageInProgress => 'In progress';

  @override
  String get myPageNoCompleted => 'No completed matches recorded yet.';

  @override
  String get myPageByDifficulty => 'By difficulty';

  @override
  String get myPageFastest => 'Fastest victory (h:mm:ss)';

  @override
  String get myPageRecent => 'Recent 5 matches';

  @override
  String get myPageNoMatches => 'No matches recorded yet.';

  @override
  String get myPageViewHistory => 'View history';

  @override
  String get myPageMatchDetail => 'Match details';

  @override
  String get myPageHistoryPending =>
      'History filters and match details are being added in the next integration step.';

  @override
  String myPageTotalXp({required int xp}) {
    return 'Total XP: $xp';
  }

  @override
  String myPageMatchXp({required int xp}) {
    return '$xp XP earned';
  }

  @override
  String myPageStatsSince({required String date}) {
    return 'Statistics recorded since $date. Earlier XP has no match records.';
  }

  @override
  String myPageAvatarChoice({required int number}) {
    return 'Icon $number';
  }

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
  String get howToPlay => 'How to Play';

  @override
  String get tutorialTitle => 'How to Play';

  @override
  String get tutorialStepSourceTitle => '1. Choose your island';

  @override
  String get tutorialStepDestinationTitle => '2. Send soldiers';

  @override
  String get tutorialStepCaptureTitle => '3. Take the island';

  @override
  String get tutorialStepVictoryTitle => '4. Defeat the enemy to win!';

  @override
  String get tutorialSourceInstruction =>
      'Green islands are yours. Tap the island marked \"100\".';

  @override
  String get tutorialDestinationInstruction =>
      'Tap the outlined gray island. Half of your soldiers will move there.';

  @override
  String get tutorialCaptureInstruction =>
      'If your soldiers outnumber the island number, it becomes yours.';

  @override
  String get tutorialVictoryInstruction =>
      'Your islands gain one soldier each second. Remove every red island and moving enemy troop to win!';

  @override
  String tutorialDispatchFromTo({required int remaining}) {
    return 'At start: 100 → $remaining soldiers';
  }

  @override
  String tutorialDispatchBreakdown({
    required int sent,
    required int remaining,
  }) {
    return 'Send $sent soldiers / keep $remaining';
  }

  @override
  String tutorialCaptureValues({
    required int attack,
    required int defense,
    required int captured,
  }) {
    return '$attack - island number $defense = $captured soldiers';
  }

  @override
  String get tutorialCaptureComplete => 'The island is green!';

  @override
  String tutorialGrowthDemo({required int growth}) {
    return '+$growth / second';
  }

  @override
  String tutorialProgress({required int step}) {
    return 'Step $step / 4';
  }

  @override
  String tutorialBoardSemantics({required int step}) {
    return 'Tutorial map, step $step of 4';
  }

  @override
  String get tutorialBack => 'Back';

  @override
  String get tutorialNext => 'Continue';

  @override
  String get tutorialReturnSettings => 'Back to Match Setup';

  @override
  String get tutorialLifecyclePaused =>
      'Practice paused. Tap Resume to continue.';

  @override
  String get tutorialLifecycleResizeRequired =>
      'Make the window larger to resume the tutorial.';

  @override
  String get tutorialResume => 'Resume';

  @override
  String get tutorialSpectatorNotice =>
      'Even in spectator mode, choose islands and send soldiers here.';

  @override
  String get tutorialRetrySource => 'Tap the green island.';

  @override
  String get tutorialRetryDestination => 'Tap the outlined gray island.';

  @override
  String get tutorialRetryCapture =>
      'Wait for the soldiers to reach the island.';

  @override
  String get tutorialRulesHeading => 'Rules to remember';

  @override
  String get tutorialRuleEqualForces => 'Equal numbers cannot take islands';

  @override
  String get tutorialRuleReinforce => 'Send soldiers to your island';

  @override
  String get tutorialRuleMinimumForces => 'One soldier cannot send';

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
  String get viewportTooSmallTitle => 'Window too small';

  @override
  String get viewportTooSmallDescription =>
      'The match is held to protect the battlefield. Enlarge the window to display the current map safely.';

  @override
  String get viewportReadyDescription =>
      'The current map is ready. Tap Resume to continue the match.';

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
  String boardTitle({required String difficulty, required int islandCount}) {
    return '$difficulty / $islandCount islands';
  }

  @override
  String boardTitleSpectator({
    required String playerDifficulty,
    required String cpuDifficulty,
    required int islandCount,
  }) {
    return '1P $playerDifficulty / 2P $cpuDifficulty / $islandCount islands';
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
  String get returnSettings => 'BACK TO SETTINGS';

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
  String get replay => 'NEW MAP';

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

  @override
  String get rematch => 'REMATCH';

  @override
  String get rematchHint => 'Same map and difficulty';

  @override
  String get rematchSpectatorHint => 'Same map and both CPU difficulties';

  @override
  String get rematchMissing => 'The starting map is unavailable for rematch.';

  @override
  String get rematchEnlarge => 'Enlarge the window to rematch on the same map.';

  @override
  String get storageChecking => 'Checking local storage…';

  @override
  String get storageOwned =>
      'Use the first Conquest tab, or close it and retry here. A normal match cannot start in two tabs.';

  @override
  String get storageUnavailable =>
      'Local storage is unavailable. Your game can continue; unsaved matches can be retried.';

  @override
  String get matchSaving => 'Saving match…';

  @override
  String get matchUnsaved => 'Match not saved';

  @override
  String get matchSaved => 'Match saved';

  @override
  String get storageRetry => 'Retry saving';

  @override
  String get rankUnavailable => 'Rank unavailable until storage loads';
}
