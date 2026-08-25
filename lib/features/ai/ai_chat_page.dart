import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/ai/ai_client.dart';
import '../../core/ai/ai_service.dart';
import '../../domain/models/diet_profile.dart';
import '../../domain/models/chat_session.dart';
import '../../domain/models/health_record.dart';
import '../../domain/models/meal_plan.dart';
import '../../shared/widgets/common.dart';

/// AI 对话助手：AI 主动调工具读本地数据；思考与回答分区，思考默认折叠。
class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _ChatMsg {
  _ChatMsg.user(this.answer)
      : isUser = true,
        loading = false;
  _ChatMsg.assistant({this.loading = false})
      : isUser = false;

  bool isUser;
  String answer = '';
  String thinking = '';

  /// 生成中（三点/状态提示）。
  bool loading;

  /// 工具查询状态（如“正在查询：体重趋势”）。
  String? toolStatus;

  /// 用户手动展开/收起思考；null = 自动（回答出现前展开，之后折叠）。
  bool? thinkingExpanded;
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  static const _greeting = '你好呀！我会主动查阅你记录的数据来回答问题，比如：\n'
      '· 最近体重趋势怎么样？\n· 驱虫该做了吗？\n· 这几个月花了多少钱？';

  final _messages = <_ChatMsg>[
    _ChatMsg.assistant()..answer = _greeting,
  ];
  bool _busy = false;
  PetDataPort? _port;

  // ---- 会话持久化 ----
  static const _uuid = Uuid();
  String? _sessionId;
  DateTime? _sessionCreatedAt;
  @override
  void initState() {
    super.initState();
    _restoreLatest();
  }

  /// 启动时恢复最近一次会话（对话记录保留）。
  Future<void> _restoreLatest() async {
    final latest = await ref.read(chatSessionRepoProvider).getLatest();
    if (!mounted || latest == null) return;
    setState(() => _loadMessages(latest));
  }

  void _loadMessages(ChatSession session) {
    _messages
      ..clear()
      ..addAll(session.messages.map((m) => m.isUser
          ? _ChatMsg.user(m.answer)
          : _ChatMsg.assistant()..answer = m.answer..thinking = m.thinking));
    if (_messages.isEmpty) {
      _messages.add(_ChatMsg.assistant()..answer = _greeting);
    }
    _sessionId = session.id;
    _sessionCreatedAt = session.createdAt;
  }

  /// 新建会话（当前会话已自动保存）。
  void _newSession() {
    if (_busy) return;
    setState(() {
      _messages
        ..clear()
        ..add(_ChatMsg.assistant()..answer = '我们开始新对话吧，想问点什么？');
      _sessionId = null;
      _sessionCreatedAt = null;
    });
  }

  /// 持久化当前会话（存在用户消息才存）。
  Future<void> _persist() async {
    final msgs = [
      for (final m in _messages)
        if (!m.loading && (m.isUser || m.answer.isNotEmpty || m.thinking.isNotEmpty))
          ChatMessage(isUser: m.isUser, answer: m.answer, thinking: m.thinking),
    ];
    if (!msgs.any((m) => m.isUser)) return;
    String title = '';
    for (final m in msgs) {
      if (m.isUser) {
        title = m.answer.trim();
        break;
      }
    }
    if (title.length > 24) title = '${title.substring(0, 24)}…';
    final pet = ref.read(currentPetProvider);
    _sessionId ??= _uuid.v4();
    _sessionCreatedAt ??= DateTime.now();
    await ref.read(chatSessionRepoProvider).upsert(ChatSession(
          id: _sessionId!,
          title: title.isEmpty ? '对话' : title,
          petId: pet?.id ?? '',
          petName: pet?.name ?? '',
          messages: msgs,
          createdAt: _sessionCreatedAt!,
          updatedAt: DateTime.now(),
        ));
  }

  static const _toolLabels = {
    'get_health_records': '健康记录',
    'get_weight_trend': '体重趋势',
    'get_expense_summary': '消费统计',
    'get_diet_info': '饮食信息',
  };

