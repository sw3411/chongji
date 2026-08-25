/// AI 配置：OpenAI 兼容接口（OpenAI / DeepSeek / GLM / Ollama 通用）。
/// 配置主体存设置表；apiKey 只存系统钥匙串（见 providers.dart 的 AiConfigNotifier）。
class AiConfig {
  AiConfig({
    this.enabled = false,
    this.baseUrl = 'https://api.openai.com/v1',
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
    this.temperature = 0.3,
  });

  bool enabled;
  String baseUrl;
  String apiKey;
  String model;
  double temperature;

  bool get isReady =>
      enabled && apiKey.trim().isNotEmpty && baseUrl.trim().isNotEmpty;

  factory AiConfig.fromJson(Map<String, dynamic> json) => AiConfig(
        enabled: json['enabled'] as bool? ?? false,
        baseUrl: json['baseUrl'] as String? ?? 'https://api.openai.com/v1',
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String? ?? 'gpt-4o-mini',
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.3,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'temperature': temperature,
      };
}
