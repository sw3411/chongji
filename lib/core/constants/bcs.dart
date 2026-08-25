/// BCS（Body Condition Score，体型体况评分）1-9 分制定义。
/// 每一档附触诊/目视描述，供选择器 UI 与 AI Prompt 使用。
class BcsLevel {
  const BcsLevel(this.score, this.band, this.description);

  final int score;
  /// 分档：极瘦 / 偏瘦 / 理想 / 偏胖 / 肥胖。
  final String band;
  final String description;
}

const List<BcsLevel> kBcsLevels = [
  BcsLevel(1, '极瘦', '肋骨、腰椎、骨盆明显凸出，无脂肪可触，肌肉明显流失'),
  BcsLevel(2, '极瘦', '肋骨、腰椎、骨盆易见，几乎无体脂，腹部严重内收'),
  BcsLevel(3, '偏瘦', '肋骨易触及且可见，腰椎顶部可见，腹部明显上收'),
  BcsLevel(4, '偏瘦', '肋骨易触及，少量脂肪覆盖，腰线从上方可见'),
  BcsLevel(5, '理想', '肋骨可触及无多余脂肪，俯视有明显腰线，腹部上收'),
  BcsLevel(6, '偏胖', '肋骨可触及有轻微多余脂肪，腰线可见但不明显'),
  BcsLevel(7, '偏胖', '肋骨难触及脂肪较厚，腰线几乎不可见，腹部微垂'),
  BcsLevel(8, '肥胖', '肋骨很难触及，无腰线，腹部明显下垂，背部增厚'),
  BcsLevel(9, '肥胖', '大量脂肪沉积，肋骨触不到，腹部显著下垂，行动可能受限'),
];

/// 评分所属分档（1-2 极瘦 / 3-4 偏瘦 / 5 理想 / 6-7 偏胖 / 8-9 肥胖）。
String bcsBand(int score) {
  if (score <= 2) return '极瘦';
  if (score <= 4) return '偏瘦';
  if (score == 5) return '理想';
  if (score <= 7) return '偏胖';
  return '肥胖';
}
