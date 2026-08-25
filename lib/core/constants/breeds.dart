import '../../domain/models/enums.dart';

/// 品种信息：典型成年体重区间（kg），供热量估算与 AI 参考。
class BreedInfo {
  const BreedInfo(this.name, this.species, this.minKg, this.maxKg);

  final String name;
  final PetSpecies species;
  final double minKg;
  final double maxKg;

  String get rangeLabel => minKg == maxKg
      ? '${minKg.toStringAsFixed(minKg.truncateToDouble() == minKg ? 0 : 1)}kg'
      : '${_trim(minKg)}~${_trim(maxKg)}kg';

  static String _trim(double v) =>
      v.truncateToDouble() == v ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// 常见犬种（按体型大致排序）。品种库可随时扩充，找不到的可在表单里自定义输入。
const List<BreedInfo> kDogBreeds = [
  BreedInfo('中华田园犬', PetSpecies.dog, 10, 25),
  BreedInfo('金毛寻回犬', PetSpecies.dog, 25, 34),
  BreedInfo('拉布拉多', PetSpecies.dog, 25, 36),
  BreedInfo('阿拉斯加雪橇犬', PetSpecies.dog, 34, 45),
  BreedInfo('哈士奇', PetSpecies.dog, 16, 27),
  BreedInfo('萨摩耶', PetSpecies.dog, 16, 30),
  BreedInfo('边境牧羊犬', PetSpecies.dog, 14, 20),
  BreedInfo('德国牧羊犬', PetSpecies.dog, 22, 40),
  BreedInfo('柴犬', PetSpecies.dog, 8, 11),
  BreedInfo('柯基', PetSpecies.dog, 10, 14),
  BreedInfo('贵宾/泰迪', PetSpecies.dog, 3, 8),
  BreedInfo('巨型贵宾', PetSpecies.dog, 20, 32),
  BreedInfo('玩具贵宾', PetSpecies.dog, 2, 3.5),
  BreedInfo('可卡布犬', PetSpecies.dog, 4, 9),
  BreedInfo('可卡犬', PetSpecies.dog, 12, 15),
  BreedInfo('比熊', PetSpecies.dog, 3, 6),
  BreedInfo('博美', PetSpecies.dog, 1.8, 3.5),
  BreedInfo('雪纳瑞', PetSpecies.dog, 5, 9),
  BreedInfo('迷你雪纳瑞', PetSpecies.dog, 5, 8),
  BreedInfo('巨型雪纳瑞', PetSpecies.dog, 25, 36),
  BreedInfo('约克夏梗', PetSpecies.dog, 2, 3.5),
  BreedInfo('马尔济斯', PetSpecies.dog, 2, 4),
  BreedInfo('法国斗牛犬', PetSpecies.dog, 8, 14),
  BreedInfo('英国斗牛犬', PetSpecies.dog, 18, 25),
  BreedInfo('巴哥犬', PetSpecies.dog, 6, 8),
  BreedInfo('松狮', PetSpecies.dog, 20, 32),
  BreedInfo('沙皮犬', PetSpecies.dog, 18, 25),
  BreedInfo('秋田犬', PetSpecies.dog, 30, 50),
  BreedInfo('杜宾犬', PetSpecies.dog, 30, 40),
  BreedInfo('罗威纳', PetSpecies.dog, 35, 50),
  BreedInfo('喜乐蒂牧羊犬', PetSpecies.dog, 6, 12),
  BreedInfo('苏格兰牧羊犬', PetSpecies.dog, 20, 30),
  BreedInfo('古代英国牧羊犬', PetSpecies.dog, 27, 45),
  BreedInfo('澳洲牧羊犬', PetSpecies.dog, 20, 32),
  BreedInfo('西高地白梗', PetSpecies.dog, 6, 9),
  BreedInfo('贝灵顿梗', PetSpecies.dog, 8, 10),
  BreedInfo('惠比特犬', PetSpecies.dog, 9, 14),
  BreedInfo('万能梗', PetSpecies.dog, 20, 29),
  BreedInfo('边境梗', PetSpecies.dog, 5, 7),
  BreedInfo('吉娃娃', PetSpecies.dog, 1.5, 3),
  BreedInfo('腊肠犬', PetSpecies.dog, 4, 12),
  BreedInfo('斑点狗', PetSpecies.dog, 20, 32),
  BreedInfo('比格犬', PetSpecies.dog, 9, 14),
  BreedInfo('蝴蝶犬', PetSpecies.dog, 4, 5.5),
  BreedInfo('西施犬', PetSpecies.dog, 4, 8),
  BreedInfo('北京犬/京巴', PetSpecies.dog, 3.5, 5.5),
  BreedInfo('中国冠毛犬', PetSpecies.dog, 4, 7),
  BreedInfo('日本银狐', PetSpecies.dog, 5, 8),
  BreedInfo('查理王小猎犬', PetSpecies.dog, 5, 8),
  BreedInfo('巴吉度猎犬', PetSpecies.dog, 18, 29),
  BreedInfo('阿富汗猎犬', PetSpecies.dog, 22, 27),
  BreedInfo('灵缇', PetSpecies.dog, 25, 40),
  BreedInfo('意大利灵缇', PetSpecies.dog, 3, 5),
  BreedInfo('迷你杜宾', PetSpecies.dog, 3, 6),
  BreedInfo('威玛猎犬', PetSpecies.dog, 25, 35),
  BreedInfo('伯恩山犬', PetSpecies.dog, 38, 50),
  BreedInfo('圣伯纳', PetSpecies.dog, 55, 90),
  BreedInfo('大丹犬', PetSpecies.dog, 45, 80),
  BreedInfo('大白熊/比利牛斯山地犬', PetSpecies.dog, 40, 54),
  BreedInfo('纽芬兰犬', PetSpecies.dog, 45, 68),
  BreedInfo('阿根廷杜高', PetSpecies.dog, 36, 45),
  BreedInfo('比特犬', PetSpecies.dog, 14, 28),
  BreedInfo('藏獒', PetSpecies.dog, 45, 70),
  BreedInfo('高加索牧羊犬', PetSpecies.dog, 45, 70),
  BreedInfo('昆明犬', PetSpecies.dog, 30, 40),
];

/// 常见猫种。
const List<BreedInfo> kCatBreeds = [
  BreedInfo('中华田园猫', PetSpecies.cat, 3, 6),
  BreedInfo('英国短毛猫', PetSpecies.cat, 4, 8),
  BreedInfo('美国短毛猫', PetSpecies.cat, 3.5, 7),
  BreedInfo('布偶猫', PetSpecies.cat, 4.5, 9),
  BreedInfo('缅因猫', PetSpecies.cat, 6, 11),
  BreedInfo('暹罗猫', PetSpecies.cat, 2.5, 5),
  BreedInfo('加菲猫/异国短毛猫', PetSpecies.cat, 3.5, 7),
  BreedInfo('波斯猫', PetSpecies.cat, 3.5, 5.5),
  BreedInfo('斯芬克斯无毛猫', PetSpecies.cat, 3.5, 7),
  BreedInfo('德文卷毛猫', PetSpecies.cat, 2.5, 4.5),
  BreedInfo('柯尼斯卷毛猫', PetSpecies.cat, 2.5, 4.5),
  BreedInfo('孟加拉豹猫', PetSpecies.cat, 4, 7),
  BreedInfo('俄罗斯蓝猫', PetSpecies.cat, 3, 5.5),
  BreedInfo('金渐层', PetSpecies.cat, 4, 8),
  BreedInfo('银渐层', PetSpecies.cat, 3.5, 7),
  BreedInfo('挪威森林猫', PetSpecies.cat, 4, 9),
  BreedInfo('西伯利亚森林猫', PetSpecies.cat, 4.5, 9),
  BreedInfo('苏格兰折耳猫', PetSpecies.cat, 3, 6),
  BreedInfo('美国卷耳猫', PetSpecies.cat, 3, 5),
  BreedInfo('伯曼猫', PetSpecies.cat, 3.5, 5.5),
  BreedInfo('土耳其梵猫', PetSpecies.cat, 3.5, 6),
  BreedInfo('沙特尔猫', PetSpecies.cat, 4, 7),
  BreedInfo('阿比西尼亚猫', PetSpecies.cat, 3, 5.5),
  BreedInfo('东奇尼猫', PetSpecies.cat, 3, 5.5),
  BreedInfo('新加坡猫', PetSpecies.cat, 1.8, 3),
  BreedInfo('萨凡纳猫', PetSpecies.cat, 5, 9),
  BreedInfo('埃及猫', PetSpecies.cat, 3, 5),
];

List<BreedInfo> breedsFor(PetSpecies species) =>
    species == PetSpecies.cat ? kCatBreeds : kDogBreeds;

/// 按名称查找品种的典型体重区间；找不到返回 null。
BreedInfo? findBreed(String? name, PetSpecies species) {
  if (name == null || name.trim().isEmpty) return null;
  final n = name.trim();
  for (final b in breedsFor(species)) {
    if (b.name == n) return b;
  }
  // 允许去掉后缀/别名的模糊匹配，如「金毛」「京巴」「拉布拉多犬」。
  for (final b in breedsFor(species)) {
    for (final seg in b.name.split('/')) {
      if (seg.contains(n) || n.contains(seg)) return b;
    }
  }
  return null;
}
