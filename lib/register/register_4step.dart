import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/app_text_field.dart';
import 'package:echomeet/register/register_logics.dart';
import 'package:echomeet/register/register_shell.dart';
import 'package:echomeet/register/registered_sucesfully.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:flutter/material.dart';

class Register4step extends StatefulWidget {
  final RegisterLogic registerLogic;

  const Register4step({super.key, required this.registerLogic});

  @override
  Register4stepState createState() => Register4stepState();
}

class Register4stepState extends State<Register4step> {
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _companies = [];
  String? _selectedId;
  bool _loading = true;
  bool _hasError = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _fetchCompanies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCompanies() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      final companies = await widget.registerLogic.searchCompanies('');
      if (!mounted) return;
      setState(() {
        _companies = companies;
        if (_selectedId != null &&
            !companies.any((company) => company['id'] == _selectedId)) {
          _selectedId = null;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visible {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _companies;
    return _companies
        .where(
          (company) =>
              (company['name'] as String).toLowerCase().contains(query),
        )
        .toList();
  }

  Future<void> _finish({bool withoutCompany = false}) async {
    setState(() => _saving = true);

    try {
      await widget.registerLogic.registerUser(
        profileType: ProfileType.user,
        existingCompanyId: withoutCompany ? null : _selectedId,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const RegistrationSuccessPage(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, registrationErrorKey(e).tr());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RegisterShell(
      step: 4,
      titleKey: 'register_step4_title',
      subtitleKey: 'register_step4_subhead',
      continueLabelKey: 'finish_registration',
      onContinue: _selectedId == null || _saving ? null : _finish,
      busy: _saving,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'search_company'.tr(),
            controller: _searchController,
            icon: Icons.search_rounded,
            trailing: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: _searchController.clear,
                  ),
          ),
          const SizedBox(height: Spacing.sm),
          _buildList(),
          const SizedBox(height: Spacing.md),
          TextButton(
            onPressed: _saving ? null : () => _finish(withoutCompany: true),
            child: Text('continue_without_company'.tr()),
          ),
          Text(
            'join_company_later_hint'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: Spacing.xxl),
        child: CustomLoadingWidget(loadingText: 'loading'),
      );
    }

    if (_hasError) {
      return _CompanyLoadError(onRetry: _fetchCompanies);
    }

    final companies = _visible;
    if (companies.isEmpty) {
      return _EmptyState(
        message: _companies.isEmpty
            ? 'no_companies_yet'.tr()
            : 'no_companies_found'.tr(),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: companies.length,
        separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
        itemBuilder: (context, index) {
          final company = companies[index];
          final id = company['id'] as String;

          return _CompanyTile(
            name: company['name'] as String,
            selected: _selectedId == id,
            onTap: () => setState(() => _selectedId = id),
          );
        },
      ),
    );
  }
}

class _CompanyLoadError extends StatelessWidget {
  const _CompanyLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 28,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'error_occurred'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          TextButton(onPressed: onRetry, child: Text('retry'.tr())),
        ],
      ),
    );
  }
}

class _CompanyTile extends StatelessWidget {
  const _CompanyTile({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            color: selected
                ? scheme.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.7),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.business_outlined,
                size: 20,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 20,
                child: selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: scheme.primary,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xxl),
      child: Column(
        children: [
          Icon(
            Icons.domain_disabled_outlined,
            size: 28,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
