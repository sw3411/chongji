import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import 'ai_config.dart';

/// 消息角色。
class AiMessage {
  AiMessage(this.role, this.content);

  final String role; // system / user / assistant
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// AI 调用异常。
class AiException implements Exception {
  AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 带状态码的异常，供调用方判断是否降级（如服务商不支持 tools）。
class AiExceptionWithStatus extends AiException {
  AiExceptionWithStatus(this.statusCode, String message) : super(message);

  final int statusCode;
}

/// 工具调用对话的最终结果：回答与思考分离。
class AiToolReply {
  const AiToolReply({required this.content, this.reasoning = ''});

  final String content;

  /// 思考型模型的思考内容（可与 content 同时存在）。
  final String reasoning;
}

/// OpenAI 兼容 API 客户端（含 SSE 流式）。
/// 适配 OpenAI / DeepSeek / GLM / Moonshot / 本地 Ollama 等所有
/// 提供 /chat/completions 接口的服务，用户只需配置 baseUrl/apiKey/model。
class AiClient {
  AiClient(this.config);

  final AiConfig config;

  Uri get _endpoint => Uri.parse(
      '${config.baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      };

  void _ensureReady() {
    if (!config.isReady) {
      throw AiException('AI 未配置或未启用，请先在「设置 → AI 助手」中完成配置');
    }
  }

  /// 单轮/多轮对话，阻塞返回完整回复。
  Future<String> chat(
    List<AiMessage> messages, {
    bool jsonMode = false,
    int timeoutSeconds = 90,
  }) async {
    _ensureReady();
    final body = <String, dynamic>{
      'model': config.model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'temperature': config.temperature,
    };
    if (jsonMode) {
      body['response_format'] = {'type': 'json_object'};
    }
    final data = await _post(body, timeoutSeconds: timeoutSeconds);
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw AiException('API 返回格式异常：缺少 choices');
    }
    final message = (choices.first as Map<String, dynamic>)['message'];
    final msg = message as Map<String, dynamic>?;
    var text = msg?['content']?.toString() ?? '';
    // 思考型模型（DeepSeek-R1 / GLM 思考版等）：思考在 reasoning_content，
    // content 可能为空——回退用思考内容，避免误报“空内容”。
    if (text.isEmpty) {
      text = msg?['reasoning_content']?.toString() ?? '';
      if (text.isNotEmpty) text = '思考：$text';
    }
    if (text.isEmpty) {
      throw AiException(
          'API 返回了空内容（若配置的是思考型模型，可能思考过长未产出答案，'
          '可换普通对话模型或简化问题后重试）');
    }
    return text;
  }

  /// 流式对话（SSE）：增量回调 [onDelta]（isReasoning=true 为思考文本），
  /// 全部结束后返回完整回答（回答为空时返回思考文本）。用于聊天页。
  Future<String> chatStream(
    List<AiMessage> messages, {
    required void Function(String delta, {bool isReasoning}) onDelta,
    int timeoutSeconds = 120,
  }) async {
    _ensureReady();
    final client = http.Client();
    try {
      final request = http.Request('POST', _endpoint)
        ..headers.addAll(_headers)
        ..body = jsonEncode({
          'model': config.model,
          'messages': messages.map((m) => m.toJson()).toList(),
          'temperature': config.temperature,
          'stream': true,
        });
      final response = await client
          .send(request)
          .timeout(Duration(seconds: timeoutSeconds));
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        String detail = '';
        try {
          final data = jsonDecode(body) as Map<String, dynamic>;
          final err = data['error'];
          if (err is Map<String, dynamic>) {
            detail = err['message']?.toString() ?? '';
          }
        } catch (_) {}
        throw AiExceptionWithStatus(response.statusCode,
            'API 返回 ${response.statusCode}${detail.isEmpty ? '' : '：$detail'}');
      }

      final answerBuf = StringBuffer();
      final thinkingBuf = StringBuffer();
      var lineBuffer = '';
      void handle(({String content, String reasoning}) parsed) {
        if (parsed.reasoning.isNotEmpty) {
          thinkingBuf.write(parsed.reasoning);
          onDelta(parsed.reasoning, isReasoning: true);
        }
        if (parsed.content.isNotEmpty) {
          answerBuf.write(parsed.content);
          onDelta(parsed.content, isReasoning: false);
        }
      }

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        lineBuffer += chunk;
        final lines = lineBuffer.split('\n');
        lineBuffer = lines.removeLast(); // 末行可能不完整，留在缓冲。
        for (final line in lines) {
          handle(_parseSseLine(line));
        }
      }
      handle(_parseSseLine(lineBuffer));
      if (answerBuf.isEmpty && thinkingBuf.isEmpty) {
        throw AiException(
            'API 返回了空内容（若配置的是思考型模型，可能思考过长未产出答案，'
            '可换普通对话模型或简化问题后重试）');
      }
      return answerBuf.isNotEmpty ? answerBuf.toString() : thinkingBuf.toString();
    } catch (e) {
      if (e is AiException) rethrow;
      throw AiException('网络请求失败：$e');
    } finally {
      client.close();
    }
  }

