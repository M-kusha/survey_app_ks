import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/membership/company_admin_service.dart';
import 'package:echomeet/core/profile/authenticated_profile_image.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/status_pill.dart';
import 'package:echomeet/survey_pages/utilities/firebase_survey_service.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:echomeet/utilities/firebase_services.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:flutter/material.dart';

const _assignableRoles = ['admin', 'moderator', 'user'];

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key, required this.userId});

  final String userId;

  @override
  UserManagementPageState createState() => UserManagementPageState();
}

class UserManagementPageState extends State<UserManagementPage> {
  final _service = FirebaseSurveyService();
  final _searchController = TextEditingController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _membersSubscription;

  List<UserModel> _users = [];
  Set<String> _bannedUserIds = {};
  bool _loading = true;
  String? _errorKey;
  int _loadGeneration = 0;

  bool _canManagePeople = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    ++_loadGeneration;
    unawaited(_membersSubscription?.cancel());
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final previousSubscription = _membersSubscription;
    _membersSubscription = null;
    setState(() {
      _loading = true;
      _errorKey = null;
    });

    try {
      await previousSubscription?.cancel();
      if (!mounted || generation != _loadGeneration) return;

      final companyId = await FirebaseServices().currentCompanyId();
      if (!mounted || generation != _loadGeneration) return;

      if (companyId == null) {
        setState(() {
          _errorKey = 'no_company_on_profile';
          _loading = false;
        });
        return;
      }

      final canManagePeople = await FirebaseServices().canManagePeople();
      if (!mounted || generation != _loadGeneration) return;

      final banned = {
        for (final member in await CompanyAdminService().bannedMembers(
          companyId,
        ))
          member.userId,
      };
      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _canManagePeople = canManagePeople;
        _bannedUserIds = banned;
      });

      _membersSubscription = _service
          .watchUsersByCompanyId(companyId)
          .listen(
            (snapshot) => _applyMembers(snapshot, generation),
            onError: (Object _) => _handleMembersError(generation),
          );
    } catch (_) {
      _handleMembersError(generation);
    }
  }

  void _applyMembers(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int generation,
  ) {
    if (!mounted || generation != _loadGeneration) return;

    try {
      final users =
          snapshot.docs
              .map(UserModel.fromFirestore)
              .map((user) => user..banned = _bannedUserIds.contains(user.id))
              .toList()
            ..sort((a, b) {
              final rank = _rank(a.role).compareTo(_rank(b.role));
              return rank != 0
                  ? rank
                  : a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
      setState(() {
        _users = users;
        _loading = false;
        _errorKey = null;
      });
    } catch (_) {
      _handleMembersError(generation);
    }
  }

  void _handleMembersError(int generation) {
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _errorKey = 'error_occurred';
      _loading = false;
    });
  }

  static int _rank(String role) => switch (role) {
    'superadmin' => 0,
    'admin' => 1,
    'moderator' => 2,
    _ => 3,
  };

  List<UserModel> get _visible {
    final needle = _searchController.text.trim().toLowerCase();
    if (needle.isEmpty) return _users;
    return _users
        .where((user) => user.name.toLowerCase().contains(needle))
        .toList();
  }

  Future<void> _changeRole(UserModel user, String role) async {
    final previous = user.role;

    setState(() => user.role = role);

    try {
      await _service.updateUserRole(user.id, role);
    } catch (_) {
      if (!mounted) return;
      setState(() => user.role = previous);
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    }
  }

  Future<void> _ban(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ban_user'.tr()),
        content: Text('ban_user_confirm'.tr(namedArgs: {'name': user.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('ban_user'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _bannedUserIds.add(user.id);
      user.banned = true;
    });

    try {
      await CompanyAdminService().ban(
        companyId: user.companyId,
        userId: user.id,
        name: user.name,
        previousMembership: user.membership,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bannedUserIds.remove(user.id);
        for (final entry in _users) {
          if (entry.id == user.id) entry.banned = false;
        }
      });
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    }
  }

  Future<void> _approve(UserModel user) async {
    setState(() => user.membership = 'active');

    try {
      await CompanyAdminService().approve(user.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => user.membership = 'pending');
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    }
  }

  Future<void> _remove(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('remove_from_company'.tr()),
        content: Text(
          'remove_from_company_confirm'.tr(namedArgs: {'name': user.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('remove'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _service.removeUserFromCompany(user.id);
      if (!mounted) return;

      setState(() => _users.removeWhere((entry) => entry.id == user.id));
    } catch (_) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _visible;

    return Scaffold(
      appBar: AppBar(title: Text('user_management'.tr())),
      body: SafeArea(
        child: PageBody(
          maxWidth: 640,
          scrollable: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Spacing.sm),
              SearchPill(
                controller: _searchController,
                hint: 'search_hint'.tr(),
              ),
              const SizedBox(height: Spacing.md),
              Expanded(child: _buildBody(users)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<UserModel> users) {
    if (_loading) {
      return const Center(child: CustomLoadingWidget(loadingText: 'loading'));
    }

    if (_errorKey case final errorKey?) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'error_occurred'.tr(),
        body: errorKey == 'no_company_on_profile' ? errorKey.tr() : null,
        action: TextButton(onPressed: _load, child: Text('retry'.tr())),
      );
    }

    if (users.isEmpty) {
      return EmptyState(
        icon: Icons.person_search_rounded,
        title: _searchController.text.isEmpty
            ? 'user_list_empty'.tr()
            : 'no_search_results'.tr(),
        action: _searchController.text.isEmpty
            ? null
            : TextButton(
                onPressed: _searchController.clear,
                child: Text('clear_search'.tr()),
              ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: Spacing.xxl),
      itemCount: users.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
      itemBuilder: (context, index) {
        if (index == 0) {
          return SectionLabel(label: 'total_users'.tr(), count: _users.length);
        }

        final user = users[index - 1];
        return _UserRow(
          user: user,
          isSelf: user.id == widget.userId,
          canManagePeople: _canManagePeople,
          onRoleChanged: (role) => _changeRole(user, role),
          onBan: () => _ban(user),
          onApprove: () => _approve(user),
          onRemove: () => _remove(user),
        );
      },
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.isSelf,
    required this.canManagePeople,
    required this.onRoleChanged,
    required this.onBan,
    required this.onApprove,
    required this.onRemove,
  });

  final UserModel user;
  final bool isSelf;
  final bool canManagePeople;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onBan;
  final VoidCallback onApprove;
  final VoidCallback onRemove;

  bool get _locked => isSelf || user.role == 'superadmin' || !canManagePeople;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ContentCard(
      child: Row(
        children: [
          _Avatar(user: user),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.isEmpty ? user.id : user.name,
                  style: theme.textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isSelf)
                  Text(
                    'you'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),

                if (user.banned) ...[
                  const SizedBox(height: Spacing.xs),
                  StatusPill(
                    label: 'banned'.tr(),
                    tone: StatusTone.danger,
                    icon: Icons.block_rounded,
                  ),
                ] else if (user.isPending) ...[
                  const SizedBox(height: Spacing.xs),
                  StatusPill(
                    label: 'approval_pending'.tr(),
                    tone: StatusTone.caution,
                    icon: Icons.hourglass_top_rounded,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),

          if (user.isPending && canManagePeople && !user.banned) ...[
            FilledButton.tonal(
              onPressed: onApprove,
              child: Text('approve'.tr()),
            ),
            const SizedBox(width: Spacing.xs),
          ] else if (_locked)
            StatusPillFor(role: user.role)
          else
            _RoleMenu(role: user.role, onSelected: onRoleChanged),
          if (!_locked) ...[
            const SizedBox(width: Spacing.xs),
            PopupMenuButton<VoidCallback>(
              tooltip: 'more'.tr(),
              onSelected: (action) => action(),
              icon: Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: onBan,
                  child: Row(
                    children: [
                      Icon(
                        user.banned
                            ? Icons.lock_open_rounded
                            : Icons.block_rounded,
                        size: 18,
                        color: scheme.error,
                      ),
                      const SizedBox(width: Spacing.md),
                      Text('ban_user'.tr()),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: onRemove,
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_remove_outlined,
                        size: 18,
                        color: scheme.error,
                      ),
                      const SizedBox(width: Spacing.md),
                      Text(
                        'remove_from_company'.tr(),
                        style: TextStyle(color: scheme.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class StatusPillFor extends StatelessWidget {
  const StatusPillFor({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: scheme.surfaceContainerHighest,
      ),
      child: Text(
        'role_$role'.tr(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _RoleMenu extends StatelessWidget {
  const _RoleMenu({required this.role, required this.onSelected});

  final String role;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PopupMenuButton<String>(
      initialValue: role,
      tooltip: 'role'.tr(),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final value in _assignableRoles)
          PopupMenuItem(
            value: value,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: value == role
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: scheme.primary,
                        )
                      : null,
                ),
                Text('role_$value'.tr()),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: scheme.primary.withValues(alpha: 0.12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'role_$role'.tr(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final source = user.name.trim();
    final initial = source.isEmpty ? '?' : source[0].toUpperCase();

    return ClipOval(
      child: SizedBox(
        height: 38,
        width: 38,
        child: ColoredBox(
          color: scheme.primaryContainer,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Text(
                  initial,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              AuthenticatedProfileImage(
                storedReference: user.profileImage,
                refreshKey: user.profileImageRevision,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
