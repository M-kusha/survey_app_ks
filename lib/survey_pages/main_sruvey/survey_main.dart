import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/membership/company_gate.dart';
import 'package:echomeet/core/membership/membership.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/sign_out_button.dart';
import 'package:echomeet/survey_pages/main_sruvey/survey_create_button.dart';
import 'package:echomeet/survey_pages/main_sruvey/survey_list.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/utilities/firebase_services.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum SurveySort { newest, oldest, closingSoon, closingLast }

class QuestionarySurveyPageUI extends StatefulWidget {
  const QuestionarySurveyPageUI({super.key});

  @override
  State<QuestionarySurveyPageUI> createState() =>
      _QuestionarySurveyPageUIState();
}

class _QuestionarySurveyPageUIState extends State<QuestionarySurveyPageUI> {
  final _searchController = TextEditingController();

  SurveySort _sort = SurveySort.newest;
  bool _isAdmin = false;
  bool _isLoading = true;
  String? _error;
  Membership? _membership;

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

  Future<void> _refresh() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    final surveys = Provider.of<SurveyDataProvider>(context, listen: false);
    final users = Provider.of<UserDataProvider>(context, listen: false);
    final services = Provider.of<FirebaseServices>(context, listen: false);

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await users.loadCurrentUser();
      if (!mounted) return;

      final membership = await MembershipService().resolve();
      if (!mounted) return;

      if (!membership.isActive) {
        setState(() {
          _membership = membership;
          _isLoading = false;
        });
        return;
      }

      _membership = membership;
      final companyId = membership.companyId;

      await surveys.loadSurveys(companyId);
      if (!mounted) return;
      await surveys.checkParticipationForCurrentUser(
        FirebaseAuth.instance.currentUser?.uid ?? '',
      );

      final isAdmin = await services.fetchAdminStatus();
      if (!mounted) return;

      setState(() {
        _isAdmin = isAdmin;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  ({List<Survey> waiting, List<Survey> done, List<Survey> closed}) _group(
    List<Survey> surveys,
    SurveyDataProvider provider,
  ) {
    final now = DateTime.now();
    bool answered(Survey s) => provider.userParticipationStatus[s.id] ?? false;
    bool live(Survey s) => s.deadline.isAfter(now);

    return (
      waiting: surveys.where((s) => live(s) && !answered(s)).toList(),
      done: surveys.where((s) => live(s) && answered(s)).toList(),
      closed: surveys.where((s) => !live(s)).toList(),
    );
  }

  String _waitingLabel(int count) => count == 0
      ? 'all_caught_up'.tr()
      : 'needs_you_count'.tr(namedArgs: {'count': '$count'});

  List<Survey> _visible(List<Survey> surveys) {
    final needle = _searchController.text.trim().toLowerCase();

    final result = surveys
        .where(
          (survey) =>
              needle.isEmpty ||
              survey.surveyName.toLowerCase().contains(needle),
        )
        .toList();

    result.sort(
      (a, b) => switch (_sort) {
        SurveySort.newest => b.timeCreated.compareTo(a.timeCreated),
        SurveySort.oldest => a.timeCreated.compareTo(b.timeCreated),
        SurveySort.closingSoon => a.deadline.compareTo(b.deadline),
        SurveySort.closingLast => b.deadline.compareTo(a.deadline),
      },
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SurveyDataProvider>(context);
    final surveys = _visible(provider.surveys);

    if (!_isLoading && _membership?.isActive != true) {
      return CompanyGate(
        membership: _membership,
        onChanged: _load,
        child: const SizedBox.shrink(),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: PageBody(
          maxWidth: 720,

          scrollable: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Spacing.xl),
              ScreenHeader(
                title: 'surveys'.tr(),
                subtitle: _isLoading
                    ? null
                    : _waitingLabel(
                        _group(provider.surveys, provider).waiting.length,
                      ),
                actions: const [SignOutOnCompact()],
              ),
              const SizedBox(height: Spacing.lg),

              Row(
                children: [
                  Expanded(
                    child: SearchPill(
                      controller: _searchController,
                      hint: 'search_hint'.tr(),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  _buildSortMenu(),
                ],
              ),
              Expanded(child: _buildBody(provider, surveys)),
            ],
          ),
        ),
      ),
      floatingActionButton: _isAdmin
          ? buildCreateQuestionarySurveyButton(context)
          : null,
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<SurveySort>(
      tooltip: 'sort'.tr(),
      initialValue: _sort,
      onSelected: (value) => setState(() => _sort = value),
      itemBuilder: (context) => [
        for (final (sort, labelKey, icon) in const [
          (SurveySort.newest, 'newest', Icons.arrow_downward_rounded),
          (SurveySort.oldest, 'oldest', Icons.arrow_upward_rounded),
          (SurveySort.closingSoon, 'exp_date_asc', Icons.event_busy_rounded),
          (SurveySort.closingLast, 'exp_date_des', Icons.event_rounded),
        ])
          PopupMenuItem(
            value: sort,
            child: Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: Spacing.md),
                Text(labelKey.tr()),
              ],
            ),
          ),
      ],
      child: CircleAction(
        icon: Icons.sort_rounded,
        tooltip: 'sort'.tr(),
        active: _sort != SurveySort.newest,
        onTap: null,
      ),
    );
  }

  Widget _buildBody(SurveyDataProvider provider, List<Survey> surveys) {
    if (_isLoading) {
      return const Center(child: CustomLoadingWidget(loadingText: 'loading'));
    }

    if (_error case final error?) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'error_occurred'.tr(),
        body: error,
        action: TextButton(onPressed: _load, child: Text('retry'.tr())),
      );
    }

    if (surveys.isEmpty) {
      return _searchController.text.isEmpty
          ? EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'no_test_surveys_yet'.tr(),
              body: 'no_surveys_body'.tr(),
            )
          : EmptyState(
              icon: Icons.search_off_rounded,
              title: 'search_survey_or_test_not_found'.tr(),
              action: TextButton(
                onPressed: _searchController.clear,
                child: Text('clear_search'.tr()),
              ),
            );
    }

    final (:waiting, :done, :closed) = _group(surveys, provider);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          for (final (labelKey, group) in [
            ('section_needs_you', waiting),
            ('section_done', done),
            ('section_closed', closed),
          ])
            if (group.isNotEmpty) ...[
              SectionLabel(label: labelKey.tr(), count: group.length),
              for (final survey in group)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: SurveyListItem(
                    survey: survey,
                    isAdmin: _isAdmin,

                    hasParticipated:
                        provider.userParticipationStatus[survey.id] ?? false,
                    onChanged: _refresh,
                  ),
                ),
            ],
        ],
      ),
    );
  }
}
