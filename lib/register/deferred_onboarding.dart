import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/notifications/notification_navigation.dart';
import 'package:echomeet/core/security/email_change_service.dart';
import 'package:echomeet/core/widgets/app_text_field.dart';
import 'package:echomeet/core/widgets/aurora_background.dart';
import 'package:echomeet/core/widgets/glass_panel.dart';
import 'package:echomeet/login/login_logics.dart';
import 'package:echomeet/register/register_logics.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:echomeet/utilities/firebase_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum DeferredOnboardingType { createCompany, joinCompany }

enum OnboardingFailure {
  companyNameTaken,
  companyNameInvalid,
  companyUnavailable,
  emailNotVerified,
  retryable,
}

class DeferredOnboardingIntent {
  const DeferredOnboardingIntent({
    required this.type,
    this.companyName,
    this.companyId,
  });

  final DeferredOnboardingType type;
  final String? companyName;
  final String? companyId;
}

class OnboardingCompanyOption {
  const OnboardingCompanyOption({required this.id, required this.name});

  final String id;
  final String name;
}

class OnboardingCompletionException implements Exception {
  const OnboardingCompletionException(this.failure);

  final OnboardingFailure failure;
}

class DeferredOnboardingService {
  DeferredOnboardingService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    EmailChangeService? emailChangeService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west4'),
       _emailChangeService =
           emailChangeService ??
           EmailChangeService(auth: auth, functions: functions);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final EmailChangeService _emailChangeService;

