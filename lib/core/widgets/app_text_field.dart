import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
    this.trailing,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;
  final bool enabled;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final _focusNode = FocusNode();

  TextEditingController? _ownedController;

  bool _focused = false;

  TextEditingController get _controller =>
      widget.controller ?? (_ownedController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focused == _focusNode.hasFocus) return;
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FormField<String>(
      validator: (_) => widget.validator?.call(_controller.text),
      builder: (field) {
        final hasError = field.hasError;
        final accent = hasError ? scheme.error : scheme.primary;
        final errorStyle = (theme.textTheme.bodySmall ?? const TextStyle())
            .copyWith(color: scheme.error);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: _focused || hasError ? accent : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.md),

                boxShadow: _focused
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.18),
                          blurRadius: 0,
                          spreadRadius: 3,
                        ),
                      ]
                    : null,
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                obscureText: widget.obscure,
                enabled: widget.enabled,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                autofillHints: widget.autofillHints,
                onSubmitted: widget.onSubmitted,

                onChanged: (_) {
                  if (field.hasError) field.validate();
                },
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: widget.hint,

                  labelText: null,
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  prefixIcon: widget.icon == null
                      ? null
                      : Icon(widget.icon, size: 19),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  suffixIcon: widget.trailing,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg,
                    vertical: 15,
                  ),

                  enabledBorder: hasError ? _errorBorder(scheme, 1) : null,
                  focusedBorder: hasError ? _errorBorder(scheme, 2) : null,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(top: Spacing.xs, left: Spacing.sm),
              child: Text(
                field.errorText ?? '',
                style: errorStyle,
                strutStyle: StrutStyle.fromTextStyle(
                  errorStyle,
                  forceStrutHeight: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  OutlineInputBorder _errorBorder(ColorScheme scheme, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: BorderSide(color: scheme.error, width: width),
    );
  }
}
