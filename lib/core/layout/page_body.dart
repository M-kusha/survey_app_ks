import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:flutter/material.dart';

class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.child,
    this.maxWidth = 640,
    this.padding,
    this.scrollable = true,
    this.centerVertically = false,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  final bool scrollable;

  final bool centerVertically;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding =
        padding ??
        EdgeInsets.symmetric(
          horizontal: context.isCompact ? Spacing.lg : Spacing.xl,
          vertical: Spacing.lg,
        );

    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );

    content = Align(
      alignment: centerVertically ? Alignment.center : Alignment.topCenter,
      child: content,
    );

    content = Padding(padding: resolvedPadding, child: content);

    if (!scrollable) return content;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: centerVertically ? constraints.maxHeight : 0,
          ),
          child: content,
        ),
      ),
    );
  }
}
