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
    this.entity,
  });

  final String id;
  final String companyId;
  final String action;
  final String actorUid;
  final String? targetUid;
  final DateTime occurredAt;
  final Map<String, dynamic> before;
  final Map<String, dynamic> after;

  final CompanyActivityEntity? entity;

  static CompanyActivity? fromData({
    required String id,
    required Map<String, dynamic> data,
  }) {
    if (!_validId(id, maxLength: 400)) return null;
    const topLevelFields = {
      'schemaVersion',
      'companyId',
      'action',
      'actorUid',
      'targetUid',
      'entity',
      'occurredAt',
      'before',
      'after',
    };
    if (data.keys.any((key) => !topLevelFields.contains(key))) return null;

    final companyId = _id(data['companyId']);
    final action = data['action'];
    final actorUid = _id(data['actorUid']);
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
      ...contentActions,
    };
    if (data['schemaVersion'] != 1 ||
        companyId == null ||
        action is! String ||
        !actions.contains(action) ||
        actorUid == null ||
        occurredAt == null) {
      return null;
    }

    final targetValue = data['targetUid'];
    final target = targetValue == null ? null : _id(targetValue);
    if (data.containsKey('targetUid') && target == null) return null;
    final before = data.containsKey('before')
        ? _changeMap(data['before'])
        : const <String, dynamic>{};
    final after = data.containsKey('after')
        ? _changeMap(data['after'])
        : const <String, dynamic>{};
    if (before == null || after == null) return null;

    final entity = CompanyActivityEntity.fromData(data['entity']);
    if (data.containsKey('entity') != (entity != null)) return null;
    if (contentActions.contains(action) != (entity != null)) return null;
    if (!_validActionShape(
      action: action,
      actorUid: actorUid,
      targetUid: target,
      entity: entity,
      hasBefore: data.containsKey('before'),
      before: before,
      hasAfter: data.containsKey('after'),
      after: after,
    )) {
      return null;
    }
    return CompanyActivity(
      id: id,
      companyId: companyId,
      action: action,
      actorUid: actorUid,
      targetUid: target,
      occurredAt: occurredAt,
      before: before,
      after: after,
      entity: entity,
    );
  }

  static String? _id(Object? value) =>
      value is String && _validId(value, maxLength: 128) ? value : null;

  static bool _validId(String value, {required int maxLength}) =>
      value.isNotEmpty &&
      value.length <= maxLength &&
      value == value.trim() &&
      !value.contains('/');

  static Map<String, dynamic>? _changeMap(Object? value) {
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
    'confirmedStartAt' => value is Timestamp,
    _ => false,
  };

  static bool _validActionShape({
    required String action,
    required String actorUid,
    required String? targetUid,
    required CompanyActivityEntity? entity,
    required bool hasBefore,
    required Map<String, dynamic> before,
    required bool hasAfter,
    required Map<String, dynamic> after,
  }) {
    if (targetUid == actorUid) return false;

    bool state(Map<String, dynamic> value, Map<String, Object> expected) =>
        value.length == expected.length &&
        expected.entries.every((entry) => value[entry.key] == entry.value);
    bool oneOf(String key, Map<String, dynamic> value, Set<String> values) =>
        value.length == 1 && values.contains(value[key]);
    const memberships = {'active', 'pending'};
    const roles = {'user', 'moderator', 'admin', 'superadmin'};
    final noTarget = targetUid == null;
    final noState = !hasBefore && !hasAfter;

    return switch (action) {
      'member.approved' =>
        targetUid != null &&
            hasBefore &&
            state(before, const {'membership': 'pending'}) &&
            hasAfter &&
            state(after, const {'membership': 'active'}),
      'member.role_changed' =>
        targetUid != null &&
            hasBefore &&
            oneOf('role', before, roles) &&
            hasAfter &&
            oneOf('role', after, roles) &&
            before['role'] != after['role'],
      'member.banned' =>
        targetUid != null &&
            hasBefore &&
            oneOf('membership', before, memberships) &&
            hasAfter &&
            state(after, const {'membership': 'pending'}),
      'member.unbanned' =>
        targetUid != null &&
            (noState ||
                (hasBefore &&
                    state(before, const {'membership': 'pending'}) &&
                    hasAfter &&
                    oneOf('membership', after, memberships))),
      'member.removed' || 'member.company_data_erased' =>
        targetUid != null &&
            (action == 'member.company_data_erased' && noState ||
                hasBefore &&
                    before.length == 2 &&
                    roles.contains(before['role']) &&
                    memberships.contains(before['membership']) &&
                    hasAfter &&
                    state(after, const {
                      'role': 'user',
                      'membership': 'active',
                    })),
      'company.join_policy_changed' =>
        noTarget &&
            hasBefore &&
            oneOf('joinPolicy', before, const {'open', 'approval'}) &&
            hasAfter &&
            oneOf('joinPolicy', after, const {'open', 'approval'}) &&
            before['joinPolicy'] != after['joinPolicy'],
      'company.deletion_scheduled' =>
        noTarget &&
            !hasBefore &&
            hasAfter &&
            after.length == 1 &&
            after['deletionScheduledFor'] is Timestamp,
      'company.deletion_cancelled' =>
        noTarget &&
            hasBefore &&
            before.length == 1 &&
            before['deletionScheduledFor'] is Timestamp &&
            !hasAfter,
      'company.created' =>
        noTarget &&
            !hasBefore &&
            hasAfter &&
            state(after, {'ownerUid': actorUid}),
      'company.ownership_transferred' =>
        targetUid != null &&
            hasBefore &&
            state(before, {'ownerUid': actorUid}) &&
            hasAfter &&
            state(after, {'ownerUid': targetUid}),
      'account.email_changed' => noTarget && noState,
      'survey.created' || 'survey.deleted' =>
        noTarget && noState && const {'survey', 'test'}.contains(entity?.type),
      'appointment.created' || 'appointment.updated' || 'appointment.deleted' =>
        noTarget && noState && entity?.type == 'appointment',
      'appointment.slot_confirmed' =>
        noTarget &&
            !hasBefore &&
            hasAfter &&
            after.length == 1 &&
            after['confirmedStartAt'] is Timestamp &&
            entity?.type == 'appointment',
      _ => false,
    };
  }
}

