import 'package:shared_preferences/shared_preferences.dart';

const legacyXpStorageKey = 'conquest.rank.totalXp';

abstract interface class LegacyXpSource {
  Future<Object?> read();
}

final class SharedPreferencesLegacyXpSource implements LegacyXpSource {
  SharedPreferencesLegacyXpSource({Future<SharedPreferences>? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _preferences;

  @override
  Future<Object?> read() async {
    final preferences = await _preferences;
    await preferences.reload();
    return preferences.get(legacyXpStorageKey);
  }
}
