import 'package:shared_preferences/shared_preferences.dart';

import 'storage.dart';

class PreferencesStore implements TextStore {
  PreferencesStore(this.prefs, {this.key = 'practice.todos'});

  final SharedPreferencesAsync prefs;
  final String key;

  @override
  Future<String?> read() => prefs.getString(key);

  @override
  Future<void> write(String value) => prefs.setString(key, value);
}
