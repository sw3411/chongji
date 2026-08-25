import 'dart:convert';

import '../../domain/models/diet_profile.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/health_record.dart';
import '../../domain/models/meal_plan.dart';
import '../../domain/models/pet.dart';
import '../../domain/models/enums.dart';
import '../../domain/services/diet_calculator.dart';
import '../../domain/services/health_calculator.dart';
import '../../domain/services/statistics_service.dart';
import '../constants/bcs.dart' show bcsBand;
import '../utils/formatters.dart';
import '../utils/money.dart';
import 'ai_client.dart';
import 'ai_prompts.dart';

/// 对话回复：回答与思考分离（思考默认折叠展示）。
class AiReply {
  const AiReply({required this.answer, this.thinking = ''});

  final String answer;
  final String thinking;
}

/// 一次会话预加载的全部本地数据（个人 App 数据量小，整体载入内存即可）。
class PetDataPort {
  PetDataPort({
    required this.pets,
    required this.recordsByPet,
    required this.expenses,
    required this.profilesByPet,
    required this.plansByPet,
    this.now,
  });

  final List<Pet> pets;
  final Map<String, List<HealthRecord>> recordsByPet;
  final List<Expense> expenses;
  final Map<String, DietProfile> profilesByPet;
  final Map<String, List<MealPlan>> plansByPet;
  final DateTime? now;

  DateTime get n => now ?? DateTime.now();

  List<HealthRecord> recordsOf(Pet pet) => recordsByPet[pet.id] ?? const [];
}

/// AI 业务编排：饮食计划生成 / 一句话解析 / 周报 / 对话。
class AiService {
  AiService(this._client);

  final AiClient _client;

  // ---------- JSON 容错提取（wuji 验证过的三段式） ----------

