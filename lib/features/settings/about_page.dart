import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/constants/app_info.dart';

/// 关于页。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 32),
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppTheme.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets, color: Colors.white, size: 42),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text(AppInfo.appName, style: AppTheme.title(cs.onSurface))),
          const SizedBox(height: 4),
          Center(
              child:
                  Text('v0.1.0', style: AppTheme.caption(cs.onSurfaceVariant))),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('隐私说明', style: AppTheme.cardTitle(cs.onSurface)),
                  const SizedBox(height: 8),
                  Text(
                    '· 所有数据只保存在你的手机本地，无账号、无云端。\n'
                    '· AI 功能会把相关宠物数据发送到你自行配置的 API 服务商；不配置则完全不发送。\n'
                    '· 备份文件包含照片，请妥善保管。',
                    style: AppTheme.subhead(cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('健康提示', style: AppTheme.cardTitle(cs.onSurface)),
                  const SizedBox(height: 8),
                  Text(
                    '宠迹的喂食与热量建议基于通用营养学估算，不能替代兽医诊断。宠物出现异常症状请及时就医。',
                    style: AppTheme.subhead(cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
