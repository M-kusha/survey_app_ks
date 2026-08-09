import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/membership/company_admin_service.dart';
import 'package:echomeet/core/membership/company_browser.dart';
import 'package:echomeet/core/membership/membership.dart';
import 'package:echomeet/settings/banned_members.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/localization/app_locales.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/login/login.dart';
import 'package:echomeet/login/login_logics.dart';
import 'package:echomeet/settings/biometrics_options.dart';
import 'package:echomeet/settings/delete_account.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/settings/notifications_options.dart';
import 'package:echomeet/settings/password_change.dart';
import 'package:echomeet/settings/profile_section.dart';
import 'package:echomeet/settings/settings_kit.dart';
import 'package:echomeet/settings/user_menagment.dart';
import 'package:echomeet/utilities/firebase_services.dart';
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
  late final FirebaseServices _services = FirebaseServices();

  String _userId = '';
  bool _isSuperAdmin = false;
  bool _canManagePeople = false;
  bool _loading = true;
  Membership? _membership;
  bool _openToJoin = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    final isSuperAdmin = await _services.isSuperAdminUser();
    final canManagePeople = await _services.canManagePeople();
    final membership = await MembershipService().resolve();

    final openToJoin = canManagePeople && membership.companyId.isNotEmpty
        ? await CompanyAdminService().isOpenToJoin(membership.companyId)
        : true;

    if (!mounted) return;

    setState(() {
      _userId = userId;
      _isSuperAdmin = isSuperAdmin;
      _canManagePeople = canManagePeople;
      _membership = membership;
      _openToJoin = openToJoin;
      _loading = false;
    });
  }

  Future<void> _setJoinPolicy(bool open) async {
    final companyId = _membership?.companyId ?? '';
    if (companyId.isEmpty) return;

    final previous = _openToJoin;
    setState(() => _openToJoin = open);

    try {
      await CompanyAdminService().setJoinPolicy(
        companyId: companyId,
        open: open,
      );
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

    await AuthManager().signOut();
    if (!mounted) return;
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

    return SettingsGroup(
      title: 'company'.tr(),
      footnote: _canManagePeople && inCompany
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

        if (_isSuperAdmin && inCompany)
          SettingsTile(
            icon: membership!.isClosing
                ? Icons.undo_rounded
                : Icons.domain_disabled_outlined,
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
        if (_canManagePeople && inCompany) ...[
          SwitchListTile(
            secondary: const Icon(Icons.door_front_door_outlined),
            title: Text('open_to_join'.tr()),
            value: _openToJoin,
            onChanged: _setJoinPolicy,
          ),
          SettingsTile(
            icon: Icons.block_outlined,
            title: 'banned_members'.tr(),
            subtitle: 'banned_members_hint'.tr(),
            onTap: () => _open(BannedMembersPage(companyId: companyId)),
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

    try {
      final at = await CompanyAdminService().scheduleDeletion(
        membership.companyId,
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
    } catch (_) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    }
  }

  Future<void> _cancelClosure() async {
    final companyId = _membership?.companyId ?? '';
    if (companyId.isEmpty) return;

    try {
      await CompanyAdminService().cancelDeletion(companyId);
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

  Widget _buildAccountGroup() {
    return SettingsGroup(
      title: 'account'.tr(),
      children: [
        SettingsTile(
          icon: Icons.lock_outline_rounded,
          title: 'change_password'.tr(),
          onTap: () => _open(PasswordChanger(isSuperAdmin: _isSuperAdmin)),
        ),

        if (_isSuperAdmin || _canManagePeople || _isStaffViewer)
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
              ? 'delete_account_blocked'.tr()
              : 'delete_account_hint'.tr(),
          tint: scheme.error,
          onTap: _confirmDelete,
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
              _isSuperAdmin
                  ? 'delete_account_blocked'.tr()
                  : 'delete_account_warning'.tr(),
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
