import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';

/// 页面右上角手动同步按钮：拉取 + 有修改才推送。
class SyncButton extends ConsumerWidget {
  const SyncButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(syncBusyProvider);
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: busy ? '同步中…' : '同步云空间',
      onPressed:
          busy ? null : () => manualSyncCurrentPet(ref, context),
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.sync_rounded, color: cs.primary),
    );
  }
}

/// 深色横幅上用的浅色版本（首页）。
class SyncButtonLight extends ConsumerWidget {
  const SyncButtonLight({super.key, this.shadows = true});

  final bool shadows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(syncBusyProvider);
    return IconButton(
      tooltip: busy ? '同步中…' : '同步云空间',
      onPressed:
          busy ? null : () => manualSyncCurrentPet(ref, context),
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(
              Icons.sync_rounded,
              color: Colors.white,
              shadows: shadows ? AppTheme.bannerShadow : null,
            ),
    );
  }
}
