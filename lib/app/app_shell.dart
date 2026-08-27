import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'theme.dart';

/// 中央爪印钮：按压缩放反馈。
class _CenterButton extends StatefulWidget {
  const _CenterButton();

  @override
  State<_CenterButton> createState() => _CenterButtonState();
}

class _CenterButtonState extends State<_CenterButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet<void>(
          context: context,
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text('记一笔',
                      style: Theme.of(sheetContext).textTheme.titleMedium),
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsDuotone.firstAidKit,
                      size: 24, color: AppTheme.green),
                  title: const Text('健康记录',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('体重 / 疫苗 / 驱虫 / 就诊',
                      style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    sheetContext.push('/health/record/new');
                  },
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsDuotone.camera,
                      size: 24, color: AppTheme.green),
                  title: const Text('时刻',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('游玩 / 美容 / 生日，带照片',
                      style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    sheetContext.push('/moment/new');
                  },
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsDuotone.coins,
                      size: 24, color: AppTheme.green),
                  title: const Text('消费',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('为它花的每一笔',
                      style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    sheetContext.push('/expense/new');
                  },
                ),
                ListTile(
                  leading: Icon(PhosphorIconsDuotone.sparkle,
                      size: 24, color: sheetContext.palette.accentText),
                  title: const Text('AI 一句话记录',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('「今天打了狂犬疫苗花了200」',
                      style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    sheetContext.push('/ai/quick-add');
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
      child: Semantics(
        label: '记一笔',
        button: true,
        child: AnimatedScale(
          duration: Motion.fast,
          curve: Curves.easeOutBack,
          scale: _pressed ? 0.88 : 1.0,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppTheme.primaryGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.green.withValues(alpha: 0.30),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(PhosphorIconsBold.pawPrint,
                color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}

/// 底部导航外壳：首页/健康/记录(中央圆钮)/饮食/时刻。
/// 图标语言：Phosphor Duotone 矢量双色（结构层统一），emoji 只保留在
/// 氛围层（toast/空态/AI 文案）。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    Widget navItem(IconData icon, IconData iconFill, String label, int index) {
      final selected = navigationShell.currentIndex == index;
      return InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 选中态：淡染胶囊 + 实底填充图标。
              AnimatedScale(
                scale: selected ? 1.12 : 1.0,
                duration: Motion.fast,
                curve: Curves.easeOutBack,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
                  decoration: selected
                      ? BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(10),
                        )
                      : null,
                  child: Icon(
                    selected ? iconFill : icon,
                    size: 21,
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    const centerButton = _CenterButton();

    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          // 毛玻璃：背景模糊 + 半透明表面 + 发丝描边。
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.glassSurface(dark),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.glassBorder(dark)),
              ),
              child: Row(
                children: [
                  Expanded(
                      child: Center(
                          child: navItem(PhosphorIconsDuotone.house,
                              PhosphorIconsFill.house, '首页', 0))),
                  Expanded(
                      child: Center(
                          child: navItem(PhosphorIconsDuotone.heartStraight,
                              PhosphorIconsFill.heartStraight, '健康', 1))),
                  Expanded(child: Center(child: centerButton)),
                  Expanded(
                      child: Center(
                          child: navItem(PhosphorIconsDuotone.bowlFood,
                              PhosphorIconsFill.bowlFood, '饮食', 2))),
                  Expanded(
                      child: Center(
                          child: navItem(PhosphorIconsDuotone.camera,
                              PhosphorIconsFill.camera, '时刻', 3))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


}
