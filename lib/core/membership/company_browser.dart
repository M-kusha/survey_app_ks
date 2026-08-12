import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/membership/membership.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/status_pill.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

class CompanyBrowserPage extends StatefulWidget {
  const CompanyBrowserPage({super.key});

  @override
  State<CompanyBrowserPage> createState() => _CompanyBrowserPageState();
}

class _CompanyBrowserPageState extends State<CompanyBrowserPage> {
  final _service = MembershipService();
  final _searchController = TextEditingController();

  List<CompanySummary> _companies = [];
  Set<String> _banned = {};
  bool _loading = true;
  bool _hasError = false;
  String? _joining;

  Object? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
      _error = null;
    });

    try {
      final companies = await _service.searchCompanies('');

      final banned = await _service.bannedCompanyIds([
        for (final company in companies) company.id,
      ]);

      if (!mounted) return;
      setState(() {
        _companies = companies;
        _banned = banned;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _error = error;
        _loading = false;
      });
    }
  }

  List<CompanySummary> get _visible {
    final needle = _searchController.text.trim().toLowerCase();
    if (needle.isEmpty) return _companies;
    return _companies
        .where((company) => company.name.toLowerCase().contains(needle))
        .toList();
  }

  Future<void> _join(CompanySummary company) async {
    setState(() => _joining = company.id);

    try {
      final state = await _service.joinCompany(company);
      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state == MembershipState.pending
                ? 'join_requested'.tr(namedArgs: {'company': company.name})
                : 'joined_company'.tr(namedArgs: {'company': company.name}),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _joining = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('find_a_company'.tr())),
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
                hint: 'search_companies'.tr(),
              ),
              const SizedBox(height: Spacing.md),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_hasError) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'error_occurred'.tr(),
        body: kDebugMode ? '$_error' : null,
        action: TextButton(onPressed: _load, child: Text('retry'.tr())),
      );
    }

    final companies = _visible;
    if (companies.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: _searchController.text.isEmpty
            ? 'no_companies_yet'.tr()
            : 'no_companies_found'.tr(),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: Spacing.xxl),
      itemCount: companies.length,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
      itemBuilder: (context, index) {
        final company = companies[index];
        final banned = _banned.contains(company.id);

        return ContentCard(
          muted: banned,
          onTap: banned || _joining != null ? null : () => _join(company),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: Spacing.xs),

                    if (banned)
                      StatusPill(
                        label: 'banned_from_here'.tr(),
                        tone: StatusTone.danger,
                        icon: Icons.block_rounded,
                      )
                    else
                      StatusPill(
                        label: company.needsApproval
                            ? 'needs_approval'.tr()
                            : 'open_to_join'.tr(),
                        tone: company.needsApproval
                            ? StatusTone.caution
                            : StatusTone.positive,
                        icon: company.needsApproval
                            ? Icons.how_to_reg_outlined
                            : Icons.door_front_door_outlined,
                      ),
                  ],
                ),
              ),
              if (_joining == company.id)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (!banned)
                const Icon(Icons.chevron_right_rounded),
            ],
          ),
        );
      },
    );
  }
}
