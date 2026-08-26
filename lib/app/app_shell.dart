import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';

/// 底部导航外壳：首页/健康/记录(中央圆钮)/饮食/账本。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    Widget navItem(IconData icon, IconData activeIcon, String label,
        int index) {
      final selected = navigationShell.currentIndex == index;
      final color = selected ? cs.primary : cs.onSurfaceVariant;
      return InkWell(
        onTap: () => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 选中时图标背后加胶囊底（潮汐式轻量选中态）。
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
                decoration: selected
                    ? BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(9),
                      )
                    : null,
                child: Icon(
                  selected ? activeIcon : icon,
                  size: 19,
                  color: selected ? cs.primary : color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget centerButton() {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _showAddMenu(context);
        },
        child: Semantics(
          label: '记一笔',
          button: true,
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
            child: const Icon(Icons.pets, color: Colors.white, size: 20),
          ),
        ),
      );
    }

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
                          child: navItem(Icons.home_outlined,
                              Icons.home_rounded, '首页', 0))),
                  Expanded(
                      child: Center(
                          child: navItem(Icons.monitor_heart_outlined,
                              Icons.monitor_heart_rounded, '健康', 1))),
                  Expanded(child: Center(child: centerButton())),
                  Expanded(
                      child: Center(
                          child: navItem(Icons.restaurant_outlined,
                              Icons.restaurant_rounded, '饮食', 2))),
                  Expanded(
                      child: Center(
                          child: navItem(Icons.photo_camera_back_outlined,
                              Icons.photo_camera_back_rounded, '时刻', 3))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text('记一笔',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: const Text('健康记录',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('体重 / 疫苗 / 驱虫 / 就诊',
                  style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                context.push('/health/record/new');
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_back_outlined),
              title: const Text('时刻',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('游玩 / 美容 / 生日，带照片',
                  style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                context.push('/moment/new');
              },
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('消费',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('为它花的每一笔', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                context.push('/expense/new');
              },
            ),
            ListTile(
              leading: Icon(Icons.auto_awesome_outlined,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('AI 一句话记录',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle:
                  const Text('「今天打了狂犬疫苗花了200」', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                context.push('/ai/quick-add');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
