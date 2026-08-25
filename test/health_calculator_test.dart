import 'package:flutter_test/flutter_test.dart';
import 'package:chongji/domain/models/enums.dart';
import 'package:chongji/domain/models/health_record.dart';
import 'package:chongji/domain/models/pet.dart';
import 'package:chongji/domain/services/health_calculator.dart';

HealthRecord rec(
  HealthRecordType type,
  DateTime date, {
  double? value,
  int? cycleDays,
}) =>
    HealthRecord(
      id: '${type.name}-${date.toIso8601String()}',
      petId: 'p1',
      type: type,
      date: date,
      value: value,
      cycleDays: cycleDays,
      createdAt: date,
      updatedAt: date,
    );

Pet pet({DateTime? birthday, PetSpecies species = PetSpecies.dog}) => Pet(
      id: 'p1',
      name: '豆豆',
      species: species,
      birthday: birthday,
      neutered: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  final now = DateTime(2026, 8, 25);

  group('ageInMonths / ageText', () {
    test('不足月', () {
      expect(HealthCalculator.ageInMonths(DateTime(2026, 8, 10), now: now), 0);
      expect(HealthCalculator.ageText(DateTime(2026, 8, 10), now: now), '未满月');
    });

    test('月龄', () {
      expect(
          HealthCalculator.ageText(DateTime(2026, 3, 1), now: now), '5个月');
    });

    test('岁+月', () {
      expect(HealthCalculator.ageText(DateTime(2024, 6, 1), now: now), '2岁2个月');
    });

    test('整岁', () {
      expect(HealthCalculator.ageText(DateTime(2024, 8, 25), now: now), '2岁');
    });

    test('生日未填', () {
      expect(HealthCalculator.ageText(null, now: now), '年龄未填');
    });
  });

  group('lifeStage', () {
    test('幼年 / 成年 / 老年', () {
      expect(HealthCalculator.lifeStage(DateTime(2026, 6, 1), PetSpecies.dog, now: now),
          contains('幼年'));
      expect(HealthCalculator.lifeStage(DateTime(2024, 1, 1), PetSpecies.dog, now: now),
          '成年');
      // 狗 7 岁以上老年。
      expect(HealthCalculator.lifeStage(DateTime(2019, 1, 1), PetSpecies.dog, now: now),
          '老年');
      // 猫 10 岁以上老年。
      expect(HealthCalculator.lifeStage(DateTime(2015, 1, 1), PetSpecies.cat, now: now),
          '老年');
    });
  });

  group('latestWeight / weightChange', () {
    test('取最新一条', () {
      final records = [
        rec(HealthRecordType.weight, DateTime(2026, 7, 1), value: 5.0),
        rec(HealthRecordType.weight, DateTime(2026, 8, 20), value: 5.4),
      ];
      expect(HealthCalculator.latestWeight(records)!.value, 5.4);
    });

    test('30 天变化', () {
      final records = [
        rec(HealthRecordType.weight, DateTime(2026, 7, 1), value: 5.0),
        rec(HealthRecordType.weight, DateTime(2026, 8, 20), value: 5.4),
      ];
      final change = HealthCalculator.weightChange(records, 30, now: now);
      expect(change, isNotNull);
      expect(change!.$1, closeTo(0.4, 0.001));
      expect(change.$2, closeTo(8.0, 0.01));
    });

    test('单条记录无基线', () {
      final records = [
        rec(HealthRecordType.weight, DateTime(2026, 8, 20), value: 5.0),
      ];
      expect(HealthCalculator.weightChange(records, 30, now: now), isNull);
    });
  });

  group('nextDue', () {
    test('记录自带周期', () {
      final records = [
        rec(HealthRecordType.dewormOut, DateTime(2026, 8, 1),
            cycleDays: 30),
      ];
      expect(HealthCalculator.nextDue(records, HealthRecordType.dewormOut, now: now),
          DateTime(2026, 8, 31));
    });

    test('无周期用默认（疫苗 365 天）', () {
      final records = [
        rec(HealthRecordType.vaccine, DateTime(2026, 1, 1)),
      ];
      expect(HealthCalculator.nextDue(records, HealthRecordType.vaccine, now: now),
          DateTime(2027, 1, 1));
    });

    test('多次记录取最近一次', () {
      final records = [
        rec(HealthRecordType.dewormIn, DateTime(2026, 1, 1), cycleDays: 90),
        rec(HealthRecordType.dewormIn, DateTime(2026, 7, 1), cycleDays: 90),
      ];
      expect(HealthCalculator.nextDue(records, HealthRecordType.dewormIn, now: now),
          DateTime(2026, 9, 29));
    });

    test('无记录返回 null', () {
      expect(
          HealthCalculator.nextDue([], HealthRecordType.vaccine, now: now),
          isNull);
    });
  });

  group('nextBirthday', () {
    test('今年未过取今年', () {
      expect(HealthCalculator.nextBirthday(DateTime(2020, 12, 1), now: now),
          DateTime(2026, 12, 1));
    });

    test('今年已过取明年', () {
      expect(HealthCalculator.nextBirthday(DateTime(2020, 1, 15), now: now),
          DateTime(2027, 1, 15));
    });

    test('今天是生日仍返回今天', () {
      expect(HealthCalculator.nextBirthday(DateTime(2020, 8, 25), now: now),
          DateTime(2026, 8, 25));
    });
  });

  group('buildDueItems', () {
    test('过期驱虫 + 未来生日排序', () {
      final p = pet(birthday: DateTime(2020, 9, 10));
      final records = [
        rec(HealthRecordType.dewormOut, DateTime(2026, 6, 1), cycleDays: 30),
        // 已过期 50+ 天，超过 -30 窗口不显示。
      ];
      final items = buildDueItems(p, records, now: now);
      // 驱虫 7/1 到期，已过 55 天 → 超出 -30 窗口不显示；只显示生日。
      expect(items.length, 1);
      expect(items.first.kind, 'birthday');
      expect(items.first.daysLeft, 16);
    });

    test('称重/体型 7 天测量提醒：到期前 3 天进入列表', () {
      final p = pet(birthday: DateTime(2020, 9, 10));
      final records = [
        rec(HealthRecordType.weight, DateTime(2026, 8, 20), value: 5.0),
        rec(HealthRecordType.bcs, DateTime(2026, 8, 1), value: 5),
      ];
      final items = buildDueItems(p, records, now: now);
      // 体重 8/27 到期（还有 2 天 ≤3）→ 显示；体型 8/8 已过 17 天 → 显示过期。
      final weightItem = items.where((i) => i.kind == 'weight').single;
      expect(weightItem.daysLeft, 2);
      expect(weightItem.title, '称重测量');
      final bcsItem = items.where((i) => i.kind == 'bcs').single;
      expect(bcsItem.daysLeft, -17);
      // 3 天窗口外的不显示：4 天后到期 → 无。
      final records2 = [
        rec(HealthRecordType.weight, DateTime(2026, 8, 22), value: 5.0),
      ];
      final items2 = buildDueItems(p, records2, now: now);
      expect(items2.where((i) => i.kind == 'weight').isEmpty, isTrue);
    });
  });
}
