import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/membership/company_admin_service.dart';
import 'package:echomeet/core/membership/company_browser.dart';
import 'package:echomeet/core/membership/membership.dart';
import 'package:echomeet/core/membership/company_privilege_service.dart';
import 'package:echomeet/core/membership/ownership_transfer_service.dart';
import 'package:echomeet/core/files/text_download.dart';
import 'package:echomeet/core/navigation/public_routes.dart';
import 'package:echomeet/settings/banned_members.dart';
import 'package:echomeet/settings/data_export.dart';
import 'package:echomeet/settings/data_export_service.dart';
import 'package:echomeet/settings/change_email.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/localization/app_locales.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/login/login.dart';
import 'package:echomeet/login/login_logics.dart';
import 'package:echomeet/settings/administrative_activity.dart';
import 'package:echomeet/settings/biometrics_options.dart';
import 'package:echomeet/settings/create_company.dart';
import 'package:echomeet/settings/delete_account.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/settings/notifications_options.dart';
import 'package:echomeet/settings/ownership_transfer.dart';
import 'package:echomeet/settings/password_change.dart';
import 'package:echomeet/settings/profile_section.dart';
import 'package:echomeet/settings/settings_kit.dart';
import 'package:echomeet/settings/user_menagment.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsPageUI extends StatefulWidget {
  final AdaptiveThemeMode? savedThemeMode;

  const SettingsPageUI({super.key, this.savedThemeMode});

  @override
  State<SettingsPageUI> createState() => _SettingsPageUIState();
}

class _SettingsPageUIState extends State<SettingsPageUI> {
  String _userId = '';
  bool _loading = true;
  bool _hasError = false;
  bool _openToJoin = true;
  String? _sessionKey;
  bool _loadScheduled = false;
  int _loadGeneration = 0;
  bool _exporting = false;

