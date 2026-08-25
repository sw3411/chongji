import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/ai/ai_client.dart';
import '../../core/ai/ai_config.dart';
import '../../shared/widgets/common.dart';

/// AI 设置：API 地址 / Key / 模型 + 测试连接。
/// 兼容 OpenAI / DeepSeek / GLM / Ollama 等 OpenAI 兼容服务。
class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _model;
  bool _enabled = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(aiConfigProvider);
    _baseUrl = TextEditingController(text: config.baseUrl);
    _apiKey = TextEditingController(text: config.apiKey);
    _model = TextEditingController(text: config.model);
    _enabled = config.enabled;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    super.dispose();
  }

  AiConfig get _draftConfig => AiConfig(
        // 字段填全了就自动启用，避免「填了但开关没开」导致提示未配置。
        enabled: _baseUrl.text.trim().isNotEmpty &&
                _apiKey.text.trim().isNotEmpty &&
                _model.text.trim().isNotEmpty
            ? true
            : _enabled,
        baseUrl: _baseUrl.text.trim(),
        apiKey: _apiKey.text.trim(),
        model: _model.text.trim(),
        temperature: ref.read(aiConfigProvider).temperature,
      );

  Future<void> _save() async {
    await ref.read(aiConfigProvider.notifier).save(_draftConfig);
    if (mounted) showAutoToast(context, '已保存');
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      final reply = await AiClient(_draftConfig).testConnection();
      // 测试通过即自动保存，避免「测试成功但忘了保存」的坑。
      await ref.read(aiConfigProvider.notifier).save(_draftConfig);
      if (mounted) showAutoToast(context, '连接成功，已自动保存：$reply');
    } on AiException catch (e) {
      if (mounted) showAutoToast(context, e.message);
    } catch (e) {
      if (mounted) showAutoToast(context, '测试失败：$e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI 助手设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('启用 AI 功能', style: AppTheme.cardTitle(cs.onSurface)),
            subtitle: Text('API 信息填全后自动启用，也可手动开关',
                style: AppTheme.footnote(cs.onSurfaceVariant)),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              labelText: 'API 地址（OpenAI 兼容）',
              hintText: 'https://api.openai.com/v1',
              helperText: '也支持 DeepSeek / GLM / Moonshot / 本地 Ollama',
            ),
            style: AppTheme.body(cs.onSurface),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _apiKey,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'sk-…',
              helperText: '仅保存在本机系统钥匙串/Keystore，不上传',
            ),
            style: AppTheme.body(cs.onSurface),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: '模型名称',
              hintText: 'gpt-4o-mini / deepseek-chat / glm-4-flash',
            ),
            style: AppTheme.body(cs.onSurface),
          ),
          const SizedBox(height: 12),
          Text(
            '常用地址示例：\n· OpenAI：https://api.openai.com/v1\n· DeepSeek：https://api.deepseek.com/v1\n· 智谱 GLM：https://open.bigmodel.cn/api/paas/v4\n· Ollama 本地：http://localhost:11434/v1',
            style: AppTheme.caption(cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _test,
                  child: _testing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('测试连接'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: _save, child: const Text('保存')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '隐私说明：AI 功能会把相关宠物数据发送到你配置的 API 服务商；不配置则完全不发送。',
            style: AppTheme.caption(cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
