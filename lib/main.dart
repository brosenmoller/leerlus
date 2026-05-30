import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/models/user_question_data.dart';
import 'package:leerlus/screens/home_screen.dart';
import 'package:leerlus/services/favorites_service.dart' show FavoritesService;
import 'package:leerlus/services/notification_service.dart';
import 'package:leerlus/services/question_service.dart' show QuestionService;
import 'package:leerlus/services/settings_service.dart';
import 'package:leerlus/services/srs_service.dart' show SrsService;
import 'package:leerlus/services/statistics_service.dart';
import 'package:leerlus/services/streak_service.dart';
import 'package:leerlus/utils/app_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageDir = await getAppStorageDir();
  Hive.init(storageDir.path);
  Hive.registerAdapter(UserQuestionDataAdapter());

  final db = AppDatabase();

  final srsService = SrsService();
  final questionService = QuestionService();
  final favoritesService = FavoritesService();
  final settingsService = SettingsService();
  final notificationService = NotificationService();
  final streakService = StreakService();

  await srsService.init();
  await questionService.init(db);
  await favoritesService.init();
  await settingsService.init();
  await notificationService.init();
  await streakService.init();
  await StatisticsService().init();

  // Restore scheduled reminder after app restart.
  if (streakService.streakEnabled && streakService.notifsEnabled) {
    await notificationService.rescheduleReminder(
      hour: streakService.notifsHour,
      minute: streakService.notifsMinute,
      title: 'Leerlus',
      body: "Don't forget to study — keep your streak alive!",
    );
  }

  runApp(Leerlus(db: db));
}

class Leerlus extends StatefulWidget {
  final AppDatabase db;
  const Leerlus({super.key, required this.db});

  @override
  State<Leerlus> createState() => _LeerlusState();
}

class _LeerlusState extends State<Leerlus> {
  final SettingsService _settings = SettingsService();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _settings.localeNotifier.addListener(_onLocaleChanged);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    _settings.localeNotifier.removeListener(_onLocaleChanged);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _navigatorKey.currentState?.maybePop();
    }
    return false;
  }

  void _onLocaleChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Leerlus',
      locale: _settings.localeNotifier.value,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: HomeScreen(db: widget.db),
    );
  }
}