  /// 解析一行 SSE（data: {...}），返回增量文本与思考文本；
  /// [DONE] 与空行返回空记录。思考型模型的思考在 reasoning_content。
  @visibleForTesting
  static ({String content, String reasoning}) parseSseLine(String line) {
    final empty = (content: '', reasoning: '');
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith(':')) return empty;
    if (!trimmed.startsWith('data:')) return empty;
    // 'data:' 占 5 个字符（原 substring(4) 会留下开头的冒号导致解析恒失败）。
    final payload = trimmed.substring(5).trim();
    if (payload == '[DONE]') return empty;
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return empty;
      final delta = (choices.first as Map<String, dynamic>?)?['delta']
          as Map<String, dynamic>?;
      return (
        content: delta?['content'] as String? ?? '',
        reasoning: (delta?['reasoning_content'] ?? delta?['reasoning'])
                as String? ??
            '',
      );
    } catch (_) {
      return empty;
    }
  }

  static ({String content, String reasoning}) _parseSseLine(String line) =>
      parseSseLine(line);

  /// 工具调用循环（OpenAI function calling 兼容协议，非流式）。
  Future<AiToolReply> chatWithTools(
    List<AiMessage> messages,
    List<Map<String, dynamic>> tools,
    Future<String> Function(String name, Map<String, dynamic> args) executor, {
    int maxTurns = 4,
    void Function(String toolName)? onToolCall,
  }) async {
    _ensureReady();
    final conversation = [...messages.map((m) => m.toJson())];
    for (var turn = 0; turn < maxTurns; turn++) {
      final resp = await _post({
        'model': config.model,
        'messages': conversation,
        'temperature': config.temperature,
        'tools': tools,
        'tool_choice': 'auto',
      });
      final choices = resp['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw AiException('API 返回格式异常：缺少 choices');
      }
      final message = (choices.first as Map<String, dynamic>)['message']
          as Map<String, dynamic>?;
      if (message == null) {
        throw AiException('API 返回格式异常：缺少 message');
      }
      final toolCalls = message['tool_calls'] as List<dynamic>?;
      if (toolCalls == null || toolCalls.isEmpty) {
        final text = message['content']?.toString() ?? '';
        final reasoning = message['reasoning_content']?.toString() ?? '';
        if (text.isEmpty && reasoning.isEmpty) {
          throw AiException(
              'API 返回了空内容（若配置的是思考型模型，可能思考过长未产出答案）');
        }
        return AiToolReply(content: text, reasoning: reasoning);
      }

      conversation.add({
        'role': 'assistant',
        'content': message['content'] ?? '',
        'tool_calls': toolCalls,
      });
      for (final call in toolCalls) {
        final fn = (call as Map<String, dynamic>)['function']
            as Map<String, dynamic>?;
        final id = call['id'] as String? ?? '';
        final name = fn?['name'] as String? ?? '';
        var args = <String, dynamic>{};
        if (fn != null && fn['arguments'] != null) {
          try {
            final decoded = fn['arguments'];
            args = decoded is String
                ? (jsonDecode(decoded) as Map<String, dynamic>? ?? {})
                : (decoded as Map<String, dynamic>? ?? {});
          } catch (_) {
            args = {};
          }
        }
        onToolCall?.call(name);
        String result;
        try {
          result = await executor(name, args);
        } catch (e) {
          result = '工具执行失败：$e';
        }
        conversation.add({
          'role': 'tool',
          'tool_call_id': id,
          'content':
              result.length > 6000 ? result.substring(0, 6000) : result,
        });
      }
    }
    throw AiException('工具调用轮次过多，请稍后简化重试');
  }

  /// 便捷方法：system + user 单轮。
  Future<String> ask(String system, String user, {bool jsonMode = false}) =>
      chat([AiMessage('system', system), AiMessage('user', user)],
          jsonMode: jsonMode);

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body,
      {int timeoutSeconds = 90}) async {
    http.Response resp;
    try {
      resp = await http
          .post(_endpoint, headers: _headers, body: jsonEncode(body))
          .timeout(Duration(seconds: timeoutSeconds));
    } catch (e) {
      throw AiException('网络请求失败：$e');
    }
    if (resp.statusCode != 200) {
      String detail = '';
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final err = data['error'];
        if (err is Map<String, dynamic>) {
          detail = err['message']?.toString() ?? '';
        }
      } catch (_) {}
      throw AiExceptionWithStatus(resp.statusCode,
          'API 返回 ${resp.statusCode}${detail.isEmpty ? '' : '：$detail'}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// 测试连接：发送一句话，成功返回回复文本。
  Future<String> testConnection() async {
    _ensureReady();
    return chat([
      AiMessage('user', '请只回复：ok'),
    ], timeoutSeconds: 30);
  }
}
