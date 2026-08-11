import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class CompanyActivity {
  const CompanyActivity({
    required this.id,
    required this.companyId,
    required this.action,
    required this.actorUid,
    required this.occurredAt,
    required this.before,
    required this.after,
    this.targetUid,
  });

  final String id;
  final String companyId;
  final String action;
  final String actorUid;
  final String? targetUid;
  final DateTime occurredAt;
  final Map<String, dynamic> before;
  final Map<String, dynamic> after;

  static CompanyActivity? fromData({
    required String id,
    required Map<String, dynamic> data,
  }) {
    const topLevelFields = {
      'schemaVersion',
      'companyId',
      'action',
      'actorUid',
      'targetUid',
      'occurredAt',
      'before',
      'after',
    };
    if (data.keys.any((key) => !topLevelFields.contains(key))) return null;

    final companyId = _string(data['companyId']);
    final action = _string(data['action']);
    final actorUid = _string(data['actorUid']);
    final occurredAt = data['occurredAt'] is Timestamp
        ? (data['occurredAt'] as Timestamp).toDate()
        : null;
    const actions = {
      'member.approved',
      'member.role_changed',
      'member.banned',
      'member.unbanned',
      'member.removed',
      'member.company_data_erased',
      'company.join_policy_changed',
      'company.deletion_scheduled',
      'company.deletion_cancelled',
      'company.created',
      'company.ownership_transferred',
      'account.email_changed',
    };
    if (data['schemaVersion'] != 1 ||
        companyId.isEmpty ||
        !actions.contains(action) ||
        actorUid.isEmpty ||
        occurredAt == null) {
      return null;
    }

    final targetValue = data['targetUid'];
    if (targetValue != null &&
        (targetValue is! String || targetValue.trim().isEmpty)) {
      return null;
    }
    final before = _changeMap(data['before']);
    final after = _changeMap(data['after']);
    if (before == null || after == null) return null;

    final target = targetValue is String ? targetValue.trim() : '';
    const targetActions = {
      'member.approved',
      'member.role_changed',
      'member.banned',
      'member.unbanned',
      'member.removed',
      'member.company_data_erased',
      'company.ownership_transferred',
    };
    if (targetActions.contains(action) && target.isEmpty) return null;
    return CompanyActivity(
      id: id,
      companyId: companyId,
      action: action,
      actorUid: actorUid,
      targetUid: target.isEmpty ? null : target,
      occurredAt: occurredAt,
      before: before,
      after: after,
    );
  }

  static String _string(Object? value) => value is String ? value.trim() : '';

  static Map<String, dynamic>? _changeMap(Object? value) {
    if (value == null) return const {};
    if (value is! Map) return null;

    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String || !_validChange(key, entry.value)) return null;
      result[key] = entry.value;
    }
    return Map.unmodifiable(result);
  }

  static bool _validChange(String key, Object? value) => switch (key) {
    'role' =>
      value is String &&
          const {'user', 'moderator', 'admin', 'superadmin'}.contains(value),
    'membership' =>
      value is String && const {'active', 'pending'}.contains(value),
    'joinPolicy' =>
      value is String && const {'open', 'approval'}.contains(value),
    'ownerUid' => value is String && value.trim().isNotEmpty,
    'deletionScheduledFor' => value is Timestamp,
    _ => false,
  };
}

@immutable
class CompanyActivityPageData {
  const CompanyActivityPageData({
    required this.entries,
    required this.hasMore,
    this.cursor,
  });

  final List<CompanyActivity> entries;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
}

class CompanyActivityService {
  CompanyActivityService({FirebaseFirestore? firestore})
    : _providedFirestore = firestore;

  static const pageSize = 25;

  final FirebaseFirestore? _providedFirestore;
  FirebaseFirestore get _db => _providedFirestore ?? FirebaseFirestore.instance;

  Future<CompanyActivityPageData> loadPage(
    String companyId, {
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection('companies')
        .doc(companyId)
        .collection('activity')
        .orderBy('occurredAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(pageSize);
    if (after != null) query = query.startAfterDocument(after);

    final snapshot = await query.get();
    final visibleDocuments = snapshot.docs;
    final entries = <CompanyActivity>[];
    for (final document in visibleDocuments) {
      final entry = CompanyActivity.fromData(
        id: document.id,
        data: document.data(),
      );
      if (entry != null && entry.companyId == companyId) entries.add(entry);
    }

    return CompanyActivityPageData(
      entries: List.unmodifiable(entries),
      hasMore: snapshot.docs.length == pageSize,
      cursor: visibleDocuments.isEmpty ? null : visibleDocuments.last,
    );
  }

  Stream<Map<String, String>> watchMemberNames(String companyId) => _db
      .collection('memberDirectory')
      .where('companyId', isEqualTo: companyId)
      .snapshots()
      .map((snapshot) {
        return Map.unmodifiable({
          for (final member in snapshot.docs)
            if ((member.data()['fullName'] as String? ?? '').trim().isNotEmpty)
              member.id: (member.data()['fullName'] as String).trim(),
        });
      });
}
