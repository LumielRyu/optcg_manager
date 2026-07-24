import 'package:flutter/material.dart';

/// Turns a fully clickable surface into one clear, keyboard-accessible action.
///
/// The supplied label replaces the visual descendants in the semantics tree,
/// preventing icons and decorative copy from being announced as separate
/// controls. The visual content itself remains unchanged.
class AccessibleActionSurface extends StatefulWidget {
  final String label;
  final String? hint;
  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius borderRadius;
  final Color? focusColor;

  const AccessibleActionSurface({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.hint,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.focusColor,
  });

  @override
  State<AccessibleActionSurface> createState() =>
      _AccessibleActionSurfaceState();
}

class _AccessibleActionSurfaceState extends State<AccessibleActionSurface> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final focusColor = widget.focusColor ?? theme.colorScheme.primary;

    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.label,
      hint: widget.hint,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 120),
          foregroundDecoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: _focused ? Border.all(color: focusColor, width: 3) : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              excludeFromSemantics: true,
              canRequestFocus: widget.onTap != null,
              onFocusChange: (focused) {
                if (_focused != focused) setState(() => _focused = focused);
              },
              onTap: widget.onTap,
              borderRadius: widget.borderRadius,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
