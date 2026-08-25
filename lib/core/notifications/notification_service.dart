import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/models/health_record.dart';
import '../../domain/models/pet.dart';
import '../../domain/models/enums.dart';
import '../../domain/services/health_calculator.dart';

/// 本地通知：疫苗/驱虫到期 + 生日提醒。
/// 权限只在用户开启提醒开关时请求；保存记录时静默检查。
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<bool> initialize() async {
    if (_initialized) return true;
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    final ok = await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios));
    _initialized = ok ?? false;
    return _initialized;
  }

  /// 请求权限（仅在用户开启提醒开关时调用，会弹系统授权框）。
  static Future<bool> requestPermission() async {
    final ready = await initialize();
    if (!ready) return false;
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(alert: true, badge: true);
      return granted ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return true;
  }

  /// 检查通知是否已授权（不弹框）。
  static Future<bool> isPermissionGranted() async {
    final ready = await initialize();
    if (!ready) return false;
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final permissions = await ios.checkPermissions();
      return permissions?.isEnabled ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  static int _notifyId(String petId, String kind) => '$petId#$kind'.hashCode;

  /// 通用调度：到 dueDate 前 daysBefore 天的早上 9 点。
  static Future<void> _schedule(
    int notifyId,
    String title,
    String body,
    DateTime dueDate,
    int daysBefore,
    String channel,
    String channelName,
  ) async {
    await initialize();
    final when = tz.TZDateTime.from(
      DateTime(dueDate.year, dueDate.month, dueDate.day, 9)
          .subtract(Duration(days: daysBefore)),
      tz.local,
    );
    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      notifyId,
      title,
      body,
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channelName,
          channelDescription: '宠迹到期提醒',
          importance: Importance.defaultImportance,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// 同步一只宠物的全部提醒（疫苗/体内驱虫/体外驱虫/生日）。
  /// [enabled] 为提醒总开关；[daysBefore] 提前天数。
  static Future<void> syncPetReminders(
    Pet pet,
    List<HealthRecord> records, {
    required bool enabled,
    required int daysBefore,
  }) async {
    await initialize();
    if (!enabled || pet.isDeleted) {
      await cancelPet(pet.id);
      return;
    }
    if (!await isPermissionGranted()) return;

    for (final type in [
      HealthRecordType.vaccine,
      HealthRecordType.dewormIn,
      HealthRecordType.dewormOut,
    ]) {
      final due = HealthCalculator.nextDue(records, type);
      if (due == null) {
        await _plugin.cancel(_notifyId(pet.id, type.name));
        continue;
      }
      await _schedule(
        _notifyId(pet.id, type.name),
        '${pet.name}的${type.label}快到期了',
        '${_notifyDayLabel(due)} 到期，记得安排～',
        due,
        daysBefore,
        'health_due',
        '健康到期提醒',
      );
    }

    // 称重 / 体型评估：距上次测量满 7 天当天提醒（不用提前天数）。
    for (final type in [HealthRecordType.weight, HealthRecordType.bcs]) {
      final due = HealthCalculator.nextDue(records, type);
      if (due == null) {
        await _plugin.cancel(_notifyId(pet.id, type.name));
        continue;
      }
      await _schedule(
        _notifyId(pet.id, type.name),
        '${pet.name}该${type == HealthRecordType.weight ? "称重" : "做体型评估"}了',
        '距上次测量已 7 天，保持每周记录一次的节奏',
        due,
        0,
        'health_due',
        '健康到期提醒',
      );
    }

    final birthday = HealthCalculator.nextBirthday(pet.birthday);
    if (birthday == null) {
      await _plugin.cancel(_notifyId(pet.id, 'birthday'));
    } else {
      await _schedule(
        _notifyId(pet.id, 'birthday'),
        '今天是${pet.name}的生日 🎂',
        '祝它生日快乐，别忘了拍张照片记录一下！',
        birthday,
        0, // 生日当天提醒。
        'birthday',
        '纪念提醒',
      );
    }

    // 到家纪念日。
    final adoption = pet.adoptionDate;
    if (adoption == null || adoption.year >= DateTime.now().year) {
      await _plugin.cancel(_notifyId(pet.id, 'adoption'));
    } else {
      final next = HealthCalculator.nextAnnual(adoption);
      if (next == null) {
        await _plugin.cancel(_notifyId(pet.id, 'adoption'));
        return;
      }
      await _schedule(
        _notifyId(pet.id, 'adoption'),
        '今天是${pet.name}到家的日子 🏠',
        '又一年啦，感谢彼此的陪伴～',
        next,
        0,
        'birthday',
        '纪念提醒',
      );
    }
  }

  /// 取消某宠物的全部提醒（删除宠物/关闭开关时）。
  static Future<void> cancelPet(String petId) async {
    await initialize();
    for (final kind in [
      HealthRecordType.vaccine.name,
      HealthRecordType.dewormIn.name,
      HealthRecordType.dewormOut.name,
      HealthRecordType.weight.name,
      HealthRecordType.bcs.name,
      'birthday',
      'adoption',
    ]) {
      await _plugin.cancel(_notifyId(petId, kind));
    }
  }

  static Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }
}

/// 通知文案里的日期（M月d日）。
String _notifyDayLabel(DateTime d) => '${d.month}月${d.day}日';
