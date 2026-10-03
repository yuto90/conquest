import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'l10n/generated/app_localizations.dart';
import 'home.dart';
import 'ui/tactical_theme.dart';
import 'profile/legacy_xp.dart';
import 'profile/match_identity.dart';
import 'profile/match_persistence.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // iOS gets its device-specific orientation policy from Info.plist.  The
  // iPhone declaration remains portrait-only while the iPad declaration also
  // permits landscape. Other platforms keep the existing portrait policy.
  SystemChrome.setPreferredOrientations(
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
        ? const <DeviceOrientation>[]
        : const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );
  String appVersion;
  try {
    final package = await PackageInfo.fromPlatform().timeout(
      const Duration(seconds: 3),
    );
    appVersion = '${package.version}+${package.buildNumber}';
  } catch (_) {
    appVersion = 'unknown';
  }
  final persistence = MatchPersistence(
    factory: MatchContextFactory(
      ids: SecureUuidGenerator(),
      clock: SystemUtcClock(),
      appVersion: appVersion,
      rulesVersion: '1',
    ),
    openBackend: DurableProfileBackend.open,
    legacyXp: SharedPreferencesLegacyXpSource(),
  );
  unawaited(persistence.prepare());
  runApp(
    ProviderScope(
      overrides: [matchPersistenceProvider.overrideWithValue(persistence)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.locale});

  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      )!.appTitle,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTacticalTheme(),
      home: const Home(),
    );
  }
}
