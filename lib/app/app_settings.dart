import 'package:flutter/material.dart';

import '../data/repositories/settings_repository.dart';

/// 全局应用设置（持久化）。
class AppSettings {
  AppSettings({
    this.currency = 'CNY',
    this.themeMode = ThemeMode.system,
    this.reminderEnabled = true,
    this.reminderDaysBefore = 3,
    this.dailyDigestEnabled = true,
    this.dailyDigestHour = 9,
  });

  String currency;
  ThemeMode themeMode;

  /// 到期本地通知（疫苗/驱虫/生日）。
  bool reminderEnabled;
  int reminderDaysBefore;

  /// 每日提醒摘要：每天定时推送当日到期事项。
  bool dailyDigestEnabled;
  int dailyDigestHour;

  AppSettings copy() => AppSettings(
        currency: currency,
        themeMode: themeMode,
        reminderEnabled: reminderEnabled,
        reminderDaysBefore: reminderDaysBefore,
        dailyDigestEnabled: dailyDigestEnabled,
        dailyDigestHour: dailyDigestHour,
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
    s.dailyDigestEnabled =
        await _repo.getBool('dailyDigestEnabled') ?? true;
    s.dailyDigestHour = await _repo.getInt('dailyDigestHour') ?? 9;
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
    await _repo.setBool('dailyDigestEnabled', s.dailyDigestEnabled);
    await _repo.setInt('dailyDigestHour', s.dailyDigestHour);
    await _repo.set(SettingsRepository.keyThemeMode, switch (s.themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}

const List<String> kCurrencies = ['CNY', 'USD', 'EUR', 'JPY', 'GBP', 'HKD'];
