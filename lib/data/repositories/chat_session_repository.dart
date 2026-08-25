import 'package:drift/drift.dart';

import '../../domain/models/chat_session.dart';
import '../db/app_database.dart';

/// AI 对话会话仓库。
class ChatSessionRepository {
  ChatSessionRepository(this._db);

  final AppDatabase _db;

  /// 全部会话（最近更新在前）。
  Stream<List<ChatSession>> watchAll() {
    final query = _db.select(_db.chatSessions)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch().map(
        (rows) => rows.map(AppDatabase.toChatSession).toList());
  }

  Future<List<ChatSession>> getAll() async {
    final query = _db.select(_db.chatSessions)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(AppDatabase.toChatSession).toList();
  }

  Future<ChatSession?> getLatest() async {
    final all = await getAll();
    return all.isEmpty ? null : all.first;
  }

  Future<void> upsert(ChatSession session) async {
    await _db.into(_db.chatSessions).insertOnConflictUpdate(
        AppDatabase.toChatSessionsCompanion(session));
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.chatSessions)..where((t) => t.id.equals(id))).go();
  }
}
