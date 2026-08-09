import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyableCode extends StatefulWidget {
  const CopyableCode({super.key, required this.label, required this.code});

  final String label;
  final String code;

  @override
  State<CopyableCode> createState() => _CopyableCodeState();
}

class _CopyableCodeState extends State<CopyableCode> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;

    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final app = context.appColors;
    final accent = _copied ? app.success : scheme.primary;

    return Semantics(
      button: true,
      label: '${widget.label}: ${widget.code}',
      child: InkWell(
        onTap: _copy,
        borderRadius: BorderRadius.circular(Radii.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            color: accent.withValues(alpha: 0.08),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _copied ? 'copied'.tr() : widget.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _copied ? app.success : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _grouped(widget.code),

                      style: theme.textTheme.titleSmall?.copyWith(
                        letterSpacing: 1.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.sm),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                  key: ValueKey(_copied),
                  size: 17,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _grouped(String code) {
    if (code.length <= 8) return code;

    final buffer = StringBuffer();
    for (var i = 0; i < code.length; i += 4) {
      if (i > 0) buffer.write(' ');
      buffer.write(code.substring(i, (i + 4).clamp(0, code.length)));
    }
    return buffer.toString();
  }
}
