import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/core/membership/member_directory.dart';
import 'package:echomeet/core/membership/ownership_transfer_service.dart';
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
    this.joinPolicy = 'open',
    this.deletionAt,
    this.ownershipTransfer,
  });

  static const unknown = Membership(state: MembershipState.noCompany);

  final MembershipState state;
  final String companyId;
  final String companyName;
  final String joinPolicy;

  final DateTime? deletionAt;
  final OwnershipTransferOffer? ownershipTransfer;

  bool get isClosing => deletionAt != null;

  bool get isActive => state == MembershipState.active;

  bool get isOpenToJoin => joinPolicy != 'approval';
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
    final companyData = company.data();
    final companyName = (companyData?['name'] as String? ?? '').trim();
    final joinPolicy = companyData?['joinPolicy'] as String? ?? 'open';
    final deletionAt = (companyData?['deletionScheduledFor'] as Timestamp?)
        ?.toDate();
    final ownershipTransfer = companyData == null
        ? null
        : OwnershipTransferOffer.fromCompanyData(companyData);

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
        joinPolicy: joinPolicy,
        deletionAt: deletionAt,
        ownershipTransfer: ownershipTransfer,
      );
    }

    final membership = data?['membership'] as String? ?? 'active';

    return Membership(
      state: membership == 'pending'
          ? MembershipState.pending
          : MembershipState.active,
      companyId: companyId,
      companyName: companyName,
      joinPolicy: joinPolicy,
      deletionAt: deletionAt,
      ownershipTransfer: ownershipTransfer,
    );
  }

  Future<List<CompanySummary>> searchCompanies(String query) async {
    final snapshot = await _db.collection('companyDirectory').get();
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

    await MemberDirectory.updateOwnProfile(
      firestore: _db,
      userId: uid,
      fields: {'companyId': company.id, 'role': 'user', 'membership': status},
    );

    return status == 'pending'
        ? MembershipState.pending
        : MembershipState.active;
  }

  Future<void> leaveCompany() async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in.');

    await MemberDirectory.removeMember(firestore: _db, userId: uid);
  }
}

