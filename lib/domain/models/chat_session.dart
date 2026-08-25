/// AI 对话会话（含全部消息，整存整取）。
class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    required this.petId,
    required this.petName,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// 首条用户消息截断，列表展示用。
  final String title;
  final String petId;
  final String petName;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession copyWith({
    String? title,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
  }) =>
      ChatSession(
        id: id,
        title: title ?? this.title,
        petId: petId,
        petName: petName,
        messages: messages ?? this.messages,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// 单条消息：思考与回答分离持久化。
class ChatMessage {
  ChatMessage({required this.isUser, required this.answer, this.thinking = ''});

  final bool isUser;
  final String answer;
  final String thinking;

  Map<String, dynamic> toJson() =>
      {'isUser': isUser, 'answer': answer, 'thinking': thinking};

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        isUser: json['isUser'] as bool? ?? false,
        answer: json['answer'] as String? ?? '',
        thinking: json['thinking'] as String? ?? '',
      );
}