  Future<void> _ensurePort() async {
    if (_port != null) return;
    final pets = await ref.read(petRepoProvider).getAll();
    final petsActive = pets.where((p) => !p.isDeleted).toList();
    final recordsByPet = <String, List<HealthRecord>>{};
    final profilesByPet = <String, DietProfile>{};
    final plansByPet = <String, List<MealPlan>>{};
    for (final p in petsActive) {
      recordsByPet[p.id] = await ref.read(healthRepoProvider).getByPet(p.id);
      final profile = await ref.read(dietRepoProvider).getProfile(p.id);
      if (profile != null) profilesByPet[p.id] = profile;
      plansByPet[p.id] =
          await ref.read(dietRepoProvider).watchPlansByPet(p.id).first;
    }
    final expenses = await ref.read(expenseRepoProvider).getAll();
    _port = PetDataPort(
      pets: petsActive,
      recordsByPet: recordsByPet,
      expenses: expenses,
      profilesByPet: profilesByPet,
      plansByPet: plansByPet,
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _update(int index, void Function(_ChatMsg) mutate) {
    if (!mounted) return;
    setState(() => mutate(_messages[index]));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _busy) return;
    final pet = ref.read(currentPetProvider);
    if (pet == null) {
      showAutoToast(context, '先添加一只宠物再聊天吧');
      return;
    }
    _inputController.clear();
    setState(() {
      _messages.add(_ChatMsg.user(text));
      _messages.add(_ChatMsg.assistant(loading: true));
      _busy = true;
    });
    _persist(); // 用户消息先落盘，防止中断丢失
    _scrollToBottom();
    final replyIndex = _messages.length - 1;

    try {
      await _ensurePort();
      final port = _port!;
      // 历史只携带回答（思考内容不重复送回，节省 token）。
      final convoEnd = _messages.length - 2;
      final convoStart = convoEnd >= 8 ? convoEnd - 8 : 0;
      final history = <AiMessage>[
        for (final m in _messages.sublist(convoStart, convoEnd))
          AiMessage(
            m.isUser ? 'user' : 'assistant',
            m.answer.isNotEmpty ? m.answer : m.thinking,
          ),
      ];

      final reply = await ref.read(aiServiceProvider).chat(
            port,
            pet,
            [...history, AiMessage('user', text)],
            onToolCall: (name) => _update(replyIndex,
                (m) => m.toolStatus = _toolLabels[name] ?? '本地数据'),
            onThinkingDelta: (d) =>
                _update(replyIndex, (m) => m.thinking += d),
            onAnswerDelta: (d) => _update(replyIndex, (m) {
                  m.answer += d;
                  m.toolStatus = null;
                }),
          );
      // 兜底：确保最终内容落在消息上（回调遗漏时）。
      _update(replyIndex, (m) {
        if (reply.thinking.isNotEmpty && m.thinking.isEmpty) {
          m.thinking = reply.thinking;
        }
        if (reply.answer.isNotEmpty && m.answer.isEmpty) {
          m.answer = reply.answer;
        }
        m.loading = false;
        m.toolStatus = null;
      });
    } on AiExceptionWithStatus catch (e) {
      _fail(replyIndex, e.message);
    } on AiException catch (e) {
      _fail(replyIndex, e.message);
    } catch (e) {
      _fail(replyIndex, '出错了：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
      _persist(); // 回复完成/失败后保存整段会话
      _scrollToBottom();
    }
  }

  void _fail(int index, String message) {
    if (!mounted) return;
    setState(() {
      _messages.removeAt(index);
      _messages.add(_ChatMsg.assistant()..answer = message);
    });
  }

  /// 历史会话列表（点选恢复继续聊，可删除）。
  Future<void> _showHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        builder: (sheetCtx, controller) => Consumer(
          builder: (context, ref, _) {
            final cs = Theme.of(context).colorScheme;
            final sessions =
                ref.watch(chatSessionsProvider).valueOrNull ?? const <ChatSession>[];
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: [
                Text('历史会话', style: AppTheme.title(cs.onSurface)),
                const SizedBox(height: 8),
                if (sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('还没有保存的会话',
                          style: AppTheme.subhead(cs.onSurfaceVariant)),
                    ),
                  ),
                for (final s in sessions)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${s.petName.isEmpty ? "" : "${s.petName} · "}${s.messages.length} 条 · ${s.updatedAt.month}/${s.updatedAt.day}',
                      style: AppTheme.captionSm(cs.onSurfaceVariant),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 20, color: AppTheme.warnRed),
                      tooltip: '删除会话',
                      onPressed: () async {
                        await ref
                            .read(chatSessionRepoProvider)
                            .delete(s.id);
                        if (_sessionId == s.id) {
                          // 删除的是当前会话 → 重置为新会话。
                          if (context.mounted) _newSession();
                        }
                      },
                    ),
                    onTap: () {
                      setState(() => _loadMessages(s));
                      Navigator.pop(sheetCtx);
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(currentPetProvider);
    final cs = Theme.of(context).colorScheme;
    final config = ref.watch(aiConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI 助手', style: AppTheme.cardTitle(cs.onSurface)),
            Text(
              pet == null
                  ? '未选择宠物'
                  : '${pet.name} · ${config.isReady ? config.model : "未配置 AI"}',
              style: AppTheme.captionSm(cs.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: '新建会话',
            onPressed: _busy ? null : _newSession,
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: '历史会话',
            onPressed: _busy ? null : _showHistory,
          ),
       ],
      ),
      body: !config.isReady
          ? EmptyView(
              icon: Icons.key_outlined,
              title: 'AI 还没有配置',
              subtitle: '填写 API 地址与 Key 即可启用对话、饮食计划等能力',
              action: FilledButton(
                onPressed: () => context.push('/settings/ai'),
                child: const Text('去配置'),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _Bubble(message: _messages[index]),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            enabled: !_busy,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: const InputDecoration(
                              hintText: '问点什么…',
                              isDense: true,
                            ),
                            style: AppTheme.body(cs.onSurface),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: _busy
                              ? cs.outlineVariant
                              : AppTheme.greenLight,
                          child: IconButton(
                            icon: const Icon(Icons.send,
                                color: Colors.white, size: 20),
                            onPressed: _busy ? null : _send,
                          ),
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

/// WhatsApp 式气泡：思考区（可折叠）+ 回答区。
/// 思考展开规则：用户点过 → 跟随用户；否则回答出现前展开、之后自动折叠。
class _Bubble extends StatefulWidget {
  const _Bubble({required this.message});

  final _ChatMsg message;

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  bool? _manualExpanded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final m = widget.message;
    final isUser = m.isUser;
    final bubbleColor =
        isUser ? (dark ? AppTheme.greenBubble : AppTheme.bubbleOut) : cs.surface;
    final textColor =
        isUser ? (dark ? Colors.white : AppTheme.ink) : cs.onSurface;

    final thinkingLive =
        m.thinking.isNotEmpty && m.answer.isEmpty && m.loading;
    final expanded = _manualExpanded ?? thinkingLive;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 思考区（可折叠）。
            if (m.thinking.isNotEmpty)
              GestureDetector(
                onTap: () => setState(
                    () => _manualExpanded = !(expanded)),
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            thinkingLive
                                ? Icons.psychology_alt_rounded
                                : Icons.psychology_outlined,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              thinkingLive
                                  ? '思考中…（点击收起）'
                                  : '已深度思考（点击${expanded ? '收起' : '展开'}）',
                              style: AppTheme.captionSm(cs.onSurfaceVariant)
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Icon(
                            expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 15,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                      if (expanded)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            m.thinking,
                            style: AppTheme.caption(cs.onSurfaceVariant)
                                .copyWith(height: 1.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            // 工具查询状态。
            if (m.toolStatus != null && m.loading && m.answer.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.8)),
                    const SizedBox(width: 8),
                    Text('正在查询：${m.toolStatus}}…',
                        style: AppTheme.captionSm(cs.onSurfaceVariant)),
                  ],
                ),
              ),
            // 回答区。
            if (m.answer.isNotEmpty)
              MarkdownBody(
                data: m.answer,
                styleSheet: digestMarkdownStyle(context),
                selectable: true,
              ),
            // 纯等待（无思考无工具）：三点跳动。
            if (m.loading &&
                m.answer.isEmpty &&
                m.thinking.isEmpty &&
                m.toolStatus == null)
              const _TypingDots(),
            if (!isUser && !m.loading && m.answer.isEmpty)
              Text('（空回复）', style: AppTheme.caption(textColor)),
          ],
        ),
      ),
    );
  }
}

/// 生成中的三点跳动。
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_controller.value * 3 - i).clamp(0.0, 1.0);
            final scale = 0.6 + 0.4 * (t < 0.5 ? t * 2 : 2 - t * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
