import 'package:flutter_test/flutter_test.dart';
import 'package:chongji/core/ai/ai_client.dart';
import 'package:chongji/core/ai/ai_service.dart';
import 'package:chongji/core/utils/money.dart';
import 'package:chongji/domain/models/enums.dart';

void main() {
  group('AiClient.parseSseLine（思考型模型兼容）', () {
    test('普通增量内容', () {
      final r = AiClient.parseSseLine(
          'data: {"choices":[{"delta":{"content":"你好"}}]}');
      expect(r.content, '你好');
      expect(r.reasoning, '');
    });

    test('思考型模型：reasoning_content 增量', () {
      final r = AiClient.parseSseLine(
          'data: {"choices":[{"delta":{"reasoning_content":"先想想…"}}]}');
      expect(r.content, '');
      expect(r.reasoning, '先想想…');
    });

    test('[DONE] 与无关行返回空', () {
      expect(AiClient.parseSseLine('data: [DONE]').content, '');
      expect(AiClient.parseSseLine('随便一行').reasoning, '');
      expect(AiClient.parseSseLine('').content, '');
    });
  });

  group('AiService.extractJson', () {
    test('裸 JSON', () {
      final j = AiService.extractJson('{"a":1}');
      expect(j, isNotNull);
      expect(j!['a'], 1);
    });

    test('markdown 代码块包裹', () {
      final j = AiService.extractJson('```json\n{"a": 2}\n```');
      expect(j!['a'], 2);
    });

    test('前后有废话文本', () {
      final j = AiService.extractJson('好的，结果如下：{"a": 3} 以上。');
      expect(j!['a'], 3);
    });

    test('完全不是 JSON 返回 null', () {
      expect(AiService.extractJson('今天天气不错'), isNull);
    });
  });

  group('parseQuickAddDraft', () {
    test('完整健康记录', () {
      final draft = AiService.parseQuickAddDraft(
          '{"kind":"health","petName":"豆豆","date":"2026-08-24",'
          '"title":"打狂犬疫苗","healthType":"vaccine","value":null,'
          '"textValue":"狂犬疫苗","cycleDays":365,'
          '"expenseCategory":"other","amountYuan":null,'
          '"momentType":"custom","location":"","notes":"反应正常"}');
      expect(draft.kind, QuickAddKind.health);
      expect(draft.petName, '豆豆');
      expect(draft.date, DateTime(2026, 8, 24));
      expect(draft.healthType, HealthRecordType.vaccine);
      expect(draft.cycleDays, 365);
      expect(draft.notes, '反应正常');
    });

    test('消费记录金额换算', () {
      final draft = AiService.parseQuickAddDraft(
          '{"kind":"expense","petName":"豆豆","date":"2026-08-25",'
          '"title":"狂犬疫苗","healthType":"other","expenseCategory":"medical",'
          '"amountYuan":200.5,"momentType":"custom"}');
      expect(draft.kind, QuickAddKind.expense);
      expect(draft.expenseCategory, ExpenseCategory.medical);
      expect(draft.amountYuan, 200.5);
    });

    test('未知类型兜底', () {
      final draft = AiService.parseQuickAddDraft(
          '{"kind":"moment","momentType":"outing","title":"去公园","date":"2026-08-23"}');
      expect(draft.kind, QuickAddKind.moment);
      expect(draft.momentType, MomentType.outing);
    });

    test('无法解析抛异常', () {
      expect(() => AiService.parseQuickAddDraft('not json at all'),
          throwsA(isA<AiException>()));
    });
  });

  group('Money', () {
    test('format 千分位与小数', () {
      expect(Money.format(123456789), '¥1,234,567.9');
      expect(Money.format(20000), '¥200');
      expect(Money.format(1250), '¥12.5');
      expect(Money.format(-500), '-¥5');
    });

    test('formatCompact 万', () {
      expect(Money.formatCompact(123456789), '¥123.5万');
      expect(Money.formatCompact(12345), '¥123');
    });

    test('parse 往返', () {
      expect(Money.parse('200'), 20000);
      expect(Money.parse('12.5'), 1250);
      expect(Money.parse('1,234.56'), 123456);
      expect(Money.parse('abc'), isNull);
      expect(Money.parse('-3'), isNull);
    });

    test('金额精度：0.1+0.2 问题不存在（int 分）', () {
      final a = Money.parse('0.1')! + Money.parse('0.2')!;
      expect(a, 30);
      expect(Money.format(a), '¥0.3');
    });
  });
}
