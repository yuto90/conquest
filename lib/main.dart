import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/generated/app_localizations.dart';
import 'home.dart';
import 'ui/tactical_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // iOS gets its device-specific orientation policy from Info.plist.  The
  // iPhone declaration remains portrait-only while the iPad declaration also
  // permits landscape. Other platforms keep the existing portrait policy.
  SystemChrome.setPreferredOrientations(
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
        ? const <DeviceOrientation>[]
        : const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );
  runApp(const ProviderScope(child: MyApp()));
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
