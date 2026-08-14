import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leerlus/widgets/screen_shortcuts.dart';

void main() {
  /// Presses [key] with the given modifiers held, the way a real chord arrives.
  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool control = false,
    bool shift = false,
  }) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  group('ScreenShortcuts', () {
    late int saves;
    late int searches;
    late int news;
    late int newFolders;

    Future<void> pumpShortcuts(
      WidgetTester tester, {
      bool withSearch = true,
      bool withNew = true,
      bool withNewFolder = true,
    }) {
      saves = 0;
      searches = 0;
      news = 0;
      newFolders = 0;
      return tester.pumpWidget(
        MaterialApp(
          home: ScreenShortcuts(
            onSave: () => saves++,
            onSearch: withSearch ? () => searches++ : null,
            onNew: withNew ? () => news++ : null,
            onNewFolder: withNewFolder ? () => newFolders++ : null,
            child: const Scaffold(body: Text('content')),
          ),
        ),
      );
    }

    // The screens this wraps have no autofocusing field of their own (the edit
    // screens only autofocus when creating, not when editing), so the bindings
    // only ever fire because ScreenShortcuts claims focus itself.
    testWidgets('fires with nothing else focused', (tester) async {
      await pumpShortcuts(tester);
      await press(tester, LogicalKeyboardKey.keyF, control: true);
      expect(searches, 1);
      await press(tester, LogicalKeyboardKey.keyS, control: true);
      expect(saves, 1);
    });

    testWidgets('Ctrl+Space and Ctrl+Shift+Space stay distinct',
        (tester) async {
      await pumpShortcuts(tester);

      await press(tester, LogicalKeyboardKey.space, control: true);
      expect(news, 1);
      expect(newFolders, 0);

      await press(tester, LogicalKeyboardKey.space, control: true, shift: true);
      expect(news, 1, reason: 'Shift must exclude the plain Ctrl+Space binding');
      expect(newFolders, 1);
    });

    testWidgets('unmodified keys do nothing', (tester) async {
      await pumpShortcuts(tester);
      await press(tester, LogicalKeyboardKey.keyF);
      await press(tester, LogicalKeyboardKey.space);
      expect(searches, 0);
      expect(news, 0);
    });

    // Screens pass null for an action that is currently unavailable (FAB
    // hidden while searching, selection mode active).
    testWidgets('null callbacks leave the key unbound', (tester) async {
      await pumpShortcuts(tester, withNew: false);
      await press(tester, LogicalKeyboardKey.space, control: true);
      expect(news, 0);
      await press(tester, LogicalKeyboardKey.keyF, control: true);
      expect(searches, 1, reason: 'other bindings still work');
    });

    // The wrapper's own autofocus wins over a descendant's `autofocus: true`
    // (whichever registers first wins, and the ancestor registers first), so
    // screens that want a field focused on open must request it imperatively —
    // as EditQuestionScreen / EditQuizScreen / EditFolderScreen all do. Keys
    // still reach the bindings from there, since the wrapper is an ancestor.
    testWidgets('an explicit requestFocus from the child wins, and the '
        'bindings still fire from that field', (tester) async {
      var saves = 0;
      final fieldNode = FocusNode();
      addTearDown(fieldNode.dispose);

      await tester.pumpWidget(MaterialApp(
        home: ScreenShortcuts(
          onSave: () => saves++,
          child: Scaffold(body: TextField(focusNode: fieldNode)),
        ),
      ));
      // Mirrors the screens' initState post-frame callback.
      fieldNode.requestFocus();
      await tester.pumpAndSettle();

      expect(fieldNode.hasFocus, isTrue);
      await press(tester, LogicalKeyboardKey.keyS, control: true);
      expect(saves, 1);
    });

    testWidgets('onEscape intercepts back instead of popping', (tester) async {
      var escapes = 0;
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Text('first')),
      ));
      navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => ScreenShortcuts(
          onEscape: () => escapes++,
          child: const Scaffold(body: Text('second')),
        ),
      ));
      await tester.pumpAndSettle();

      // main.dart's global Escape handler pops through maybePop, which is what
      // the PopScope inside ScreenShortcuts intercepts.
      await navKey.currentState!.maybePop();
      await tester.pumpAndSettle();

      expect(escapes, 1);
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('a null onEscape pops normally', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Text('first')),
      ));
      navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const ScreenShortcuts(
          child: Scaffold(body: Text('second')),
        ),
      ));
      await tester.pumpAndSettle();

      await navKey.currentState!.maybePop();
      await tester.pumpAndSettle();

      expect(find.text('second'), findsNothing);
    });
  });
}