  static Map<String, dynamic>? extractJson(String raw) {
    var text = raw.trim();
    // 1) 剥 markdown 代码块。
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final m = fence.firstMatch(text);
    if (m != null) text = m.group(1)!.trim();
    // 2) 直接解析。
    try {
      final v = jsonDecode(text);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    // 3) 首尾大括号截取重试。
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final v = jsonDecode(text.substring(start, end + 1));
        if (v is Map<String, dynamic>) return v;
      } catch (_) {}
    }
    return null;
  }

  static String _str(Map<String, dynamic> json, String key) =>
      json[key]?.toString() ?? '';

  static double? _num(Map<String, dynamic> json, String key) =>
      json[key] == null ? null : double.tryParse(json[key].toString());

  static int? _int(Map<String, dynamic> json, String key) =>
      json[key] == null ? null : int.tryParse(json[key].toString());

  static List<String> _strList(dynamic v) => (v as List<dynamic>? ?? const [])
      .map((e) => e.toString())
      .where((s) => s.trim().isNotEmpty)
      .toList();

  // ---------- 饮食计划 ----------

  /// 组装宠物数据集（纯函数，供测试与 Prompt 复用）。
  static String buildDietDataset(
    Pet pet,
    List<HealthRecord> records,
    DietProfile? profile, {
    double? breedTypicalKg,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final latestWeight = HealthCalculator.latestWeight(records);
    final latestBcs = HealthCalculator.latestBcs(records);
    final estimate = DietCalculator.dailyKcal(pet, records,
        breedTypicalKg: breedTypicalKg);
    final buffer = StringBuffer()
      ..writeln('【宠物档案】')
      ..writeln('名字：${pet.name}')
      ..writeln('物种：${pet.species.label}')
      ..writeln('品种：${pet.breedLabel}')
      ..writeln('生日：${pet.birthday == null ? "未填" : Fmt.date(pet.birthday!)}（${HealthCalculator.ageText(pet.birthday, now: n)}，${HealthCalculator.lifeStage(pet.birthday, pet.species, now: n)}）')
      ..writeln('性别：${pet.gender.label}；绝育：${pet.neutered ? "是" : "否"}')
      ..writeln('当前体重：${latestWeight == null ? "未记录" : "${latestWeight.value}kg（${Fmt.date(latestWeight.date)}）"}')
      ..writeln('体型评分BCS：${latestBcs == null ? "未记录" : "${latestBcs.value!.toInt()}/9"}')
      ..writeln('本地热量估算：${estimate == null ? "无法估算" : "${estimate.round()} kcal/天（RER×系数，仅供参考）"}');
    buffer.writeln('【饮食偏好】');
    if (profile == null) {
      buffer.writeln('未填写（默认混搭、每天2餐、无已知过敏）');
    } else {
      buffer
        ..writeln('主食类型：${profile.foodType.label}')
        ..writeln('常用品牌：${profile.brand ?? "未填"}')
        ..writeln('每天餐数：${profile.mealsPerDay}')
        ..writeln('爱吃的：${profile.likes.isEmpty ? "未填" : profile.likes.join("、")}')
        ..writeln('不爱吃的：${profile.dislikes.isEmpty ? "未填" : profile.dislikes.join("、")}')
        ..writeln('过敏源：${profile.allergens.isEmpty ? "无已知过敏" : profile.allergens.join("、")}（必须避开）')
        ..writeln('其他说明：${profile.notes ?? "无"}');
    }
    return buffer.toString();
  }

  /// 生成某天的喂食计划（已解析成 MealPlan，解析失败抛 AiException）。
  Future<MealPlan> generateDietPlan(
    Pet pet,
    List<HealthRecord> records,
    DietProfile? profile, {
    double? breedTypicalKg,
    DateTime? forDate,
    DateTime? now,
  }) async {
    final n = now ?? DateTime.now();
    final date = forDate ?? n.add(const Duration(days: 1));
    final dataset = buildDietDataset(pet, records, profile,
        breedTypicalKg: breedTypicalKg, now: n);
    final extra = '\n计划日期：${Fmt.date(date)}';
    final raw = await _client.ask(AiPrompts.dietPlanSystem(n),
        '${AiPrompts.dietPlanUser(dataset)}$extra',
        jsonMode: true);
    final json = extractJson(raw);
    if (json == null) {
      throw AiException('AI 返回的内容无法解析为喂食计划，请重试或换个模型');
    }
    final meals = (json['meals'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((m) => PlanMeal(
              time: _str(m, 'time'),
              name: _str(m, 'name'),
              type: _str(m, 'type'),
              grams: _num(m, 'grams'),
              kcal: _num(m, 'kcal'),
              items: _strList(m['items']),
              ingredients: _strList(m['ingredients']),
              steps: _strList(m['steps']),
            ))
        .toList();
    if (meals.isEmpty) {
      throw AiException('AI 生成的计划缺少每餐明细，请重试');
    }
    meals.sort((a, b) => a.time.compareTo(b.time));
    return MealPlan(
      id: '',
      petId: pet.id,
      date: DateTime(date.year, date.month, date.day),
      source: PlanSource.ai,
      totalKcal: _num(json, 'totalKcal'),
      waterMl: _num(json, 'waterMl'),
      meals: meals,
      advice: _str(json, 'advice'),
      warnings: _strList(json['warnings']),
      createdAt: n,
    );
  }

  // ---------- 批量饮食计划（一周 / 月度周循环模板） ----------

  /// 一次调用生成 [days] 天的计划（从 startDate 起）。
  /// [repeatWeekly] 为月度模式：生成的模板按星期几循环执行。
  Future<List<MealPlan>> generateDietPlanBatch(
    Pet pet,
    List<HealthRecord> records,
    DietProfile? profile, {
    required DateTime startDate,
    required int days,
    bool repeatWeekly = false,
    double? breedTypicalKg,
    DateTime? now,
  }) async {
    final n = now ?? DateTime.now();
    final dataset = buildDietDataset(pet, records, profile,
        breedTypicalKg: breedTypicalKg, now: n);
    final raw = await _client.ask(
      AiPrompts.dietPlanBatchSystem(n, days, repeatWeekly),
      AiPrompts.dietPlanBatchUser(dataset, startDate),
      jsonMode: true,
    );
    final json = extractJson(raw);
    if (json == null) {
      throw AiException('AI 返回的内容无法解析为喂食计划，请重试或换个模型');
    }
    final overallAdvice = _str(json, 'advice');
    final overallWarnings = _strList(json['warnings']);
    final dayList = (json['days'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final plans = <MealPlan>[];
    for (final day in dayList) {
      final date = DateTime.tryParse(_str(day, 'date'));
      final meals = (day['meals'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((m) => PlanMeal(
                time: _str(m, 'time'),
                name: _str(m, 'name'),
                type: _str(m, 'type'),
                grams: _num(m, 'grams'),
                kcal: _num(m, 'kcal'),
                items: _strList(m['items']),
                ingredients: _strList(m['ingredients']),
                steps: _strList(m['steps']),
              ))
          .toList();
      if (date == null || meals.isEmpty) continue;
      meals.sort((a, b) => a.time.compareTo(b.time));
      final advice = [
        if (_str(day, 'advice').isNotEmpty) _str(day, 'advice'),
        if (overallAdvice.isNotEmpty) overallAdvice,
      ].join('\n\n');
      plans.add(MealPlan(
        id: '',
        petId: pet.id,
        date: DateTime(date.year, date.month, date.day),
        source: PlanSource.ai,
        totalKcal: _num(day, 'totalKcal'),
        waterMl: _num(day, 'waterMl'),
        meals: meals,
        advice: advice,
        warnings: [..._strList(day['warnings']), ...overallWarnings],
        repeatWeekly: repeatWeekly,
        createdAt: n,
      ));
    }
    if (plans.isEmpty) {
      throw AiException('AI 生成的计划缺少每日明细，请重试');
    }
    plans.sort((a, b) => a.date.compareTo(b.date));
    return plans;
  }

  // ---------- 首页综合洞察 ----------

  /// 组装首页洞察数据集（纯函数）：到期项 + 体重体型 + 近 14 天健康事件。
  static String buildInsightDataset(
    Pet pet,
    List<HealthRecord> records,
    List<DueItem> dues, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final buffer = StringBuffer()
      ..writeln('宠物：${pet.name}（${pet.species.label}·${pet.breedLabel}·${HealthCalculator.ageText(pet.birthday, now: n)}）');

    if (dues.isNotEmpty) {
      buffer.writeln('近期到期：');
      for (final d in dues.take(5)) {
        buffer.writeln('- ${d.title}：${d.daysLeft < 0 ? "已过${-d.daysLeft}天" : d.daysLeft == 0 ? "就是今天" : "${d.daysLeft}天后"}');
      }
    }

    final weight = HealthCalculator.latestWeight(records);
    final change = HealthCalculator.weightChange(records, 30, now: n);
    buffer.writeln('体重：${weight?.value ?? "未记录"}kg'
        '${change == null ? "" : "（30天${change.$1 >= 0 ? "+" : ""}${change.$1.toStringAsFixed(2)}kg，${change.$2.toStringAsFixed(1)}%）"}');
    final bcs = HealthCalculator.latestBcs(records);
    if (bcs != null) {
      buffer.writeln('体型BCS：${bcs.value!.toInt()}/9（${bcsBand(bcs.value!.toInt())}）');
    }

    final since = n.subtract(const Duration(days: 14));
    final recent = records.where((r) => r.date.isAfter(since)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (recent.isNotEmpty) {
      buffer.writeln('近14天健康事件：');
      for (final r in recent.take(8)) {
        buffer.writeln(
            '- ${Fmt.date(r.date)} ${r.type.label}：${[if (r.value != null) (r.type == HealthRecordType.weight ? "${r.value}kg" : "${r.value!.toInt()}分"), if (r.textValue != null && r.textValue!.isNotEmpty) r.textValue, if (r.diagnosis != null && r.diagnosis!.isNotEmpty) r.diagnosis, if (r.notes != null && r.notes!.isNotEmpty) r.notes].join("，")}');
      }
    }
    return buffer.toString();
  }
  /// 生成首页综合判断（Markdown 文本）。
  Future<String> homeInsight(
    Pet pet,
    List<HealthRecord> records,
    List<DueItem> dues, {
    DateTime? now,
  }) async {
    final n = now ?? DateTime.now();
    final dataset = buildInsightDataset(pet, records, dues, now: n);
    return _client
        .ask(AiPrompts.insightSystem(n), AiPrompts.insightUser(dataset))
        .then((s) => s.trim());
  }

  // ---------- 一句话快速记录 ----------

  /// 解析结果草稿（UI 预填表单，确认后入库）。
  static QuickAddDraft parseQuickAddDraft(String raw) {
    final json = extractJson(raw);
    if (json == null) throw AiException('AI 返回的内容无法解析，请换个说法再试');
    final kindStr = _str(json, 'kind');
    final kind = switch (kindStr) {
      'expense' => QuickAddKind.expense,
      'moment' => QuickAddKind.moment,
      _ => QuickAddKind.health,
    };
    return QuickAddDraft(
      kind: kind,
      petName: _str(json, 'petName'),
      date: DateTime.tryParse(_str(json, 'date')) ?? DateTime.now(),
      title: _str(json, 'title'),
      healthType: HealthRecordType.fromName(_str(json, 'healthType')),
      value: _num(json, 'value'),
      textValue: _str(json, 'textValue'),
      cycleDays: _int(json, 'cycleDays'),
      expenseCategory: ExpenseCategory.fromName(_str(json, 'expenseCategory')),
      amountYuan: _num(json, 'amountYuan'),
      momentType: MomentType.fromName(_str(json, 'momentType')),
      location: _str(json, 'location'),
      notes: _str(json, 'notes'),
    );
  }

  Future<QuickAddDraft> quickAdd(String input, List<String> petNames,
      {DateTime? now}) async {
    final n = now ?? DateTime.now();
    final raw = await _client.ask(
        AiPrompts.quickAddSystem(petNames, n), input,
        jsonMode: true);
    return parseQuickAddDraft(raw);
  }

  // ---------- 健康周报 ----------

  /// 周报数据集（纯函数）。
  static String buildWeeklyDataset(
    Pet pet,
    List<HealthRecord> records,
    List<Expense> expenses,
    MealPlan? latestPlan, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final since = n.subtract(const Duration(days: 7));
    final week = records.where((r) => r.date.isAfter(since)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final weekExpenses =
        expenses.where((e) => e.date.isAfter(since)).toList();

    final buffer = StringBuffer()
      ..writeln('宠物：${pet.name}（${pet.species.label}·${pet.breedLabel}·${HealthCalculator.ageText(pet.birthday, now: n)}）')
      ..writeln('统计区间：${Fmt.date(since)} 至 ${Fmt.date(n)}')
      ..writeln()
      ..writeln('本周健康记录（${week.length} 条）：');
    if (week.isEmpty) {
      buffer.writeln('无');
    } else {
      for (final r in week) {
        buffer.writeln(
            '- ${Fmt.date(r.date)} ${r.type.label}：${r.value ?? ""}${r.type == HealthRecordType.weight ? "kg" : ""} ${r.textValue ?? ""} ${r.diagnosis ?? ""} ${r.notes ?? ""}'
                .trim());
      }
    }
    final weightChange = HealthCalculator.weightChange(records, 30, now: n);
    buffer
      ..writeln()
      ..writeln('体重：${HealthCalculator.latestWeight(records)?.value ?? "未记录"}kg'
          '${weightChange == null ? "" : "（近30天 ${weightChange.$1 >= 0 ? "+" : ""}${weightChange.$1.toStringAsFixed(2)}kg）"}')
      ..writeln('体型BCS：${HealthCalculator.latestBcs(records)?.value?.toInt() ?? "未记录"}/9')
      ..writeln()
      ..writeln('本周消费：${Money.format(weekExpenses.fold(0, (s, e) => s + e.amount))}（${weekExpenses.length} 笔）');
    for (final e in weekExpenses) {
      buffer.writeln('- ${Fmt.date(e.date)} ${e.category.label} ${e.title} ${Money.format(e.amount)}');
    }
    buffer
      ..writeln()
      ..writeln('最近喂食计划：${latestPlan == null ? "无" : "${Fmt.date(latestPlan.date)}，总热量${latestPlan.totalKcal?.round() ?? "?"}kcal，${latestPlan.meals.length}餐"}');
    return buffer.toString();
  }

  Future<String> weeklyReport(
    Pet pet,
    List<HealthRecord> records,
    List<Expense> expenses,
    MealPlan? latestPlan, {
    DateTime? now,
  }) async {
    final n = now ?? DateTime.now();
    final dataset =
        buildWeeklyDataset(pet, records, expenses, latestPlan, now: n);
    return _client
        .ask(AiPrompts.weeklyReportSystem(n), AiPrompts.weeklyReportUser(dataset))
        .then((s) => s.trim());
  }

  // ---------- 对话助手 ----------

  /// 宠物概况摘要（system prompt 注入）。
  static String buildPetSummary(PetDataPort port, Pet pet) {
    final records = port.recordsOf(pet);
    final weight = HealthCalculator.latestWeight(records);
    final bcs = HealthCalculator.latestBcs(records);
    return '${pet.name}，${pet.species.label}（${pet.breedLabel}），'
        '${HealthCalculator.ageText(pet.birthday, now: port.n)}，'
        '${pet.gender.label}${pet.neutered ? "·已绝育" : ""}，'
        '体重${weight?.value ?? "?"}kg，BCS ${bcs?.value?.toInt() ?? "?"}/9。';
  }

  /// 工具执行器：在预载数据上本地查询。
  static String executeTool(PetDataPort port, Pet pet, String name,
      Map<String, dynamic> args) {
    final records = port.recordsOf(pet);
    switch (name) {
      case 'get_health_records':
        final typeStr = args['type'] as String?;
        final limit = (args['limit'] as num?)?.toInt() ?? 20;
        var list = records.where((r) => !r.date.isAfter(port.n)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        if (typeStr != null && typeStr.isNotEmpty) {
          final t = HealthRecordType.fromName(typeStr);
          list = list.where((r) => r.type == t).toList();
        }
        if (list.isEmpty) return '没有匹配的健康记录';
        return list.take(limit).map((r) => <String>[
              Fmt.date(r.date),
              r.type.label,
              if (r.value != null)
                '${r.value}${r.type == HealthRecordType.weight ? "kg" : "分"}',
              if (r.textValue != null && r.textValue!.isNotEmpty) r.textValue!,
              if (r.diagnosis != null && r.diagnosis!.isNotEmpty)
                '诊断:${r.diagnosis}',
              if (r.cycleDays != null) '周期${r.cycleDays}天',
              if (r.notes != null && r.notes!.isNotEmpty) r.notes!,
            ].join(' ')).join('\n');
      case 'get_weight_trend':
        final months = (args['months'] as num?)?.toInt() ?? 6;
        final since = port.n.subtract(Duration(days: 30 * months));
        final weights = records
            .where((r) =>
                r.type == HealthRecordType.weight &&
                r.value != null &&
                r.date.isAfter(since))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        if (weights.isEmpty) return '该时段没有体重记录';
        final change = HealthCalculator.weightChange(records, 30, now: port.n);
        final lines =
            weights.map((r) => '${Fmt.date(r.date)} ${r.value}kg').join('\n');
        final trend = change == null
            ? ''
            : '\n近30天变化：${change.$1 >= 0 ? "+" : ""}${change.$1.toStringAsFixed(2)}kg（${change.$2.toStringAsFixed(1)}%）';
        return '$lines$trend';
      case 'get_expense_summary':
        final months = (args['months'] as num?)?.toInt() ?? 3;
        final trend = StatisticsService.monthlyTrend(port.expenses,
            months: months, now: port.n);
        final lines = trend
            .map((m) => '${m.label}：${Money.format(m.total)}')
            .join('\n');
        final slices =
            StatisticsService.byCategory(port.expenses);
        final cat = slices
            .take(5)
            .map((s) => '${s.category.label} ${Money.format(s.total)}(${s.pct.toStringAsFixed(0)}%)')
            .join('，');
        return '$lines\n分类占比：$cat';
      case 'get_diet_info':
        final profile = port.profilesByPet[pet.id];
        final plans = port.plansByPet[pet.id] ?? const <MealPlan>[];
        final latest = plans.isEmpty ? null : plans.first;
        final profileText = profile == null
            ? '未填写饮食偏好'
            : '${profile.foodType.label}，每天${profile.mealsPerDay}餐'
                '${profile.brand == null ? "" : "，品牌${profile.brand}"}'
                '${profile.allergens.isEmpty ? "" : "，过敏:${profile.allergens.join("、")}"}'
                '${profile.likes.isEmpty ? "" : "，爱吃:${profile.likes.join("、")}"}'
                '${profile.dislikes.isEmpty ? "" : "，不爱吃:${profile.dislikes.join("、")}"}';
        final planText = latest == null
            ? '暂无喂食计划'
            : '最近计划 ${Fmt.date(latest.date)}：总热量${latest.totalKcal?.round() ?? "?"}kcal，'
                '${latest.meals.map((m) => "${m.time} ${m.name}${m.grams == null ? "" : " ${m.grams}g"}").join("；")}';
        return '$profileText\n$planText';
      default:
        return '未知工具：$name';
    }
  }

  /// 对话（带历史）：AI 主动调用工具读取本地数据后综合回答；
  /// 服务商不支持 tools（400）时，降级为"上下文注入 + 流式"。
  /// 回调：[onToolCall] 展示查询进度；[onThinkingDelta]/[onAnswerDelta]
  /// 用于流式降级时的分区打字效果。
  Future<AiReply> chat(
    PetDataPort port,
    Pet pet,
    List<AiMessage> history, {
    void Function(String toolName)? onToolCall,
    void Function(String delta)? onThinkingDelta,
    void Function(String delta)? onAnswerDelta,
  }) async {
    final system = AiMessage(
        'system', AiPrompts.chatSystem(port.n, buildPetSummary(port, pet)));
    try {
      final r = await _client.chatWithTools(
        [system, ...history],
        AiPrompts.chatTools(),
        (name, args) async => executeTool(port, pet, name, args),
        onToolCall: onToolCall,
      );
      if (r.reasoning.isNotEmpty) onThinkingDelta?.call(r.reasoning);
      if (r.content.isNotEmpty) onAnswerDelta?.call(r.content);
      return AiReply(answer: r.content, thinking: r.reasoning);
    } on AiExceptionWithStatus catch (e) {
      if (e.statusCode != 400) rethrow;
    }
    // 降级：一次性注入常用数据 + 流式输出（思考/回答分区）。
    final fallbackData = [
      '【健康记录】',
      executeTool(port, pet, 'get_health_records', const {}),
      '【体重趋势】',
      executeTool(port, pet, 'get_weight_trend', const {}),
      '【消费统计】',
      executeTool(port, pet, 'get_expense_summary', const {'months': 3}),
      '【饮食】',
      executeTool(port, pet, 'get_diet_info', const {}),
    ].join('\n');
    final thinking = StringBuffer();
    final answer = StringBuffer();
    await _client.chatStream([
      system,
      AiMessage('system', '以下是查询到的本地数据：'),
      AiMessage('system', fallbackData),
      ...history,
    ], onDelta: (delta, {isReasoning = false}) {
      if (isReasoning) {
        thinking.write(delta);
        onThinkingDelta?.call(delta);
      } else {
        answer.write(delta);
        onAnswerDelta?.call(delta);
      }
    });
    return AiReply(answer: answer.toString(), thinking: thinking.toString());
  }

}

enum QuickAddKind { health, expense, moment }

/// 一句话解析出的记录草稿。
class QuickAddDraft {
  QuickAddDraft({
    required this.kind,
    required this.petName,
    required this.date,
    required this.title,
    required this.healthType,
    this.value,
    this.textValue = '',
    this.cycleDays,
    required this.expenseCategory,
    this.amountYuan,
    required this.momentType,
    this.location = '',
    this.notes = '',
  });

  final QuickAddKind kind;
  final String petName;
  final DateTime date;
  final String title;
  final HealthRecordType healthType;
  final double? value;
  final String textValue;
  final int? cycleDays;
  final ExpenseCategory expenseCategory;
  final double? amountYuan;
  final MomentType momentType;
  final String location;
  final String notes;
}
