import 'package:flutter/material.dart';
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
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 选中时图标背后加胶囊底（WhatsApp 选中 tab 样式）。
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                decoration: selected
                    ? BoxDecoration(
                        color: dark ? AppTheme.greenDark : AppTheme.green,
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: Icon(
                  selected ? activeIcon : icon,
                  size: 22,
                  color: selected ? Colors.white : color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomAppBar(
        elevation: 0,
        color: dark ? AppTheme.darkSurface : AppTheme.lightSurface,
        child: Row(
          children: [
            Expanded(
                child: Center(
                    child: navItem(Icons.home_outlined, Icons.home_rounded,
                        '首页', 0))),
            Expanded(
                child: Center(
                    child: navItem(Icons.monitor_heart_outlined,
                        Icons.monitor_heart_rounded, '健康', 1))),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: () => _showAddMenu(context),
                  child: Semantics(
                    label: '记一笔',
                    button: true,
                    child: Container(
                      width: 54,
                      height: 54,
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: dark ? AppTheme.greenDark : AppTheme.green,
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.add, color: Colors.white, size: 30),
                    ),
                  ),
                ),
              ),
            ),
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
