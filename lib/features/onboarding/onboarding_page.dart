import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/constants/app_info.dart';

/// 首次启动引导：介绍 + 添加第一只宠物。
class OnboardingHost extends ConsumerWidget {
  const OnboardingHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: AppTheme.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pets, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 28),
              Text(AppInfo.appName, style: AppTheme.largeTitle(cs.onSurface, size: 40)),
              const SizedBox(height: 10),
              Text(AppInfo.appTagline, style: AppTheme.subhead(cs.onSurfaceVariant)),
              const Spacer(),
              _FeatureRow(
                icon: Icons.monitor_heart_rounded,
                color: AppTheme.green,
                title: '健康管理',
                subtitle: '体重曲线、疫苗驱虫到期提醒、就诊记录',
              ),
              const SizedBox(height: 18),
              _FeatureRow(
                icon: Icons.restaurant_rounded,
                color: AppTheme.warnAmber,
                title: 'AI 饮食计划',
                subtitle: '按体重体型与口味偏好，生成每天每餐怎么喂',
              ),
              const SizedBox(height: 18),
              _FeatureRow(
                icon: Icons.photo_camera_back_rounded,
                color: AppTheme.infoBlue,
                title: '时刻与账本',
                subtitle: '照片时间线记录成长，消费笔笔清楚',
              ),
              const Spacer(flex: 2),
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(settingsRepoProvider)
                      .setBool('onboarded', true);
                  if (context.mounted) context.go('/pet/new');
                },
                child: const Text('开始使用'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await ref
                      .read(settingsRepoProvider)
                      .setBool('onboarded', true);
                  if (context.mounted) context.go('/home');
                },
                child: const Text('先逛逛，稍后再添加宠物'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.cardTitle(cs.onSurface)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTheme.footnote(cs.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