  Future<DeferredOnboardingIntent?> loadIntent() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const OnboardingCompletionException(
        OnboardingFailure.emailNotVerified,
      );
    }

    final intent = await _readIntent(user.uid);
    if (intent == null && user.emailVerified) {
      unawaited(_refreshVerifiedSession());
      return null;
    }

    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed?.emailVerified != true) {
      throw const OnboardingCompletionException(
        OnboardingFailure.emailNotVerified,
      );
    }
    await refreshed!.getIdToken(true);
    try {
      await _emailChangeService.syncAfterAuthenticationRefresh();
    } on EmailChangeException {
      throw const OnboardingCompletionException(OnboardingFailure.retryable);
    }

    return intent ?? await _readIntent(refreshed.uid);
  }

  Future<void> _refreshVerifiedSession() async {
    try {
      await _auth.currentUser?.getIdToken(true);
      await _emailChangeService.syncAfterAuthenticationRefresh();
    } catch (_) {}
  }

  Future<DeferredOnboardingIntent?> _readIntent(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    final data = snapshot.data();
    final type = data?['pendingOnboardingType'];
    if (type == 'createCompany') {
      return DeferredOnboardingIntent(
        type: DeferredOnboardingType.createCompany,
        companyName: (data?['pendingCompanyName'] as String?)?.trim(),
      );
    }
    if (type == 'joinCompany') {
      return DeferredOnboardingIntent(
        type: DeferredOnboardingType.joinCompany,
        companyId: (data?['pendingCompanyId'] as String?)?.trim(),
      );
    }
    return null;
  }

  Future<void> complete({String? companyName, String? companyId}) async {
    try {
      final callable = _functions.httpsCallable(
        'completeOnboarding',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final payload = <String, String>{};
      if (companyName?.trim().isNotEmpty == true) {
        payload['companyName'] = companyName!.trim();
      }
      if (companyId?.trim().isNotEmpty == true) {
        payload['companyId'] = companyId!.trim();
      }
      final result = await callable.call<Map<String, dynamic>>(payload);
      if (result.data['completed'] != true) {
        throw const OnboardingCompletionException(OnboardingFailure.retryable);
      }
    } on FirebaseFunctionsException catch (error) {
      throw OnboardingCompletionException(switch (error.message) {
        'company-name-taken' => OnboardingFailure.companyNameTaken,
        'company-name-invalid' => OnboardingFailure.companyNameInvalid,
        'company-unavailable' ||
        'company-closing' ||
        'company-banned' => OnboardingFailure.companyUnavailable,
        'email-not-verified' => OnboardingFailure.emailNotVerified,
        _ => OnboardingFailure.retryable,
      });
    }
  }

  Future<List<OnboardingCompanyOption>> companies() async {
    final snapshot = await _firestore.collection('companyDirectory').get();
    final result = <OnboardingCompanyOption>[];
    for (final document in snapshot.docs) {
      final name = (document.data()['name'] as String? ?? '').trim();
      if (name.isNotEmpty) {
        result.add(OnboardingCompanyOption(id: document.id, name: name));
      }
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }
}

/// Blocks tenant screens until the verified registration transaction commits.
/// Reopening the app simply re-runs the same persisted private intent.
class DeferredOnboardingGate extends StatefulWidget {
  const DeferredOnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  State<DeferredOnboardingGate> createState() => _DeferredOnboardingGateState();
}

class _DeferredOnboardingGateState extends State<DeferredOnboardingGate> {
  /// The account this gate has already cleared, for this run of the app.
  ///
  /// The gate wraps every protected route, so it remounts on each navigation.
  /// Without this it repeated a Firestore read and flashed the full-screen
  /// "Finishing registration" panel on the way into settings, the survey list
  /// and every wizard step — long enough to see, too short to read, and
  /// meaningless to somebody who registered weeks ago.
  ///
  /// Keyed by uid rather than a bare flag, so signing in as a different account
  /// is checked properly. Onboarding happens once per account, so a resolved
  /// uid stays resolved.
  static String? _resolvedForUid;

  final _service = DeferredOnboardingService();
  final _companyNameController = TextEditingController();

  DeferredOnboardingIntent? _intent;
  OnboardingFailure? _failure;
  List<OnboardingCompanyOption> _companies = const [];
  String? _selectedCompanyId;
  late bool _loading = !_alreadyResolved;
  late bool _completed = _alreadyResolved;

  bool get _alreadyResolved {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && uid == _resolvedForUid;
  }

  @override
  void initState() {
    super.initState();
    _companyNameController.addListener(_nameChanged);
    if (_completed) {
      // Nothing left to finish, but the work `_finish` schedules still has to
      // happen: a notification tap waiting to be replayed once a navigator
      // exists, and a profile photo chosen during registration that has not
      // been uploaded yet. Skipping straight to the child dropped both.
      _scheduleReadyWork();
      return;
    }
    unawaited(_resume());
  }

  void _scheduleReadyWork() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NotificationNavigation.appReady();
      unawaited(_uploadPendingProfileImage());
    });
  }

  void _nameChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    super.dispose();
  }

  Future<void> _resume({String? companyName, String? companyId}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _failure = null;
      });
    }

    try {
      final intent = _intent ?? await _service.loadIntent();
      if (intent == null) {
        _finish();
        return;
      }
      _intent = intent;
      if (_companyNameController.text.isEmpty && intent.companyName != null) {
        _companyNameController.text = intent.companyName!;
      }
      await _service.complete(companyName: companyName, companyId: companyId);
      _finish();
    } on OnboardingCompletionException catch (error) {
      if (!mounted) return;
      var companies = _companies;
      if (error.failure == OnboardingFailure.companyUnavailable &&
          companies.isEmpty) {
        try {
          companies = await _service.companies();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _companies = companies;
        _failure = error.failure;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failure = OnboardingFailure.retryable;
        _loading = false;
      });
    }
  }

  void _finish() {
    FirebaseServices.invalidateCache();
    // Remember for the rest of this run, so navigating anywhere else does not
    // repeat the read or show the panel again.
    _resolvedForUid = FirebaseAuth.instance.currentUser?.uid;
    if (!mounted) return;
    setState(() {
      _completed = true;
      _loading = false;
      _failure = null;
    });
    _scheduleReadyWork();
  }

  Future<void> _uploadPendingProfileImage() async {
    final registration = context.read<RegisterLogic>();
    if (!registration.hasPendingProfileImage) return;
    final result = await registration.uploadPendingProfileImage();
    if (result.succeeded || !mounted) return;
    UIUtils.showSnackBar(context, result.errorKey!.tr(), isError: true);
  }

  Future<void> _signOut() async {
    final signedOut = await AuthManager().signOut();
    if (!mounted) return;
    if (!signedOut) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) return widget.child;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: PageBody(
            maxWidth: 500,
            centerVertically: true,
            child: GlassPanel(
              padding: const EdgeInsets.all(Spacing.xl),
              child: _loading ? _loadingView() : _resolver(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingView() {
    final finishing = _intent != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: Spacing.lg),
        Text(
          (finishing ? 'finishing_registration' : 'signing_in').tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (finishing) ...[
          const SizedBox(height: Spacing.sm),
          Text('finishing_registration_body'.tr(), textAlign: TextAlign.center),
        ],
      ],
    );
  }

  Widget _resolver() {
    final failure = _failure ?? OnboardingFailure.retryable;
    final nameFailure =
        failure == OnboardingFailure.companyNameTaken ||
        failure == OnboardingFailure.companyNameInvalid;
    final joinFailure = failure == OnboardingFailure.companyUnavailable;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.sync_problem_rounded,
          size: 42,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: Spacing.md),
        Text(
          (nameFailure
                  ? 'onboarding_name_conflict_title'
                  : joinFailure
                  ? 'onboarding_company_unavailable_title'
                  : 'onboarding_retry_title')
              .tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          (nameFailure
                  ? 'onboarding_name_conflict_body'
                  : joinFailure
                  ? 'onboarding_company_unavailable_body'
                  : 'onboarding_retry_body')
              .tr(),
          textAlign: TextAlign.center,
        ),
        if (nameFailure) ...[
          const SizedBox(height: Spacing.lg),
          AppTextField(
            label: 'company_name'.tr(),
            controller: _companyNameController,
            icon: Icons.business_outlined,
          ),
        ],
        if (joinFailure && _companies.isNotEmpty) ...[
          const SizedBox(height: Spacing.lg),
          DropdownButtonFormField<String>(
            initialValue: _selectedCompanyId,
            decoration: InputDecoration(labelText: 'select_company'.tr()),
            items: [
              for (final company in _companies)
                DropdownMenuItem(value: company.id, child: Text(company.name)),
            ],
            onChanged: (value) => setState(() => _selectedCompanyId = value),
          ),
        ],
        if (joinFailure && _companies.isEmpty) ...[
          const SizedBox(height: Spacing.lg),
          Text('no_companies_yet'.tr(), textAlign: TextAlign.center),
        ],
        const SizedBox(height: Spacing.xl),
        GlowButton(
          onPressed:
              (nameFailure && _companyNameController.text.trim().isEmpty) ||
                  (joinFailure && _selectedCompanyId == null)
              ? null
              : () {
                  if (nameFailure) {
                    final name = _companyNameController.text.trim();
                    if (name.isEmpty) return;
                    unawaited(_resume(companyName: name));
                    return;
                  }
                  if (joinFailure) {
                    final id = _selectedCompanyId;
                    if (id == null) return;
                    unawaited(_resume(companyId: id));
                    return;
                  }
                  unawaited(_resume());
                },
          label: (nameFailure || joinFailure ? 'continue' : 'retry').tr(),
        ),
        const SizedBox(height: Spacing.sm),
        TextButton(onPressed: _signOut, child: Text('back_to_login'.tr())),
      ],
    );
  }
}
