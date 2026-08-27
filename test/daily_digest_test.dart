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
  String petId = 'p1',
}) =>
    HealthRecord(
      id: '${type.name}-${date.toIso8601String()}',
      petId: petId,
      type: type,
      date: date,
      value: value,
      cycleDays: cycleDays,
      createdAt: date,
      updatedAt: date,
    );

Pet pet({String id = 'p1', String name = '豆豆', DateTime? birthday}) => Pet(
      id: id,
      name: name,
      species: PetSpecies.dog,
      birthday: birthday,
      neutered: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  final now = DateTime(2026, 8, 27, 12);

  test('临近到期（2 天后）→ 还有2天', () {
    final (title, body) = dailyDigestText({
      pet(): [
        rec(HealthRecordType.dewormIn, DateTime(2026, 7, 1), cycleDays: 59),
      ],
    }, now: now);
    expect(title, contains('1 项'));
    expect(body, contains('豆豆·体内驱虫 还有2天'));
  });

  test('已过期措辞', () {
    final (title, body) = dailyDigestText({
      pet(): [
        rec(HealthRecordType.vaccine, DateTime(2026, 5, 1), cycleDays: 90),
      ],
    }, now: now);
    expect(body, contains('豆豆·疫苗 已过期'));
  });

  test('窗口外（>7 天）不出现在摘要里', () {
    final (title, body) = dailyDigestText({
      pet(): [
        rec(HealthRecordType.dewormOut, DateTime(2026, 8, 20), cycleDays: 90),
      ],
    }, now: now);
    expect(title, '宠迹 · 今日提醒');
    expect(body, contains('一切都在计划中'));
  });

  test('多宠多项：按剩余天数排序、超 4 项折算为共 N 项', () {
    // 到期日：p1 体内驱虫 8/30（3天）、疫苗 9/3（7天）、体外驱虫 9/1（5天）；
    // p2 疫苗 8/28（1天）、体内驱虫 7/30（已过期）→ 共 5 项在窗口内。
    final (title, body) = dailyDigestText({
      pet(id: 'p1', name: '豆豆'): [
        rec(HealthRecordType.dewormIn, DateTime(2026, 6, 2), cycleDays: 89),
        rec(HealthRecordType.vaccine, DateTime(2026, 6, 5), cycleDays: 90),
        rec(HealthRecordType.dewormOut, DateTime(2026, 6, 3), cycleDays: 90),
      ],
      pet(id: 'p2', name: '奶茶'): [
        rec(HealthRecordType.vaccine, DateTime(2026, 5, 30), cycleDays: 90,
            petId: 'p2'),
        rec(HealthRecordType.dewormIn, DateTime(2026, 5, 1), cycleDays: 90,
            petId: 'p2'),
      ],
    }, now: now);
    expect(title, contains('5 项'));
    expect(body, contains('共5项'));
    // 最早到期的（5月1日的体外/体内）排最前。
    expect(body.indexOf('已过期'), lessThan(body.indexOf('还有')));
  });
}
