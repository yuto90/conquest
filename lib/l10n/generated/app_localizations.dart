import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// The tactical game brand name.
  ///
  /// In en, this message translates to:
  /// **'CONQUEST'**
  String get brandName;

  /// The application title shown by the Web entry point and Flutter app.
  ///
  /// In en, this message translates to:
  /// **'CONQUEST ISLES'**
  String get appTitle;

  /// The title screen action that opens match setup.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get titleStart;

  /// Title screen help dialog heading and accessibility label.
  ///
  /// In en, this message translates to:
  /// **'How to Play'**
  String get titleHowToPlay;

  /// Game objective in the title help dialog.
  ///
  /// In en, this message translates to:
  /// **'Capture the islands and defeat the opposing army.'**
  String get titleHowToGoal;

  /// First instruction in the title help dialog.
  ///
  /// In en, this message translates to:
  /// **'1. Select one of your green islands with at least 2 forces.'**
  String get titleHowToSelect;

  /// Second instruction in the title help dialog.
  ///
  /// In en, this message translates to:
  /// **'2. Tap another island to send half your forces. Send them to a friendly island to reinforce it.'**
  String get titleHowToSend;

  /// Third instruction in the title help dialog.
  ///
  /// In en, this message translates to:
  /// **'3. Send more forces than the island\'s defenders to capture it. Eliminate all enemy islands and moving forces to win.'**
  String get titleHowToCapture;

  /// Title sound information heading and accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get titleSound;

  /// Explains where the in-match background music setting is available.
  ///
  /// In en, this message translates to:
  /// **'Background music can be controlled in match setup and while paused.'**
  String get titleSoundDescription;

  /// Close action for title information dialogs.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get titleClose;

  /// The match setup action that returns to the title screen.
  ///
  /// In en, this message translates to:
  /// **'Back to Title'**
  String get returnTitle;

  /// The stable countdown start word.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get startWord;

  /// The Very Easy CPU difficulty name.
  ///
  /// In en, this message translates to:
  /// **'Very Easy'**
  String get difficultyVeryEasy;

  /// The Easy CPU difficulty name.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get difficultyEasy;

  /// The Normal CPU difficulty name.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get difficultyNormal;

  /// The Hard CPU difficulty name.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get difficultyHard;

  /// The configuration step marker.
  ///
  /// In en, this message translates to:
  /// **'Match Setup / 01'**
  String get settingsStep;

  /// The configuration screen heading.
  ///
  /// In en, this message translates to:
  /// **'Match Setup'**
  String get settingsTitle;

  /// The configuration screen explanation.
  ///
  /// In en, this message translates to:
  /// **'Choose the battlefield size and CPU decision speed.'**
  String get settingsDescription;

  /// The English and Japanese base title for rank 0.
  ///
  /// In en, this message translates to:
  /// **'Recruit'**
  String get rankTitleRecruit;

  /// The English and Japanese base title for ranks 1 through 5.
  ///
  /// In en, this message translates to:
  /// **'Private First Class'**
  String get rankTitlePrivateFirstClass;

  /// The English and Japanese base title for ranks 6 through 10.
  ///
  /// In en, this message translates to:
  /// **'Lance Corporal'**
  String get rankTitleLanceCorporal;

  /// The English and Japanese base title for ranks 11 through 15.
  ///
  /// In en, this message translates to:
  /// **'Corporal'**
  String get rankTitleCorporal;

  /// The English and Japanese base title for ranks 16 through 20.
  ///
  /// In en, this message translates to:
  /// **'Sergeant'**
  String get rankTitleSergeant;

  /// The English and Japanese base title for ranks 21 through 25.
  ///
  /// In en, this message translates to:
  /// **'Staff Sergeant'**
  String get rankTitleStaffSergeant;

  /// The English and Japanese base title for ranks 26 through 30.
  ///
  /// In en, this message translates to:
  /// **'Gunnery Sergeant'**
  String get rankTitleGunnerySergeant;

  /// The English and Japanese base title for ranks 31 through 35.
  ///
  /// In en, this message translates to:
  /// **'Master Sergeant'**
  String get rankTitleMasterSergeant;

  /// The English and Japanese base title for ranks 36 through 40.
  ///
  /// In en, this message translates to:
  /// **'First Sergeant'**
  String get rankTitleFirstSergeant;

  /// The English and Japanese base title for ranks 41 through 45.
  ///
  /// In en, this message translates to:
  /// **'Master Gunnery Sergeant'**
  String get rankTitleMasterGunnerySergeant;

  /// The English and Japanese base title for ranks 46 through 50.
  ///
  /// In en, this message translates to:
  /// **'Sergeant Major'**
  String get rankTitleSergeantMajor;

  /// The English and Japanese base title for ranks 51 through 55.
  ///
  /// In en, this message translates to:
  /// **'Warrant Officer One'**
  String get rankTitleWarrantOfficerOne;

  /// The English and Japanese base title for ranks 56 through 60.
  ///
  /// In en, this message translates to:
  /// **'Chief Warrant Officer Two'**
  String get rankTitleChiefWarrantOfficerTwo;

  /// The English and Japanese base title for ranks 61 through 65.
  ///
  /// In en, this message translates to:
  /// **'Chief Warrant Officer Three'**
  String get rankTitleChiefWarrantOfficerThree;

  /// The English and Japanese base title for ranks 66 through 70.
  ///
  /// In en, this message translates to:
  /// **'Chief Warrant Officer Four'**
  String get rankTitleChiefWarrantOfficerFour;

  /// The English and Japanese base title for ranks 71 through 75.
  ///
  /// In en, this message translates to:
  /// **'Chief Warrant Officer Five'**
  String get rankTitleChiefWarrantOfficerFive;

  /// The English and Japanese base title for ranks 76 through 80.
  ///
  /// In en, this message translates to:
  /// **'Second Lieutenant'**
  String get rankTitleSecondLieutenant;

  /// The English and Japanese base title for ranks 81 through 85.
  ///
  /// In en, this message translates to:
  /// **'First Lieutenant'**
  String get rankTitleFirstLieutenant;

  /// The English and Japanese base title for ranks 86 through 90.
  ///
  /// In en, this message translates to:
  /// **'Captain'**
  String get rankTitleCaptain;

  /// The English and Japanese base title for ranks 91 through 95.
  ///
  /// In en, this message translates to:
  /// **'Major'**
  String get rankTitleMajor;

  /// The English and Japanese base title for ranks 96 through 99.
  ///
  /// In en, this message translates to:
  /// **'Lieutenant Colonel'**
  String get rankTitleLieutenantColonel;

  /// The English and Japanese base title for ranks 100 through 109.
  ///
  /// In en, this message translates to:
  /// **'Colonel'**
  String get rankTitleColonel;

  /// The English and Japanese base title for ranks 110 through 119.
  ///
  /// In en, this message translates to:
  /// **'Brigadier General'**
  String get rankTitleBrigadierGeneral;

  /// The English and Japanese base title for ranks 120 through 129.
  ///
  /// In en, this message translates to:
  /// **'Major General'**
  String get rankTitleMajorGeneral;

  /// The English and Japanese base title for ranks 130 through 139.
  ///
  /// In en, this message translates to:
  /// **'Lieutenant General'**
  String get rankTitleLieutenantGeneral;

  /// The English and Japanese base title for rank 140.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get rankTitleGeneral;

  /// The current rank and title.
  ///
  /// In en, this message translates to:
  /// **'Rank {rank} · {title}'**
  String rankDisplay({required int rank, required String title});

  /// The XP remaining until the next rank.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP to next rank'**
  String rankProgress({required int xp});

  /// The maximum rank display.
  ///
  /// In en, this message translates to:
  /// **'MAX'**
  String get rankMax;

  /// The island count setting label.
  ///
  /// In en, this message translates to:
  /// **'Island Count'**
  String get islandCountLabel;

  /// The game mode setting label.
  ///
  /// In en, this message translates to:
  /// **'Game Mode'**
  String get gameModeLabel;

  /// The CPU difficulty setting label.
  ///
  /// In en, this message translates to:
  /// **'CPU Difficulty'**
  String get cpuDifficultyLabel;

  /// The player CPU difficulty label in spectator mode.
  ///
  /// In en, this message translates to:
  /// **'1P CPU Difficulty'**
  String get playerCpuDifficultyLabel;

  /// The opponent CPU difficulty label in spectator mode.
  ///
  /// In en, this message translates to:
  /// **'2P CPU Difficulty'**
  String get opponentCpuDifficultyLabel;

  /// The background music setting label.
  ///
  /// In en, this message translates to:
  /// **'BGM'**
  String get bgmLabel;

  /// The enabled state of the background music setting.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get bgmOn;

  /// The disabled state of the background music setting.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get bgmOff;

  /// The background music toggle accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Background music: {state}'**
  String bgmToggleSemantics({required String state});

  /// The start game button text.
  ///
  /// In en, this message translates to:
  /// **'Start Game'**
  String get startGame;

  /// Explains why the map cannot be started and how to recover.
  ///
  /// In en, this message translates to:
  /// **'The map cannot be prepared at this screen size. Enlarge the window or reopen in portrait orientation.'**
  String get mapUnavailableMessage;

  /// The selected standard match summary.
  ///
  /// In en, this message translates to:
  /// **'Selected: {islandCount} islands / {difficulty}'**
  String selectedSummary({
    required int islandCount,
    required String difficulty,
  });

  /// The selected spectator match summary.
  ///
  /// In en, this message translates to:
  /// **'Selected: {islandCount} islands / 1P {playerDifficulty} / 2P {cpuDifficulty}'**
  String selectedSummarySpectator({
    required int islandCount,
    required String playerDifficulty,
    required String cpuDifficulty,
  });

  /// The player versus CPU mode label.
  ///
  /// In en, this message translates to:
  /// **'PLAY VS CPU'**
  String get modePlayerVsCpu;

  /// The CPU versus CPU mode label.
  ///
  /// In en, this message translates to:
  /// **'WATCH CPU VS CPU'**
  String get modeCpuVsCpu;

  /// The standard start button accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Start game with {islandCount} islands on {difficulty} CPU difficulty'**
  String startGameSemantics({
    required int islandCount,
    required String difficulty,
  });

  /// The spectator start button accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Watch CPU versus CPU with {islandCount} islands, 1P {playerDifficulty}, 2P {cpuDifficulty}'**
  String startSpectatorSemantics({
    required int islandCount,
    required String playerDifficulty,
    required String cpuDifficulty,
  });

  /// The island count option accessibility label and tooltip.
  ///
  /// In en, this message translates to:
  /// **'{count} islands'**
  String islandCountChoice({required int count});

  /// The CPU difficulty option accessibility label and tooltip.
  ///
  /// In en, this message translates to:
  /// **'{owner}{difficulty} CPU difficulty'**
  String difficultyChoice({required String owner, required String difficulty});

  /// The tactical map accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Island map, {islandCount} islands'**
  String boardMapSemantics({required int islandCount});

  /// The tactical board title.
  ///
  /// In en, this message translates to:
  /// **'Tactical Chart / {islandCount} islands'**
  String boardTitle({required int islandCount});

  /// The board status before selecting a source.
  ///
  /// In en, this message translates to:
  /// **'Select one of your islands'**
  String get boardStatusUnselected;

  /// The board status after selecting a source.
  ///
  /// In en, this message translates to:
  /// **'Dispatch source selected'**
  String get boardStatusSelected;

  /// The board hint before selecting a source.
  ///
  /// In en, this message translates to:
  /// **'Tap an island to select it\nRequires at least 2 forces'**
  String get boardStatusUnselectedDetail;

  /// The board hint after selecting a source.
  ///
  /// In en, this message translates to:
  /// **'Tap to choose a target\nDispatch half your forces'**
  String get boardStatusSelectedDetail;

  /// The spectator board status.
  ///
  /// In en, this message translates to:
  /// **'Watching CPU match'**
  String get spectatorStatus;

  /// The spectator board detail.
  ///
  /// In en, this message translates to:
  /// **'CPU versus CPU match in progress'**
  String get spectatorDetail;

  /// The pause button accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Pause game'**
  String get pauseGame;

  /// The pause sheet heading.
  ///
  /// In en, this message translates to:
  /// **'Match Paused'**
  String get pauseHeading;

  /// The pause sheet title.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get pauseTitle;

  /// The pause sheet explanation.
  ///
  /// In en, this message translates to:
  /// **'You can review the current battlefield.'**
  String get pauseDescription;

  /// The resume match button.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// The return to settings button.
  ///
  /// In en, this message translates to:
  /// **'Return to Settings'**
  String get returnSettings;

  /// The quit confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Quit match?'**
  String get quitTitle;

  /// The quit confirmation dialog explanation.
  ///
  /// In en, this message translates to:
  /// **'Your current match will not be saved.'**
  String get quitDescription;

  /// The cancel action.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// The quit action.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get quit;

  /// The result sheet heading.
  ///
  /// In en, this message translates to:
  /// **'Battle Complete'**
  String get resultHeading;

  /// The player victory result.
  ///
  /// In en, this message translates to:
  /// **'Victory'**
  String get victory;

  /// The player defeat result.
  ///
  /// In en, this message translates to:
  /// **'Defeat'**
  String get defeat;

  /// The draw result.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get draw;

  /// The XP earned in the result screen.
  ///
  /// In en, this message translates to:
  /// **'+{xp} XP'**
  String xpEarned({required int xp});

  /// The result display for a rank up.
  ///
  /// In en, this message translates to:
  /// **'Rank Up! Rank {rank} · {title}'**
  String rankUp({required int rank, required String title});

  /// The spectator result when 1P wins.
  ///
  /// In en, this message translates to:
  /// **'1P WIN'**
  String get spectatorPlayerWin;

  /// The spectator result when 2P wins.
  ///
  /// In en, this message translates to:
  /// **'2P WIN'**
  String get spectatorCpuWin;

  /// The spectator draw result.
  ///
  /// In en, this message translates to:
  /// **'DRAW'**
  String get spectatorDraw;

  /// The replay match button.
  ///
  /// In en, this message translates to:
  /// **'Play Again'**
  String get replay;

  /// The countdown live region label.
  ///
  /// In en, this message translates to:
  /// **'Game start {countdown}'**
  String countdownSemantics({required String countdown});

  /// The countdown helper text.
  ///
  /// In en, this message translates to:
  /// **'Prepare to Deploy'**
  String get prepareToDeploy;

  /// The selected dispatch source badge.
  ///
  /// In en, this message translates to:
  /// **'SOURCE'**
  String get sourceBadge;

  /// The player faction name.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get factionPlayer;

  /// The CPU faction name.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get factionCpu;

  /// The neutral faction name.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get factionNeutral;

  /// The first spectator CPU slot name.
  ///
  /// In en, this message translates to:
  /// **'1P'**
  String get factionPlayerOne;

  /// The second spectator CPU slot name.
  ///
  /// In en, this message translates to:
  /// **'2P'**
  String get factionPlayerTwo;

  /// The small island accessibility name.
  ///
  /// In en, this message translates to:
  /// **'small island'**
  String get islandSizeSmall;

  /// The medium island accessibility name.
  ///
  /// In en, this message translates to:
  /// **'medium island'**
  String get islandSizeMedium;

  /// The large island accessibility name.
  ///
  /// In en, this message translates to:
  /// **'large island'**
  String get islandSizeLarge;

  /// The headquarters accessibility name.
  ///
  /// In en, this message translates to:
  /// **'headquarters'**
  String get islandSizeHeadquarters;

  /// The owned island accessibility description.
  ///
  /// In en, this message translates to:
  /// **'{faction} {size}, forces {forces} of {capacity}, current value {value}'**
  String islandOwnedSemantics({
    required String faction,
    required String size,
    required int forces,
    required int capacity,
    required int value,
  });

  /// The neutral island accessibility description.
  ///
  /// In en, this message translates to:
  /// **'{faction} {size}, durability {durability}, current value {value}'**
  String islandNeutralSemantics({
    required String faction,
    required String size,
    required int durability,
    required int value,
  });

  /// The selected island action state.
  ///
  /// In en, this message translates to:
  /// **'selected dispatch source'**
  String get islandActionSelected;

  /// The valid destination action state.
  ///
  /// In en, this message translates to:
  /// **'valid dispatch destination'**
  String get islandActionDestination;

  /// The available source action state.
  ///
  /// In en, this message translates to:
  /// **'available dispatch source'**
  String get islandActionAvailable;

  /// The unavailable source action state.
  ///
  /// In en, this message translates to:
  /// **'not available as dispatch source'**
  String get islandActionUnavailable;

  /// The selected source interaction hint.
  ///
  /// In en, this message translates to:
  /// **'Tap again to cancel selection, or choose a valid destination.'**
  String get islandHintSelected;

  /// The destination interaction hint.
  ///
  /// In en, this message translates to:
  /// **'Tap to dispatch troops here.'**
  String get islandHintDestination;

  /// The available source interaction hint.
  ///
  /// In en, this message translates to:
  /// **'Tap to select this island as a dispatch source.'**
  String get islandHintAvailable;

  /// The unavailable source interaction hint.
  ///
  /// In en, this message translates to:
  /// **'This island cannot be selected as a dispatch source.'**
  String get islandHintUnavailable;

  /// The moving troop accessibility description.
  ///
  /// In en, this message translates to:
  /// **'{faction} moving troop, strength {strength}, current value {value}, from island {source} to island {destination}, action unavailable, not tappable'**
  String movingForceSemantics({
    required String faction,
    required int strength,
    required int value,
    required int source,
    required int destination,
  });

  /// The feedback for an invalid source selection.
  ///
  /// In en, this message translates to:
  /// **'Choose a player island with more than 1 force.'**
  String get feedbackUnavailableSource;

  /// The feedback for a source invalidated during selection.
  ///
  /// In en, this message translates to:
  /// **'Dispatch unavailable: the source must be player-owned and have more than 1 force.'**
  String get feedbackInvalidatedSource;

  /// Non-modal explanation shown when background music preparation or playback fails.
  ///
  /// In en, this message translates to:
  /// **'BGM could not be played. The match continues without music.'**
  String get bgmUnavailableMessage;

  /// Explicit retry action for a rejected or unavailable background music playback.
  ///
  /// In en, this message translates to:
  /// **'Play BGM'**
  String get bgmRetry;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
