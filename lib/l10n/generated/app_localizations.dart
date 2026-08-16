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

  /// The local two-player configuration screen explanation.
  ///
  /// In en, this message translates to:
  /// **'Choose the battlefield size for a shared-screen match.'**
  String get settingsDescriptionLocal;

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

  /// The start game button text.
  ///
  /// In en, this message translates to:
  /// **'Start Game'**
  String get startGame;

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

  /// The selected local two-player match summary.
  ///
  /// In en, this message translates to:
  /// **'Selected: {islandCount} islands / 2P LOCAL'**
  String selectedSummaryLocal({required int islandCount});

  /// The player versus CPU mode label.
  ///
  /// In en, this message translates to:
  /// **'PLAY VS CPU'**
  String get modePlayerVsCpu;

  /// The local two-player mode label.
  ///
  /// In en, this message translates to:
  /// **'2P LOCAL'**
  String get modePlayerVsPlayer;

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

  /// The local two-player start button accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Start local two-player game with {islandCount} islands'**
  String startLocalSemantics({required int islandCount});

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
