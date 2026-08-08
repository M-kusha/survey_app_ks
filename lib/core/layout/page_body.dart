import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:flutter/material.dart';

/// Constrains and centres page content so it stops stretching on wide windows.
///
/// This is the single highest-return responsive fix in the app. Forms and
/// wizard steps were laid out edge to edge, which is fine on a phone and looks
/// broken on a monitor — a login card spanning 2560px of a 4K display, with a
/// text field the width of the screen.
///
/// [maxWidth] defaults to a comfortable reading measure for forms. Pass a wider
/// value for content that genuinely benefits from the room, such as tables or
/// dashboards.
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

  /// Wraps the content in a scroll view. Turn this off when the child already
  /// scrolls — a ListView, for example — otherwise it will be given unbounded
  /// height and throw.
  final bool scrollable;

  /// Centres the content vertically when it is shorter than the viewport.
  /// Suits short forms; leave off for long pages so they start at the top.
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
          // Lets centerVertically actually centre: without a minimum height the
          // scroll view shrink-wraps and there is nothing to centre within.
          constraints: BoxConstraints(
            minHeight: centerVertically ? constraints.maxHeight : 0,
          ),
          child: content,
        ),
      ),
    );
  }
}
