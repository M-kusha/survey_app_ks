import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/app_text_field.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:flutter/material.dart';

/// How a birthdate is written to the profile.
///
/// The registration form stores it as a localised display string rather than an
/// ISO date, so this screen has to keep writing the same shape or the two would
/// disagree about what a birthdate looks like. Matching the existing format is
/// the smaller of two evils; changing it is a data migration.
String formatBirthdate(DateTime value, {String? locale}) =>
    DateFormat.yMMMMd(locale).format(value);

/// Reads a stored birthdate back into a date, or null if it cannot be trusted.
///
/// The stored string was formatted in whatever locale the person registered in,
/// which is not necessarily the one they are reading now — so every supported
/// locale is tried before giving up. Returning null is a normal outcome: the
/// picker then opens at its default instead of on a date that was guessed.
DateTime? parseStoredBirthdate(String stored, {List<String> locales = const []}) {
  final value = stored.trim();
  if (value.isEmpty) return null;

  for (final locale in [...locales, 'en', 'de', 'sq']) {
    try {
      return DateFormat.yMMMMd(locale).parseStrict(value);
    } catch (_) {
      continue;
    }
  }
  // Older or hand-edited values may be plain ISO.
  return DateTime.tryParse(value);
}

/// Writes a name and birthdate to the profile, and to the company projection.
///
/// Both documents move together. `memberDirectory` is what every company screen
/// reads, and the rules require it to equal the private profile *after* the
/// write — so a name change that touched only one of them would either be
/// refused or leave the member list showing a name its owner had already
/// changed. A batch is one atomic write, which satisfies both.
Future<void> saveProfileDetails({
  required String userId,
  required String fullName,
  required String birthdate,
  FirebaseFirestore? firestore,
}) async {
  final name = fullName.trim();
  if (name.isEmpty || name.length > 120) {
    throw ArgumentError('A profile name must be 1-120 characters.');
  }
  if (birthdate.trim().length > 50) {
    throw ArgumentError('A stored birthdate must be 50 characters or fewer.');
  }

  final db = firestore ?? FirebaseFirestore.instance;
  final profile = db.collection('users').doc(userId);
  final existing = await profile.get();
  if (!existing.exists) throw StateError('The profile no longer exists.');

  final companyId = (existing.data()?['companyId'] as String? ?? '').trim();
  final batch = db.batch();
  batch.update(profile, {'fullName': name, 'birthdate': birthdate.trim()});
  if (companyId.isNotEmpty) {
    batch.update(db.collection('memberDirectory').doc(userId), {
      'fullName': name,
    });
  }
  await batch.commit();
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.userId, this.firestore});

  final String userId;
  final FirebaseFirestore? firestore;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthdateController = TextEditingController();

  DateTime? _birthdate;
  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;

  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(widget.userId)
          .get();
      if (!mounted) return;
      final data = snapshot.data();
      final stored = (data?['birthdate'] as String? ?? '').trim();
      setState(() {
        _nameController.text = (data?['fullName'] as String? ?? '').trim();
        _birthdateController.text = stored;
        _birthdate = parseStoredBirthdate(stored);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Saying so beats an empty form that would overwrite a real name with
      // whatever the reader typed into blank fields.
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    // The same 18-year floor registration applies. An edit screen that let you
    // set a date registration would have refused is a way around the rule.
    final latest = DateTime(now.year - 18, now.month, now.day);
    final initial = _birthdate != null && !_birthdate!.isAfter(latest)
        ? _birthdate!
        : latest;

    final chosen = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: latest,
    );
    if (chosen == null || !mounted) return;

    setState(() {
      _birthdate = chosen;
      _birthdateController.text = formatBirthdate(
        chosen,
        locale: context.locale.toLanguageTag(),
      );
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await saveProfileDetails(
        userId: widget.userId,
        fullName: _nameController.text,
        birthdate: _birthdateController.text,
        firestore: widget.firestore,
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('profile_saved'.tr())));
      navigator.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('edit_profile'.tr())),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadFailed
            ? Center(
                child: EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'error_occurred'.tr(),
                  action: TextButton(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _loadFailed = false;
                      });
                      _load();
                    },
                    child: Text('retry'.tr()),
                  ),
                ),
              )
            : PageBody(
                maxWidth: 560,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: Spacing.md),
                      AppTextField(
                        label: 'fullname'.tr(),
                        controller: _nameController,
                        textInputAction: TextInputAction.done,
                        maxLength: 120,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'please_fill_all_fields'.tr()
                            : null,
                      ),
                      const SizedBox(height: Spacing.md),
                      // Read-only with a picker behind it, the same as
                      // registration — a typed date could not be parsed back.
                      InkWell(
                        onTap: _saving ? null : _pickBirthdate,
                        borderRadius: BorderRadius.circular(Radii.md),
                        child: IgnorePointer(
                          child: AppTextField(
                            label: 'birthdate'.tr(),
                            controller: _birthdateController,
                            icon: Icons.cake_outlined,
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? 'please_fill_all_fields'.tr()
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: Spacing.xl),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text('save'.tr()),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
