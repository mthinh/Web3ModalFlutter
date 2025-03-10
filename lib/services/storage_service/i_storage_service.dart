abstract class IStorageService {
  Future<void> init();
  String? getString(String key, {String? defaultValue});
  Future<bool> setString(String key, String value);
  Future<bool> clearAll();
  Future<bool> clearKey(String key);
}
