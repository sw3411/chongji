import 'package:flutter/material.dart';

import '../data/repositories/settings_repository.dart';

/// 全局应用设置（持久化）。
class AppSettings {
  AppSettings({
    this.currency = 'CNY',
    this.themeMode = ThemeMode.system,
    this.reminderEnabled = true,
    this.reminderDaysBefore = 3,
  });

  String currency;
  ThemeMode themeMode;

  /// 到期本地通知（疫苗/驱虫/生日）。
  bool reminderEnabled;
  int reminderDaysBefore;

  AppSettings copy() => AppSettings(
        currency: currency,
        themeMode: themeMode,
        reminderEnabled: reminderEnabled,
        reminderDaysBefore: reminderDaysBefore,
      );
}

/// 设置加载/保存。
class AppSettingsController {
  AppSettingsController(this._repo);

  final SettingsRepository _repo;

  Future<AppSettings> load() async {
    final s = AppSettings();
    s.currency =
        await _repo.get(SettingsRepository.keyCurrency) ?? 'CNY';
    s.reminderEnabled =
        await _repo.getBool(SettingsRepository.keyReminderEnabled) ?? true;
    s.reminderDaysBefore =
        await _repo.getInt(SettingsRepository.keyReminderDaysBefore) ?? 3;
    final theme = await _repo.get(SettingsRepository.keyThemeMode);
    s.themeMode = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return s;
  }

  Future<void> save(AppSettings s) async {
    await _repo.set(SettingsRepository.keyCurrency, s.currency);
    await _repo.setBool(SettingsRepository.keyReminderEnabled, s.reminderEnabled);
    await _repo.setInt(
        SettingsRepository.keyReminderDaysBefore, s.reminderDaysBefore);
    await _repo.set(SettingsRepository.keyThemeMode, switch (s.themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}

const List<String> kCurrencies = ['CNY', 'USD', 'EUR', 'JPY', 'GBP', 'HKD'];
