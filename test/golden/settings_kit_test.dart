import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/localization/app_locales.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/settings/settings_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/load_fonts.dart';
import '../support/load_translations.dart';

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget child) async {
  tester.view.physicalSize = const Size(520, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData.fromView(
        tester.view,
      ).copyWith(disableAnimations: true),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        supportedLocales: AppLocales.supported,
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.lg),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
    await loadAppTranslations();
  });

  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('settings groups — $name', (tester) async {
      await _pump(
        tester,
        theme,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsGroup(
              title: 'Account',
              children: [
                SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Change password',
                  onTap: () {},
                ),
                SettingsTile(
                  icon: Icons.group_outlined,
                  title: 'User management',
                  subtitle: 'Add and remove people in your company',
                  onTap: () {},
                ),
              ],
            ),
            SettingsGroup(
              title: 'Preferences',
              footnote:
                  'Biometric unlock reopens an existing session. '
                  'It is not a password.',
              children: [
                SettingsTile(
                  icon: Icons.translate_rounded,
                  title: 'Language',
                  subtitle: 'English',
                  onTap: () {},
                ),
                SettingsSwitchTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  value: true,
                  onChanged: (_) {},
                ),

                SettingsSwitchTile(
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometrics',
                  subtitle: 'No fingerprint or face unlock set up',
                  value: false,
                  onChanged: null,
                ),
              ],
            ),
            SettingsGroup(
              title: 'Account actions',
              children: [
                SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Log out',
                  tint: theme.colorScheme.onSurfaceVariant,
                  showChevron: false,
                  onTap: () {},
                ),
                SettingsTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete account',
                  subtitle: 'Permanently removes your account and data',
                  tint: theme.colorScheme.error,
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      );

      await expectLater(
        find.byType(Column).first,
        matchesGoldenFile('goldens/settings_groups_$name.png'),
      );
    });
  }
}
