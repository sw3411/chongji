/// 全局受控枚举：带中文 label，DB 存 .name，解析失败兜底默认值。
enum PetSpecies {
  dog('狗'),
  cat('猫'),
  other('其他');

  const PetSpecies(this.label);
  final String label;

  static PetSpecies fromName(String? name) => PetSpecies.values
      .firstWhere((e) => e.name == name, orElse: () => PetSpecies.dog);
}

enum PetGender {
  male('男孩'),
  female('女孩'),
  unknown('不填');

  const PetGender(this.label);
  final String label;

  static PetGender fromName(String? name) => PetGender.values
      .firstWhere((e) => e.name == name, orElse: () => PetGender.unknown);
}

/// 健康记录类型。
enum HealthRecordType {
  weight('体重', 'scale'),
  bcs('体型评分', 'accessibility_new'),
  vaccine('疫苗', 'vaccines'),
  dewormIn('体内驱虫', 'medication_liquid'),
  dewormOut('体外驱虫', 'shower'),
  vetVisit('就诊', 'local_hospital'),
  medication('用药', 'medication'),
  surgery('手术', 'healing'),
  symptom('症状', 'sick'),
  other('其他', 'notes');

  const HealthRecordType(this.label, this.icon);
  final String label;
  final String icon;

  /// 该类型支持周期（疫苗/驱虫）：记录时可填周期天数，自动算下次时间。
  bool get supportsCycle =>
      this == vaccine || this == dewormIn || this == dewormOut;

  /// 该类型带数值（体重 kg / BCS 分）。
  bool get hasValue => this == weight || this == bcs;

  static HealthRecordType fromName(String? name) => HealthRecordType.values
      .firstWhere((e) => e.name == name, orElse: () => HealthRecordType.other);
}

/// 时刻类型。
enum MomentType {
  birthday('生日', 'cake'),
  outing('游玩', 'park'),
  grooming('美容', 'content_cut'),
  adoption('到家纪念日', 'home'),
  anniversary('纪念日', 'favorite'),
  custom('日常', 'pets');

  const MomentType(this.label, this.icon);
  final String label;
  final String icon;

  static MomentType fromName(String? name) => MomentType.values
      .firstWhere((e) => e.name == name, orElse: () => MomentType.custom);
}

/// 消费分类。
enum ExpenseCategory {
  food('主粮', 'rice_bowl'),
  treats('零食', 'cookie'),
  medical('医疗', 'local_hospital'),
  grooming('美容洗护', 'content_cut'),
  toys('玩具', 'toys'),
  supplies('用品', 'shopping_bag'),
  insurance('保险', 'shield'),
  other('其他', 'more_horiz');

  const ExpenseCategory(this.label, this.icon);
  final String label;
  final String icon;

  static ExpenseCategory fromName(String? name) =>
      ExpenseCategory.values
          .firstWhere((e) => e.name == name, orElse: () => ExpenseCategory.other);
}

/// 主食类型。
enum FoodType {
  kibble('干粮/狗粮猫粮'),
  fresh('鲜食/自制'),
  mixed('混搭');

  const FoodType(this.label);
  final String label;

  static FoodType fromName(String? name) =>
      FoodType.values.firstWhere((e) => e.name == name, orElse: () => FoodType.mixed);
}

/// 计划来源。
enum PlanSource {
  ai('AI 生成'),
  manual('手动');

  const PlanSource(this.label);
  final String label;

  static PlanSource fromName(String? name) =>
      PlanSource.values.firstWhere((e) => e.name == name, orElse: () => PlanSource.manual);
}