class MembershipProvider extends ChangeNotifier {
  MembershipProvider({
    MembershipService? service,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _db = firestore ?? service?._db ?? FirebaseFirestore.instance,
       _auth = auth ?? service?._auth ?? FirebaseAuth.instance {
    _watchUser(_auth.currentUser?.uid);
    _authSubscription = _auth.authStateChanges().listen(
      (user) => _watchUser(user?.uid),
    );
  }

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _companySubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _banSubscription;

  int _generation = 0;
  int _companyGeneration = 0;
  String? _userId;
  String _companyId = '';
  String _profileMembership = 'active';
  String _companyName = '';
  String _joinPolicy = 'open';
  DateTime? _deletionAt;
  OwnershipTransferOffer? _ownershipTransfer;
  bool _companyExists = false;
  bool _companySeen = false;
  bool _banSeen = false;
  bool _banned = false;
  bool _disposed = false;

  Membership? _membership;
  bool _loading = false;
  Object? _error;

  Membership? get membership => _membership;
  bool get loading => _loading;
  Object? get error => _error;

  bool get isActive => _membership?.isActive ?? false;

  void _watchUser(String? userId, {bool force = false}) {
    if (_disposed) return;
    if (!force && _userId == userId && _profileSubscription != null) return;

    final generation = ++_generation;
    _userId = userId;
    _cancelDataSubscriptions();
    _resetCompanyState();
    _error = null;

    if (userId == null || userId.isEmpty) {
      _membership = Membership.unknown;
      _loading = false;
      _notify();
      return;
    }

    _membership = null;
    _loading = true;
    _notify();

    _profileSubscription = _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (profile) => _handleProfile(profile, generation),
          onError: (Object error) => _handleError(error, generation),
        );
  }

  void _handleProfile(
    DocumentSnapshot<Map<String, dynamic>> profile,
    int generation,
  ) {
    if (_disposed || generation != _generation) return;

    final data = profile.data();
    final companyId = (data?['companyId'] as String? ?? '').trim();
    _profileMembership = data?['membership'] as String? ?? 'active';

    if (companyId == _companyId) {
      _recomputeMembership();
      return;
    }

    final companySubscription = _companySubscription;
    final banSubscription = _banSubscription;
    final companyGeneration = ++_companyGeneration;
    _companySubscription = null;
    _banSubscription = null;
    unawaited(companySubscription?.cancel());
    unawaited(banSubscription?.cancel());

    _companyId = companyId;
    _companyName = '';
    _joinPolicy = 'open';
    _deletionAt = null;
    _ownershipTransfer = null;
    _companyExists = false;
    _companySeen = companyId.isEmpty;
    _banSeen = companyId.isEmpty;
    _banned = false;

    if (companyId.isEmpty) {
      _recomputeMembership();
      return;
    }

    final userId = _userId!;
    _companySubscription = _db
        .collection('companies')
        .doc(companyId)
        .snapshots()
        .listen(
          (company) {
            if (_disposed ||
                generation != _generation ||
                companyGeneration != _companyGeneration ||
                companyId != _companyId) {
              return;
            }
            final companyData = company.data();
            _companySeen = true;
            _companyExists = company.exists;
            _companyName = (companyData?['name'] as String? ?? '').trim();
            _joinPolicy = companyData?['joinPolicy'] as String? ?? 'open';
            _deletionAt = (companyData?['deletionScheduledFor'] as Timestamp?)
                ?.toDate();
            _ownershipTransfer = companyData == null
                ? null
                : OwnershipTransferOffer.fromCompanyData(companyData);
            _recomputeMembership();
          },
          onError: (Object error) {
            if (companyGeneration != _companyGeneration) return;
            _handleError(error, generation);
          },
        );
    _banSubscription = _db
        .collection('companies')
        .doc(companyId)
        .collection('bans')
        .doc(userId)
        .snapshots()
        .listen(
          (ban) {
            if (_disposed ||
                generation != _generation ||
                companyGeneration != _companyGeneration ||
                companyId != _companyId) {
              return;
            }
            _banSeen = true;
            _banned = ban.exists;
            _recomputeMembership();
          },
          onError: (Object error) {
            if (companyGeneration != _companyGeneration) return;
            _handleError(error, generation);
          },
        );
  }

  void _recomputeMembership() {
    if (_companyId.isEmpty) {
      _membership = const Membership(state: MembershipState.noCompany);
      _loading = false;
      _error = null;
      _notify();
      return;
    }

    if (!_companySeen || !_banSeen) {
      _loading = true;
      _notify();
      return;
    }

    final state = !_companyExists
        ? MembershipState.noCompany
        : _banned
        ? MembershipState.banned
        : _profileMembership == 'pending'
        ? MembershipState.pending
        : MembershipState.active;

    _membership = Membership(
      state: state,
      companyId: _companyId,
      companyName: _companyName,
      joinPolicy: _joinPolicy,
      deletionAt: _deletionAt,
      ownershipTransfer: _ownershipTransfer,
    );
    _loading = false;
    _error = null;
    _notify();
  }

  void _handleError(Object error, int generation) {
    if (generation != _generation) return;
    _error = error;
    _loading = false;
    _notify();
  }

  void _resetCompanyState() {
    ++_companyGeneration;
    _companyId = '';
    _profileMembership = 'active';
    _companyName = '';
    _joinPolicy = 'open';
    _deletionAt = null;
    _ownershipTransfer = null;
    _companyExists = false;
    _companySeen = false;
    _banSeen = false;
    _banned = false;
  }

  void _cancelDataSubscriptions() {
    final profileSubscription = _profileSubscription;
    final companySubscription = _companySubscription;
    final banSubscription = _banSubscription;
    _profileSubscription = null;
    _companySubscription = null;
    _banSubscription = null;
    unawaited(profileSubscription?.cancel());
    unawaited(companySubscription?.cancel());
    unawaited(banSubscription?.cancel());
  }

  Future<void> refresh() async {
    _watchUser(_auth.currentUser?.uid, force: true);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    ++_companyGeneration;
    unawaited(_authSubscription?.cancel());
    _cancelDataSubscriptions();
    super.dispose();
  }
}