  /// Assembles every record this account can read and hands it to the platform
  /// as a JSON file.
  ///
  /// Reading is done here rather than in a trusted function because every read
  /// is one this user is already entitled to make. A server-side exporter would
  /// be a new endpoint that answers "give me everything about a person", which
  /// is worth avoiding when nothing needs it.
  Future<void> _downloadMyData() async {
    if (_userId.isEmpty) return;
    setState(() => _exporting = true);

    final messenger = ScaffoldMessenger.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final generatedAt = DateTime.now();

    try {
      final contents = await DataExportService(locale: locale).buildExport(
        userId: _userId,
        companyId: _membership?.companyId ?? '',
        now: generatedAt,
      );
      await downloadTextFile(
        contents: contents,
        fileName: dataExportFileName(generatedAt),
        mimeType: 'application/json',
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final membershipState = context.watch<MembershipProvider>();
    final users = context.watch<UserDataProvider>();
    final user = users.currentUser;
    final membership = membershipState.membership;
    final sessionKey = [
      membershipState.loading,
      membershipState.error != null,
      membership?.state,
      membership?.companyId,
      membership?.joinPolicy,
      membership?.deletionAt,
      membership?.ownershipTransfer?.fromUid,
      membership?.ownershipTransfer?.targetUid,
      membership?.ownershipTransfer?.expiresAt,
      user?.id,
      user?.role,
      user?.membership,
      users.error != null,
    ].join('|');

    if (_sessionKey == sessionKey || _loadScheduled) return;
    _sessionKey = sessionKey;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final users = context.read<UserDataProvider>();
    final membershipState = context.read<MembershipProvider>();
    if (membershipState.loading && membershipState.membership == null) return;

    try {
      if (membershipState.error case final error?) throw error;
      if (users.error case final error?) throw error;

      final membership = membershipState.membership;
      final user = users.currentUser;
      final canManagePeople =
          user?.role == 'admin' || user?.role == 'superadmin';
      final openToJoin =
          canManagePeople && membership?.companyId.isNotEmpty == true
          ? membership!.isOpenToJoin
          : true;

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
        _openToJoin = openToJoin;
        _hasError = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  Future<void> _retryLoad() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    _sessionKey = null;

    await Future.wait<void>([
      context.read<MembershipProvider>().refresh(),
      context.read<UserDataProvider>().loadCurrentUser(),
    ]);
  }

  Membership? get _membership => context.read<MembershipProvider>().membership;

  UserModel? get _currentUser => context.read<UserDataProvider>().currentUser;

  bool get _isSuperAdmin => _currentUser?.role == 'superadmin';

  bool get _canManagePeople =>
      _currentUser?.role == 'admin' || _currentUser?.role == 'superadmin';

  Future<void> _setJoinPolicy(bool open) async {
    final companyId = _membership?.companyId ?? '';
    if (companyId.isEmpty) return;

    final previous = _openToJoin;
    setState(() => _openToJoin = open);

    try {
      await CompanyAdminService().setJoinPolicy(open: open);
    } catch (_) {
      if (!mounted) return;
      setState(() => _openToJoin = previous);
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    }
  }

  Future<void> _leaveCompany() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('leave_company'.tr()),
        content: Text('leave_company_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('leave_company'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await MembershipService().leaveCompany();
      if (!mounted) return;
      await _load();
    } catch (_) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('log_out'.tr()),
        content: Text('log_out_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('log_out'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final signedOut = await AuthManager().signOut();
    if (!mounted) return;
    if (!signedOut) {
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CustomLoadingWidget(loadingText: 'loading')),
      );
    }

    if (_hasError) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'error_occurred'.tr(),
              action: TextButton(
                onPressed: _retryLoad,
                child: Text('retry'.tr()),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: PageBody(
          maxWidth: 640,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Spacing.xl),
              ScreenHeader(title: 'settings'.tr()),
              const SizedBox(height: Spacing.lg),
              ProfileSection(userId: _userId),
              _buildCompanyGroup(),
              _buildAccountGroup(),
              _buildPreferencesGroup(),
              _buildPrivacyGroup(),
              _buildDangerGroup(),
              const SizedBox(height: Spacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyGroup() {
    final membership = _membership;
    final companyId = membership?.companyId ?? '';
    final inCompany = companyId.isNotEmpty;
    final canCreateCompany = membership?.state == MembershipState.noCompany;
    final activeCompanyAdmin = _canManagePeople && membership?.isActive == true;
    final ownershipOffer = membership?.ownershipTransfer;
    final canTransferOwnership =
        _isSuperAdmin &&
        inCompany &&
        membership?.isActive == true &&
        membership?.isClosing == false;
    final hasOwnershipOffer =
        membership?.isActive == true && ownershipOffer?.targetUid == _userId;
    final ownershipOfferExpired =
        ownershipOffer?.isExpiredAt(DateTime.now()) ?? false;

    return SettingsGroup(
      title: 'company'.tr(),
      footnote: activeCompanyAdmin && inCompany
          ? (_openToJoin
                    ? 'join_policy_open_hint'
                    : 'join_policy_approval_hint')
                .tr()
          : null,
      children: [
        SettingsTile(
          icon: Icons.domain_outlined,
          title: inCompany ? membership!.companyName : 'no_company_title'.tr(),
          subtitle: switch (membership?.state) {
            MembershipState.pending => 'approval_pending'.tr(),
            MembershipState.banned => 'you_are_banned'.tr(),
            MembershipState.active => 'member'.tr(),
            _ => 'no_company_body'.tr(),
          },

          onTap: inCompany && !_isSuperAdmin
              ? _leaveCompany
              : () => _openBrowser(),
        ),

        if (canCreateCompany)
          SettingsTile(
            icon: Icons.add_business_rounded,
            title: 'create_company'.tr(),
            subtitle: 'create_company_settings_hint'.tr(),
            onTap: _openCreateCompany,
          ),

        if (hasOwnershipOffer)
          SettingsTile(
            icon: Icons.workspace_premium_outlined,
            title: 'accept_ownership'.tr(),
            subtitle: ownershipOfferExpired
                ? 'ownership_transfer_expired'.tr()
                : 'accept_ownership_hint'.tr(
                    namedArgs: {'company': membership!.companyName},
                  ),
            onTap: ownershipOfferExpired ? null : _acceptOwnership,
          ),

        if (canTransferOwnership)
          SettingsTile(
            icon: Icons.swap_horiz_rounded,
            title: 'transfer_ownership'.tr(),
            subtitle: 'transfer_ownership_hint'.tr(),
            onTap: _openOwnershipTransfer,
          ),

        if (_isSuperAdmin && inCompany)
          SettingsTile(
            // `domain_disabled` is a building with a slash through it, which
            // reads as "no building" rather than "wind this company down".
            icon: membership!.isClosing
                ? Icons.restore_rounded
                : Icons.business_center_outlined,
            title: membership.isClosing
                ? 'cancel_deletion'.tr()
                : 'close_company'.tr(),
            subtitle: membership.isClosing
                ? 'closing_on'.tr(
                    namedArgs: {
                      'date': DateFormat.yMMMd().add_jm().format(
                        membership.deletionAt!,
                      ),
                    },
                  )
                : 'close_company_hint'.tr(),
            tint: membership.isClosing
                ? null
                : Theme.of(context).colorScheme.error,
            onTap: membership.isClosing ? _cancelClosure : _closeCompany,
          ),
        if (activeCompanyAdmin && inCompany) ...[
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              secondary: const Icon(Icons.door_front_door_outlined),
              title: Text('open_to_join'.tr()),
              value: _openToJoin,
              onChanged: _setJoinPolicy,
            ),
          ),
          SettingsTile(
            icon: Icons.block_outlined,
            title: 'banned_members'.tr(),
            subtitle: 'banned_members_hint'.tr(),
            onTap: () => _open(BannedMembersPage(companyId: companyId)),
          ),
          SettingsTile(
            icon: Icons.history_rounded,
            title: 'activity_log'.tr(),
            subtitle: 'activity_log_hint'.tr(),
            onTap: () =>
                _open(AdministrativeActivityPage(companyId: companyId)),
          ),
        ],
      ],
    );
  }

  Future<void> _closeCompany() async {
    final membership = _membership;
    if (membership == null || membership.companyId.isEmpty) return;

    for (final key in const [
      'close_company_warning_1',
      'close_company_warning_2',
      'close_company_warning_3',
    ]) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text('close_company'.tr()),
          content: Text(key.tr(namedArgs: {'company': membership.companyName})),
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
              child: Text(
                key.endsWith('3') ? 'close_company'.tr() : 'continue'.tr(),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final password = await _promptForCompanyPassword();
    if (password == null || !mounted) return;

    try {
      final at = await CompanyAdminService().scheduleDeletion(
        password: password,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      UIUtils.showSnackBar(
        context,
        'closing_on'.tr(
          namedArgs: {'date': DateFormat.yMMMd().add_jm().format(at)},
        ),
      );
    } on CompanyReauthenticationFailure {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'invalid_old_password'.tr());
    } catch (_) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    }
  }

  Future<String?> _promptForCompanyPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('confirm'.tr()),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'password_label'.tr(),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(
              'close_company'.tr(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _cancelClosure() async {
    final companyId = _membership?.companyId ?? '';
    if (companyId.isEmpty) return;

    try {
      await CompanyAdminService().cancelDeletion();
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'deletion_cancelled'.tr());
    } catch (_) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    }
  }

  Future<void> _openBrowser() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CompanyBrowserPage()),
    );
    if (mounted) await _load();
  }

  Future<void> _openCreateCompany() async {
    final receipt = await Navigator.push<CompanyCreationReceipt>(
      context,
      MaterialPageRoute(builder: (context) => const CreateCompanyPage()),
    );
    if (receipt == null || !mounted) return;

    _sessionKey = null;
    await Future.wait<void>([
      context.read<MembershipProvider>().refresh(),
      context.read<UserDataProvider>().loadCurrentUser(),
    ]);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    UIUtils.showSnackBar(context, 'create_company_success'.tr());
  }

  Future<void> _openOwnershipTransfer() async {
    final membership = _membership;
    if (membership == null ||
        !membership.isActive ||
        membership.isClosing ||
        membership.companyId.isEmpty ||
        _userId.isEmpty) {
      return;
    }

    final receipt = await Navigator.push<OwnershipTransferRequestReceipt>(
      context,
      MaterialPageRoute(
        builder: (context) => OwnershipTransferPage(
          companyId: membership.companyId,
          currentUid: _userId,
        ),
      ),
    );
    if (receipt == null || !mounted) return;

    _sessionKey = null;
    await context.read<MembershipProvider>().refresh();
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    UIUtils.showSnackBar(context, 'ownership_transfer_requested'.tr());
  }

  Future<void> _acceptOwnership() async {
    final membership = _membership;
    final offer = membership?.ownershipTransfer;
    if (membership == null ||
        !membership.isActive ||
        offer == null ||
        offer.targetUid != _userId) {
      return;
    }

    final password = await promptForOwnershipPassword(
      context: context,
      title: 'accept_ownership'.tr(),
      body: 'accept_ownership_confirm'.tr(
        namedArgs: {'company': membership.companyName},
      ),
      actionLabel: 'accept_ownership'.tr(),
    );
    if (password == null || !mounted) return;

    try {
      await OwnershipTransferService().accept(password: password);
      if (!mounted) return;
      _sessionKey = null;
      await Future.wait<void>([
        context.read<MembershipProvider>().refresh(),
        context.read<UserDataProvider>().loadCurrentUser(),
      ]);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'ownership_transfer_accepted'.tr());
    } on OwnershipTransferException catch (error) {
      if (!mounted) return;
      UIUtils.showSnackBar(
        context,
        ownershipTransferFailureKey(error.failure).tr(),
      );
    } catch (_) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'ownership_transfer_unavailable'.tr());
    }
  }

  Widget _buildAccountGroup() {
    return SettingsGroup(
      title: 'account'.tr(),
      children: [
        SettingsTile(
          icon: Icons.alternate_email_rounded,
          title: 'change_email'.tr(),
          subtitle: 'change_email_hint'.tr(),
          onTap: () => _open(const ChangeEmailPage()),
        ),

        SettingsTile(
          icon: Icons.lock_outline_rounded,
          title: 'change_password'.tr(),
          onTap: () => _open(PasswordChanger(isSuperAdmin: _isSuperAdmin)),
        ),

        if (_isStaffViewer)
          SettingsTile(
            icon: Icons.group_outlined,
            title: 'user_management'.tr(),
            subtitle: 'user_management_hint'.tr(),
            onTap: () => _open(UserManagementPage(userId: _userId)),
          ),
      ],
    );
  }

  bool get _isStaffViewer => _membership?.isActive == true && _canManagePeople;

  Widget _buildPreferencesGroup() {
    final theme = Theme.of(context);
    final fontSize = context.watch<FontSizeProvider>().fontSize;

    return SettingsGroup(
      title: 'preferences'.tr(),
      footnote: theme.platform == TargetPlatform.android
          ? null
          : 'biometrics_hint'.tr(),
      children: [
        SettingsTile(
          icon: Icons.contrast_rounded,
          title: 'appearance'.tr(),
          showChevron: false,
          trailing: _ThemeModeToggle(),
        ),
        SettingsTile(
          icon: Icons.translate_rounded,
          title: 'language'.tr(),
          subtitle:
              AppLocales.names[context.locale.languageCode] ??
              context.locale.languageCode,
          onTap: _pickLanguage,
        ),
        SettingsTile(
          icon: Icons.format_size_rounded,
          title: 'font_size'.tr(),
          subtitle: fontSize.round().toString(),
          showChevron: false,
          trailing: SizedBox(
            width: 150,
            child: Slider(
              value: fontSize,

              min: fontMinSize,
              max: fontMaxSize,
              divisions: (fontMaxSize - fontMinSize) ~/ 2,
              label: fontSize.round().toString(),
              onChanged: (value) =>
                  context.read<FontSizeProvider>().setFontSize(value),
            ),
          ),
        ),
        NotificationsOptions(
          icon: Icons.notifications_none_rounded,
          title: 'global_notifications'.tr(),
        ),
        BiometricOptions(
          icon: Icons.fingerprint_rounded,
          title: 'biometrics'.tr(),
        ),
      ],
    );
  }

  Widget _buildDangerGroup() {
    final scheme = Theme.of(context).colorScheme;

    return SettingsGroup(
      title: 'danger_zone'.tr(),
      children: [
        SettingsTile(
          icon: Icons.logout_rounded,
          title: 'log_out'.tr(),
          tint: scheme.onSurfaceVariant,
          showChevron: false,
          onTap: _signOut,
        ),

        SettingsTile(
          icon: Icons.delete_outline_rounded,
          title: 'delete_account'.tr(),
          subtitle: _isSuperAdmin
              ? 'delete_owner_account_hint'.tr()
              : 'delete_account_hint'.tr(),
          tint: scheme.error,
          onTap: _confirmDelete,
        ),
      ],
    );
  }

  Widget _buildPrivacyGroup() {
    return SettingsGroup(
      title: 'privacy_and_data'.tr(),
      children: [
        SettingsTile(
          icon: Icons.download_outlined,
          title: 'download_my_data'.tr(),
          subtitle: _exporting
              ? 'download_my_data_working'.tr()
              : 'download_my_data_hint'.tr(),
          showChevron: false,
          onTap: _exporting ? null : _downloadMyData,
        ),
        SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: 'privacy_policy_link'.tr(),
          subtitle: 'privacy_policy_link_hint'.tr(),
          onTap: () =>
              Navigator.pushNamed(context, PublicRoutePaths.privacyPolicy),
        ),
        SettingsTile(
          icon: Icons.manage_accounts_outlined,
          title: 'account_deletion_info_link'.tr(),
          subtitle: 'account_deletion_info_link_hint'.tr(),
          onTap: () =>
              Navigator.pushNamed(context, PublicRoutePaths.accountDeletion),
        ),
      ],
    );
  }

  Future<void> _confirmDelete() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.xl,
          0,
          Spacing.xl,
          Spacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'delete_account'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              (_isSuperAdmin
                      ? 'delete_owner_account_warning'
                      : 'delete_account_warning')
                  .tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.xl),
            Center(child: DeleteAccountButton(isSuperadmin: _isSuperAdmin)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLanguage() async {
    final current = context.locale;

    final chosen = await showDialog<Locale>(
      context: context,

      builder: (context) => SimpleDialog(
        title: Text('language'.tr()),
        children: [
          for (final locale in AppLocales.supported)
            ListTile(
              leading: Icon(
                locale.languageCode == current.languageCode
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: locale.languageCode == current.languageCode
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(
                AppLocales.names[locale.languageCode] ?? locale.languageCode,
              ),
              onTap: () => Navigator.pop(context, locale),
            ),
        ],
      ),
    );

    if (chosen == null || !mounted) return;
    await context.setLocale(chosen);
  }
}

class _ThemeModeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mode = AdaptiveTheme.of(context).mode;

    return SegmentedButton<AdaptiveThemeMode>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: [
        ButtonSegment(
          value: AdaptiveThemeMode.light,
          icon: const Icon(Icons.light_mode_rounded, size: 16),
          tooltip: 'theme_light'.tr(),
        ),
        ButtonSegment(
          value: AdaptiveThemeMode.dark,
          icon: const Icon(Icons.dark_mode_rounded, size: 16),
          tooltip: 'theme_dark'.tr(),
        ),
        ButtonSegment(
          value: AdaptiveThemeMode.system,
          icon: const Icon(Icons.brightness_auto_rounded, size: 16),
          tooltip: 'theme_system'.tr(),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) {
        AdaptiveTheme.of(context).setThemeMode(selection.first);
      },
    );
  }
}
