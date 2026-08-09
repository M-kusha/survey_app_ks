import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum MembershipState { noCompany, pending, banned, active }

@immutable
class CompanySummary {
  const CompanySummary({
    required this.id,
    required this.name,
    required this.joinPolicy,
  });

  final String id;
  final String name;

  final String joinPolicy;

  bool get needsApproval => joinPolicy == 'approval';
}

@immutable
class Membership {
  const Membership({
    required this.state,
    this.companyId = '',
    this.companyName = '',
    this.deletionAt,
  });

  static const unknown = Membership(state: MembershipState.noCompany);

  final MembershipState state;
  final String companyId;
  final String companyName;

  final DateTime? deletionAt;

  bool get isClosing => deletionAt != null;

  bool get isActive => state == MembershipState.active;
}

class MembershipService {
  MembershipService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  Future<Membership> resolve() async {
    final uid = _uid;
    if (uid == null) return Membership.unknown;

    final profile = await _db.collection('users').doc(uid).get();
    final data = profile.data();
    final companyId = (data?['companyId'] as String? ?? '').trim();

    if (companyId.isEmpty) {
      return const Membership(state: MembershipState.noCompany);
    }

    final company = await _db.collection('companies').doc(companyId).get();
    final companyName = (company.data()?['name'] as String? ?? '').trim();
    final deletionAt = (company.data()?['deletionScheduledFor'] as Timestamp?)
        ?.toDate();

    final ban = await _db
        .collection('companies')
        .doc(companyId)
        .collection('bans')
        .doc(uid)
        .get();

    if (ban.exists) {
      return Membership(
        state: MembershipState.banned,
        companyId: companyId,
        companyName: companyName,
        deletionAt: deletionAt,
      );
    }

    final membership = data?['membership'] as String? ?? 'active';

    return Membership(
      state: membership == 'pending'
          ? MembershipState.pending
          : MembershipState.active,
      companyId: companyId,
      companyName: companyName,
      deletionAt: deletionAt,
    );
  }

  Future<List<CompanySummary>> searchCompanies(String query) async {
    final snapshot = await _db.collection('companies').get();
    final needle = query.trim().toLowerCase();

    final companies = snapshot.docs
        .map(
          (doc) => CompanySummary(
            id: doc.id,
            name: (doc.data()['name'] as String? ?? '').trim(),

            joinPolicy: doc.data()['joinPolicy'] as String? ?? 'open',
          ),
        )
        .where(
          (company) =>
              company.name.isNotEmpty &&
              (needle.isEmpty || company.name.toLowerCase().contains(needle)),
        )
        .toList();

    companies.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return companies;
  }

  Future<Set<String>> bannedCompanyIds(List<String> companyIds) async {
    final uid = _uid;
    if (uid == null) return {};

    final results = await Future.wait([
      for (final id in companyIds)
        _db
            .collection('companies')
            .doc(id)
            .collection('bans')
            .doc(uid)
            .get()
            .then((doc) => doc.exists ? id : null)
            .catchError((_) => null),
    ]);

    return results.whereType<String>().toSet();
  }

  Future<MembershipState> joinCompany(CompanySummary company) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in.');

    final status = company.needsApproval ? 'pending' : 'active';

    await _db.collection('users').doc(uid).update({
      'companyId': company.id,
      'role': 'user',
      'membership': status,
    });

    return status == 'pending'
        ? MembershipState.pending
        : MembershipState.active;
  }

  Future<void> leaveCompany() async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in.');

    await _db.collection('users').doc(uid).update({
      'companyId': '',
      'role': 'user',
      'membership': 'active',
    });
  }
}

class MembershipProvider extends ChangeNotifier {
  MembershipProvider({MembershipService? service})
    : _service = service ?? MembershipService();

  final MembershipService _service;

  Membership? _membership;
  bool _loading = false;

  Membership? get membership => _membership;
  bool get loading => _loading;

  bool get isActive => _membership?.isActive ?? false;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();

    try {
      _membership = await _service.resolve();
    } catch (_) {
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
