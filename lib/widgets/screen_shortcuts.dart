import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Desktop keyboard shortcuts shared by the content screens.
///
/// | Key               | Callback      |
/// |-------------------|---------------|
/// | Ctrl+S            | [onSave]      |
/// | Ctrl+F            | [onSearch]    |
/// | Ctrl+Space        | [onNew]       |
/// | Ctrl+Shift+Space  | [onNewFolder] |
/// | Escape / back     | [onEscape]    |
///
/// Only non-null callbacks are bound. Screens pass null for an action that is
/// currently unavailable (FAB hidden while searching, selection mode active),
/// so a shortcut never triggers something the screen isn't offering.
class ScreenShortcuts extends StatelessWidget {
  /// Ctrl+S — save the screen's form.
  final VoidCallback? onSave;

  /// Ctrl+F — open (or re-focus) the screen's search bar.
  final VoidCallback? onSearch;

  /// Ctrl+Space — the screen's primary "create" action (new quiz / question).
  final VoidCallback? onNew;

  /// Ctrl+Shift+Space — create a folder.
  final VoidCallback? onNewFolder;

  /// Escape and the system back button. Non-null means the screen wants to
  /// handle back itself (e.g. close the search bar) instead of popping.
  final VoidCallback? onEscape;

  final Widget child;

  const ScreenShortcuts({
    super.key,
    this.onSave,
    this.onSearch,
    this.onNew,
    this.onNewFolder,
    this.onEscape,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // SingleActivator matches modifiers exactly, so Ctrl+Space does not fire
    // while Shift is held — the two create bindings can't collide.
    // Built imperatively rather than with if-elements: build_runner's older
    // bundled analyzer scans this file, and the `?x` form the linter would
    // otherwise want here fails to parse there.
    final bindings = <ShortcutActivator, VoidCallback>{};
    final save = onSave;
    if (save != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.keyS, control: true)] =
          save;
    }
    final search = onSearch;
    if (search != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.keyF, control: true)] =
          search;
    }
    final create = onNew;
    if (create != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.space, control: true)] =
          create;
    }
    final createFolder = onNewFolder;
    if (createFolder != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.space,
          control: true, shift: true)] = createFolder;
    }

    // Escape can't be a binding here: main.dart installs a HardwareKeyboard
    // handler that pops the route, and those run before the focus tree ever
    // sees the key. It pops via Navigator.maybePop, which consults PopScope —
    // so intercepting back is what actually catches Escape as well.
    return PopScope<Object?>(
      canPop: onEscape == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onEscape?.call();
      },
      child: CallbackShortcuts(
        bindings: bindings,
        // Without a focused descendant the key event never travels up to the
        // bindings, and these screens have no autofocusing field of their own
        // until a search box opens. This node claims focus on entry.
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}
