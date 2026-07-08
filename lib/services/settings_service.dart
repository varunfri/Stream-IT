import 'package:hive/hive.dart';

class SettingsService {
  static const String boxName = 'settings_box';

  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late Box _box;
  bool _initialized = false;

  Future<void> init() async {
    _box = await Hive.openBox(boxName);
    _initialized = true;
  }

  bool get includeAllInSearch => _initialized
      ? _box.get('includeAllInSearch', defaultValue: false) as bool
      : false;
  set includeAllInSearch(bool value) {
    if (_initialized) _box.put('includeAllInSearch', value);
  }


  bool get isLockEnabled => _initialized
      ? _box.get('isLockEnabled', defaultValue: false) as bool
      : false;
  set isLockEnabled(bool value) {
    if (_initialized) _box.put('isLockEnabled', value);
  }
}
