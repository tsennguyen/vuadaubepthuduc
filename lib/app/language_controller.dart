import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _langPrefKey = 'app_language';

class LanguageController extends StateNotifier<Locale> {
  LanguageController() : super(const Locale('vi')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_langPrefKey);
    if (stored != null) {
      state = Locale(stored);
    }
  }

  Future<void> setLanguage(String languageCode) async {
    state = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langPrefKey, languageCode);
  }

  Future<void> toggleLanguage() async {
    final next = state.languageCode == 'vi' ? 'en' : 'vi';
    await setLanguage(next);
  }
}

final localeProvider =
    StateNotifierProvider<LanguageController, Locale>((ref) {
  return LanguageController();
});
