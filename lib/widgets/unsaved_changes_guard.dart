import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';

/// Wraps a screen with a [PopScope] that intercepts the back button (and
/// system back gesture) when [hasChanges] is true and shows a confirmation
/// dialog before discarding.
///
/// Direct [Navigator.pop] calls (e.g. from a Save button) bypass this guard
/// and always succeed, so only the back-navigation path is protected.
class UnsavedChangesGuard extends StatefulWidget {
  final bool hasChanges;
  final Widget child;

  /// Optional override for the dialog body text.
  final String? message;

  const UnsavedChangesGuard({
    super.key,
    required this.hasChanges,
    required this.child,
    this.message,
  });

  @override
  State<UnsavedChangesGuard> createState() => _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  // Set to true after the user confirms discard so the programmatic pop
  // that follows is not blocked again by canPop: false.
  bool _allowPop = false;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _allowPop || !widget.hasChanges,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _promptDiscard(context);
      },
      child: widget.child,
    );
  }

  Future<void> _promptDiscard(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.discardChangesTitle),
        content: Text(widget.message ?? l10n.discardChangesDefault),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.keepEditing),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && mounted) {
      setState(() => _allowPop = true);
      if (mounted) Navigator.of(context).pop();
    }
  }
}
