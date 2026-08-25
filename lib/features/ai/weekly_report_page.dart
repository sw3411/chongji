import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/ai/ai_client.dart';
import '../../shared/widgets/common.dart';

/// AI 健康周报：最近 7 天数据 → Markdown 解读。
class WeeklyReportPage extends ConsumerStatefulWidget {
  const WeeklyReportPage({super.key});

  @override
  ConsumerState<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends ConsumerState<WeeklyReportPage> {
  bool _loading = false;
  String? _report;
  String? _error;

  Future<void> _generate() async {
    final pet = ref.read(currentPetProvider);
    if (pet == null) {
      showAutoToast(context, '先添加一只宠物吧');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final records = await ref.read(healthRepoProvider).getByPet(pet.id);
      final expenses = await ref.read(expenseRepoProvider).getAll();
      final plans = await ref
          .read(dietRepoProvider)
          .watchPlansByPet(pet.id)
          .first;
      _report = await ref.read(aiServiceProvider).weeklyReport(
            pet,
            records,
            expenses,
            plans.isEmpty ? null : plans.first,
          );
    } on AiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = '生成失败：$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pet = ref.watch(currentPetProvider);
    final config = ref.watch(aiConfigProvider);

    return Scaffold(
      appBar: AppBar(title: Text('${pet?.name ?? ""}的健康周报')),
      body: !config.isReady
          ? EmptyView(
              icon: Icons.key_outlined,
              title: 'AI 还没有配置',
              subtitle: '配置 API 后即可生成一周健康解读',
              action: FilledButton(
                onPressed: () => context.push('/settings/ai'),
                child: const Text('去配置'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton.icon(
                  onPressed: _loading ? null : _generate,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_loading
                      ? '正在总结最近 7 天…'
                      : _report == null
                          ? '生成周报'
                          : '重新生成'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: AppTheme.footnote(AppTheme.warnRed)),
                ],
                if (_report != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: MarkdownBody(
                        data: _report!,
                        styleSheet: digestMarkdownStyle(context),
                        selectable: true,
                      ),
                    ),
                  ),
                ],
                if (_report == null && _error == null && !_loading)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      '会汇总最近 7 天的体重、体型、健康事件、消费与喂食计划，生成一份带建议的健康周报。',
                      textAlign: TextAlign.center,
                      style: AppTheme.subhead(cs.onSurfaceVariant),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
