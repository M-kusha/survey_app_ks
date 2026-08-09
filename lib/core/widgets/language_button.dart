import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/localization/app_locales.dart';
import 'package:flutter/material.dart';

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = Localizations.localeOf(context).languageCode;

    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.55),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<Locale>(
        tooltip: 'language'.tr(),
        position: PopupMenuPosition.under,
        onSelected: (locale) => context.setLocale(locale),
        itemBuilder: (context) => [
          for (final locale in AppLocales.supported)
            PopupMenuItem(
              value: locale,
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: locale.languageCode == current
                        ? Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: scheme.primary,
                          )
                        : null,
                  ),
                  Text(
                    AppLocales.names[locale.languageCode] ??
                        locale.languageCode,
                  ),
                ],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.language_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                current.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