const contentActions = {
  'survey.created',
  'survey.deleted',
  'appointment.created',
  'appointment.updated',
  'appointment.deleted',
  'appointment.slot_confirmed',
};

@immutable
class CompanyActivityEntity {
  const CompanyActivityEntity({
    required this.type,
    required this.id,
    required this.title,
  });

  final String type;
  final String id;

  final String title;

  static CompanyActivityEntity? fromData(Object? value) {
    if (value is! Map) return null;
    if (value.length != 3 ||
        value.keys.any((key) => !const {'type', 'id', 'title'}.contains(key))) {
      return null;
    }
    final type = value['type'];
    final id = value['id'];
    final title = value['title'];
    if (!const {'survey', 'test', 'appointment'}.contains(type) ||
        id is! String ||
        !CompanyActivity._validId(id, maxLength: 128) ||
        title is! String ||
        title.length > 120 ||
        title != title.trim()) {
      return null;
    }
    return CompanyActivityEntity(type: type as String, id: id, title: title);
  }
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
        final names = <String, String>{};
        for (final member in snapshot.docs) {
          final name = safeActivityMemberName(member.data()['fullName']);
          if (name != null) names[member.id] = name;
        }
        return Map.unmodifiable(names);
      });
}

String? safeActivityMemberName(Object? value) {
  if (value is! String || value.length > 160) return null;
  final normalized = value
      .replaceAll(
        RegExp(
          r'[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u202a-\u202e\u2060-\u206f\ufeff]',
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return normalized.isEmpty ? null : normalized;
}
