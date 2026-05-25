import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_nl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('nl'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Leerlus'**
  String get appTitle;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @navBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get navBrowse;

  /// No description provided for @navBrowseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore quizzes & categories'**
  String get navBrowseSubtitle;

  /// No description provided for @navSpacedRepetition.
  ///
  /// In en, this message translates to:
  /// **'Spaced Repetition'**
  String get navSpacedRepetition;

  /// No description provided for @navSpacedRepetitionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review your due cards'**
  String get navSpacedRepetitionSubtitle;

  /// No description provided for @navFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navFavorites;

  /// No description provided for @navFavoritesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your saved quizzes'**
  String get navFavoritesSubtitle;

  /// No description provided for @navManageContent.
  ///
  /// In en, this message translates to:
  /// **'Manage Content'**
  String get navManageContent;

  /// No description provided for @navManageContentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create & edit questions'**
  String get navManageContentSubtitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsResetSrs.
  ///
  /// In en, this message translates to:
  /// **'Reset all SRS data'**
  String get settingsResetSrs;

  /// No description provided for @settingsResetSrsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset SRS Data'**
  String get settingsResetSrsDialogTitle;

  /// No description provided for @settingsResetSrsDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset all SRS data? This cannot be undone.'**
  String get settingsResetSrsDialogContent;

  /// No description provided for @settingsResetSrsSuccess.
  ///
  /// In en, this message translates to:
  /// **'All SRS data reset'**
  String get settingsResetSrsSuccess;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageDutch.
  ///
  /// In en, this message translates to:
  /// **'Dutch'**
  String get settingsLanguageDutch;

  /// No description provided for @srsAlgoSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'SRS Algorithm'**
  String get srsAlgoSectionTitle;

  /// No description provided for @srsAlgoSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust scheduling behaviour'**
  String get srsAlgoSectionSubtitle;

  /// No description provided for @srsAlgoLapseMultiplier.
  ///
  /// In en, this message translates to:
  /// **'Lapse multiplier'**
  String get srsAlgoLapseMultiplier;

  /// No description provided for @srsAlgoLapseDesc.
  ///
  /// In en, this message translates to:
  /// **'On \"Again\", keep this fraction of the card\'s current interval.'**
  String get srsAlgoLapseDesc;

  /// No description provided for @srsAlgoAgainPenalty.
  ///
  /// In en, this message translates to:
  /// **'Again - ease penalty'**
  String get srsAlgoAgainPenalty;

  /// No description provided for @srsAlgoAgainDesc.
  ///
  /// In en, this message translates to:
  /// **'How much the ease factor drops on each lapse.'**
  String get srsAlgoAgainDesc;

  /// No description provided for @srsAlgoHardPenalty.
  ///
  /// In en, this message translates to:
  /// **'Hard - ease penalty'**
  String get srsAlgoHardPenalty;

  /// No description provided for @srsAlgoHardDesc.
  ///
  /// In en, this message translates to:
  /// **'How much the ease factor drops on \"Hard\".'**
  String get srsAlgoHardDesc;

  /// No description provided for @srsAlgoGoodAdjust.
  ///
  /// In en, this message translates to:
  /// **'Good - ease adjustment'**
  String get srsAlgoGoodAdjust;

  /// No description provided for @srsAlgoGoodDesc.
  ///
  /// In en, this message translates to:
  /// **'How much the ease factor shifts on \"Good\". Default 0 keeps it neutral.'**
  String get srsAlgoGoodDesc;

  /// No description provided for @srsAlgoEasyBonus.
  ///
  /// In en, this message translates to:
  /// **'Easy - ease bonus'**
  String get srsAlgoEasyBonus;

  /// No description provided for @srsAlgoEasyDesc.
  ///
  /// In en, this message translates to:
  /// **'How much the ease factor rises on \"Easy\".'**
  String get srsAlgoEasyDesc;

  /// No description provided for @srsAlgoInitialEase.
  ///
  /// In en, this message translates to:
  /// **'Initial ease factor'**
  String get srsAlgoInitialEase;

  /// No description provided for @srsAlgoInitialEaseDesc.
  ///
  /// In en, this message translates to:
  /// **'Starting ease factor for newly enrolled cards.'**
  String get srsAlgoInitialEaseDesc;

  /// No description provided for @srsAlgoMaxInterval.
  ///
  /// In en, this message translates to:
  /// **'Max interval'**
  String get srsAlgoMaxInterval;

  /// No description provided for @srsAlgoMaxIntervalDesc.
  ///
  /// In en, this message translates to:
  /// **'Longest interval a card can be scheduled.'**
  String get srsAlgoMaxIntervalDesc;

  /// No description provided for @srsAlgoDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String srsAlgoDays(int count);

  /// No description provided for @srsAlgoResetDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get srsAlgoResetDefaults;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @foldersSection.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get foldersSection;

  /// No description provided for @quizzesSection.
  ///
  /// In en, this message translates to:
  /// **'Quizzes'**
  String get quizzesSection;

  /// No description provided for @emptyFolder.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get emptyFolder;

  /// No description provided for @searchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTooltip;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search folders & quizzes…'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get searchNoResults;

  /// No description provided for @streakSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streakSectionTitle;

  /// No description provided for @streakEnabledToggle.
  ///
  /// In en, this message translates to:
  /// **'Enable streak tracking'**
  String get streakEnabledToggle;

  /// No description provided for @streakEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Earn a streak day for each day you study'**
  String get streakEnabledSubtitle;

  /// No description provided for @streakNotifsToggle.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder'**
  String get streakNotifsToggle;

  /// No description provided for @streakNotifsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get a notification to keep your streak'**
  String get streakNotifsSubtitle;

  /// No description provided for @streakNotifsTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get streakNotifsTime;

  /// No description provided for @streakResetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset streak'**
  String get streakResetButton;

  /// No description provided for @streakResetDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset streak?'**
  String get streakResetDialogTitle;

  /// No description provided for @streakResetDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Your current streak will be lost.'**
  String get streakResetDialogContent;

  /// No description provided for @streakCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day streak} other{{count} day streak}}'**
  String streakCount(int count);

  /// No description provided for @streakFreezesRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No freezes left this week} =1{1 freeze left this week} other{{count} freezes left this week}}'**
  String streakFreezesRemaining(int count);

  /// No description provided for @streakContinued.
  ///
  /// In en, this message translates to:
  /// **'Streak continued!'**
  String get streakContinued;

  /// No description provided for @streakContinuedBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You\'re on a 1-day streak!} other{You\'re on a {count}-day streak!}}'**
  String streakContinuedBody(int count);

  /// No description provided for @streakFreezeUsed.
  ///
  /// In en, this message translates to:
  /// **'Freeze used!'**
  String get streakFreezeUsed;

  /// No description provided for @streakFreezeUsedBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No freezes left this week} =1{1 freeze left this week} other{{count} freezes left this week}}'**
  String streakFreezeUsedBody(int count);

  /// No description provided for @streakReset.
  ///
  /// In en, this message translates to:
  /// **'Streak reset'**
  String get streakReset;

  /// No description provided for @streakResetBody.
  ///
  /// In en, this message translates to:
  /// **'Out of freezes — starting fresh at 1 day.'**
  String get streakResetBody;

  /// No description provided for @streakInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streakInfoTitle;

  /// No description provided for @streakBest.
  ///
  /// In en, this message translates to:
  /// **'Best: {count, plural, =1{1 day} other{{count} days}}'**
  String streakBest(int count);

  /// No description provided for @streakFreezesRestockOn.
  ///
  /// In en, this message translates to:
  /// **'Restocks on {date}'**
  String streakFreezesRestockOn(String date);

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTitle;

  /// No description provided for @favoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No favorite quizzes yet.'**
  String get favoritesEmpty;

  /// No description provided for @srsTitle.
  ///
  /// In en, this message translates to:
  /// **'Spaced Repetition'**
  String get srsTitle;

  /// No description provided for @srsNoQuestions.
  ///
  /// In en, this message translates to:
  /// **'No spaced repetition questions available'**
  String get srsNoQuestions;

  /// No description provided for @srsDue.
  ///
  /// In en, this message translates to:
  /// **'{count} due'**
  String srsDue(int count);

  /// No description provided for @srsCards.
  ///
  /// In en, this message translates to:
  /// **'{count} cards'**
  String srsCards(int count);

  /// No description provided for @srsOldestOverdue.
  ///
  /// In en, this message translates to:
  /// **'oldest {time} overdue'**
  String srsOldestOverdue(String time);

  /// No description provided for @srsNextIn.
  ///
  /// In en, this message translates to:
  /// **'next in {time}'**
  String srsNextIn(String time);

  /// No description provided for @srsStartNormalQuiz.
  ///
  /// In en, this message translates to:
  /// **'Start normal quiz'**
  String get srsStartNormalQuiz;

  /// No description provided for @srsNoSrsScheduling.
  ///
  /// In en, this message translates to:
  /// **'No SRS scheduling'**
  String get srsNoSrsScheduling;

  /// No description provided for @srsRemoveFromSrs.
  ///
  /// In en, this message translates to:
  /// **'Remove from SRS'**
  String get srsRemoveFromSrs;

  /// No description provided for @srsRemoveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from spaced repetition?'**
  String get srsRemoveDialogTitle;

  /// No description provided for @srsRemoveDialogContent.
  ///
  /// In en, this message translates to:
  /// **'All SRS progress for \"{quizTitle}\" will be lost. This cannot be undone.'**
  String srsRemoveDialogContent(String quizTitle);

  /// No description provided for @srsNoQuestionsDue.
  ///
  /// In en, this message translates to:
  /// **'No questions due'**
  String get srsNoQuestionsDue;

  /// No description provided for @srsSessionComplete.
  ///
  /// In en, this message translates to:
  /// **'Session Complete'**
  String get srsSessionComplete;

  /// No description provided for @srsQuestionsReviewed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 question reviewed} other{{count} questions reviewed}}'**
  String srsQuestionsReviewed(int count);

  /// No description provided for @srsAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up!'**
  String get srsAllCaughtUp;

  /// No description provided for @srsNoMoreDue.
  ///
  /// In en, this message translates to:
  /// **'No more questions due right now.'**
  String get srsNoMoreDue;

  /// No description provided for @srsStillDue.
  ///
  /// In en, this message translates to:
  /// **'Still due'**
  String get srsStillDue;

  /// No description provided for @srsQuestionsDue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 question due} other{{count} questions due}}'**
  String srsQuestionsDue(int count);

  /// No description provided for @srsBackToSpacedRepetition.
  ///
  /// In en, this message translates to:
  /// **'Back to Spaced Repetition'**
  String get srsBackToSpacedRepetition;

  /// No description provided for @srsHowWellKnew.
  ///
  /// In en, this message translates to:
  /// **'How well did you know this?'**
  String get srsHowWellKnew;

  /// No description provided for @srsAgain.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get srsAgain;

  /// No description provided for @srsHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get srsHard;

  /// No description provided for @srsGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get srsGood;

  /// No description provided for @srsEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get srsEasy;

  /// No description provided for @durationNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get durationNow;

  /// No description provided for @durationDays.
  ///
  /// In en, this message translates to:
  /// **'{n}d'**
  String durationDays(int n);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{n}h'**
  String durationHours(int n);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n}m'**
  String durationMinutes(int n);

  /// No description provided for @quizCompleted.
  ///
  /// In en, this message translates to:
  /// **'Quiz Completed'**
  String get quizCompleted;

  /// No description provided for @noQuestions.
  ///
  /// In en, this message translates to:
  /// **'No questions'**
  String get noQuestions;

  /// No description provided for @manageContentTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Content'**
  String get manageContentTitle;

  /// No description provided for @addFolder.
  ///
  /// In en, this message translates to:
  /// **'Add Folder'**
  String get addFolder;

  /// No description provided for @addQuiz.
  ///
  /// In en, this message translates to:
  /// **'Add Quiz'**
  String get addQuiz;

  /// No description provided for @addQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add Question'**
  String get addQuestion;

  /// No description provided for @importJsonTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import (.lus / .json)'**
  String get importJsonTooltip;

  /// No description provided for @exportJsonTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export (.lus)'**
  String get exportJsonTooltip;

  /// No description provided for @exportSeedDbTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export seed.db'**
  String get exportSeedDbTooltip;

  /// No description provided for @exportFolderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export folder'**
  String get exportFolderTooltip;

  /// No description provided for @exportQuizTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export quiz'**
  String get exportQuizTooltip;

  /// No description provided for @moveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get moveTooltip;

  /// No description provided for @moveToFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to folder'**
  String get moveToFolderTitle;

  /// No description provided for @moveToRootOption.
  ///
  /// In en, this message translates to:
  /// **'Root (no folder)'**
  String get moveToRootOption;

  /// No description provided for @contentPacksTitle.
  ///
  /// In en, this message translates to:
  /// **'Content Packs'**
  String get contentPacksTitle;

  /// No description provided for @contentPacksTooltip.
  ///
  /// In en, this message translates to:
  /// **'Browse content packs'**
  String get contentPacksTooltip;

  /// No description provided for @contentPacksImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get contentPacksImport;

  /// No description provided for @contentPacksImportedCount.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} new items'**
  String contentPacksImportedCount(int count);

  /// No description provided for @contentPacksAlreadyUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Already up to date'**
  String get contentPacksAlreadyUpToDate;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Import successful'**
  String get importSuccess;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(Object error);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(Object error);

  /// No description provided for @folderContents.
  ///
  /// In en, this message translates to:
  /// **'Folder contents'**
  String get folderContents;

  /// No description provided for @emptyFolderManage.
  ///
  /// In en, this message translates to:
  /// **'Empty. Tap + to add a folder or quiz.'**
  String get emptyFolderManage;

  /// No description provided for @builtIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get builtIn;

  /// No description provided for @builtInDebug.
  ///
  /// In en, this message translates to:
  /// **'Built-in (editable in debug)'**
  String get builtInDebug;

  /// No description provided for @deleteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Folder?'**
  String get deleteFolderTitle;

  /// No description provided for @deleteFolderContent.
  ///
  /// In en, this message translates to:
  /// **'This will delete \"{name}\" and everything inside it.'**
  String deleteFolderContent(String name);

  /// No description provided for @deleteQuizTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Quiz?'**
  String get deleteQuizTitle;

  /// No description provided for @deleteQuizContent.
  ///
  /// In en, this message translates to:
  /// **'This will delete \"{name}\" and all its questions.'**
  String deleteQuizContent(String name);

  /// No description provided for @questionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get questionsSubtitle;

  /// No description provided for @noQuestionsYet.
  ///
  /// In en, this message translates to:
  /// **'No questions yet. Add one below.'**
  String get noQuestionsYet;

  /// No description provided for @deleteQuestionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Question?'**
  String get deleteQuestionTitle;

  /// No description provided for @answerTypeMultipleChoiceChip.
  ///
  /// In en, this message translates to:
  /// **'Multiple choice'**
  String get answerTypeMultipleChoiceChip;

  /// No description provided for @answerTypeTypedChip.
  ///
  /// In en, this message translates to:
  /// **'Typed'**
  String get answerTypeTypedChip;

  /// No description provided for @answerTypeImageClickChip.
  ///
  /// In en, this message translates to:
  /// **'Image click'**
  String get answerTypeImageClickChip;

  /// No description provided for @editFolderAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Folder'**
  String get editFolderAppBarTitle;

  /// No description provided for @addFolderAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Folder'**
  String get addFolderAppBarTitle;

  /// No description provided for @folderNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderNameLabel;

  /// No description provided for @folderImageOptional.
  ///
  /// In en, this message translates to:
  /// **'Folder image (optional)'**
  String get folderImageOptional;

  /// No description provided for @editQuizAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Quiz'**
  String get editQuizAppBarTitle;

  /// No description provided for @addQuizAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Quiz'**
  String get addQuizAppBarTitle;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @quizImageOptional.
  ///
  /// In en, this message translates to:
  /// **'Quiz image (optional)'**
  String get quizImageOptional;

  /// No description provided for @languageCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Language code'**
  String get languageCodeLabel;

  /// No description provided for @languageCodeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. en, nl, de, fr'**
  String get languageCodeHint;

  /// No description provided for @editQuestionAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Question'**
  String get editQuestionAppBarTitle;

  /// No description provided for @addQuestionAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Question'**
  String get addQuestionAppBarTitle;

  /// No description provided for @questionLabel.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get questionLabel;

  /// No description provided for @answerTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Answer type'**
  String get answerTypeLabel;

  /// No description provided for @optionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get optionsLabel;

  /// No description provided for @optionN.
  ///
  /// In en, this message translates to:
  /// **'Option {n}'**
  String optionN(int n);

  /// No description provided for @radioCorrectHint.
  ///
  /// In en, this message translates to:
  /// **'Radio button = correct answer'**
  String get radioCorrectHint;

  /// No description provided for @checkboxCorrectHint.
  ///
  /// In en, this message translates to:
  /// **'Check all correct answers'**
  String get checkboxCorrectHint;

  /// No description provided for @addOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get addOption;

  /// No description provided for @multipleCorrectAnswers.
  ///
  /// In en, this message translates to:
  /// **'Multiple correct answers'**
  String get multipleCorrectAnswers;

  /// No description provided for @showCorrectCount.
  ///
  /// In en, this message translates to:
  /// **'Show answer count'**
  String get showCorrectCount;

  /// No description provided for @showCorrectCountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell students how many answers to select'**
  String get showCorrectCountSubtitle;

  /// No description provided for @checkAnswer.
  ///
  /// In en, this message translates to:
  /// **'Check answer'**
  String get checkAnswer;

  /// No description provided for @selectAllThatApply.
  ///
  /// In en, this message translates to:
  /// **'Select all that apply'**
  String get selectAllThatApply;

  /// No description provided for @selectNCorrectAnswers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Select 1 correct answer} other{Select {count} correct answers}}'**
  String selectNCorrectAnswers(int count);

  /// No description provided for @selectAtLeastOneCorrect.
  ///
  /// In en, this message translates to:
  /// **'Please mark at least one option as correct'**
  String get selectAtLeastOneCorrect;

  /// No description provided for @duplicateOption.
  ///
  /// In en, this message translates to:
  /// **'Options must be unique'**
  String get duplicateOption;

  /// No description provided for @acceptedAnswersLabel.
  ///
  /// In en, this message translates to:
  /// **'Accepted Answers'**
  String get acceptedAnswersLabel;

  /// No description provided for @acceptedAnswerN.
  ///
  /// In en, this message translates to:
  /// **'Accepted answer {n}'**
  String acceptedAnswerN(int n);

  /// No description provided for @atLeastOneRequired.
  ///
  /// In en, this message translates to:
  /// **'At least one required'**
  String get atLeastOneRequired;

  /// No description provided for @addVariant.
  ///
  /// In en, this message translates to:
  /// **'Add variant'**
  String get addVariant;

  /// No description provided for @clickAreaImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Click area image'**
  String get clickAreaImageLabel;

  /// No description provided for @defineClickAreas.
  ///
  /// In en, this message translates to:
  /// **'Define Click Areas'**
  String get defineClickAreas;

  /// No description provided for @editClickAreas.
  ///
  /// In en, this message translates to:
  /// **'Edit Click Areas ({count, plural, =1{1 area} other{{count} areas}})'**
  String editClickAreas(int count);

  /// No description provided for @areasDefinedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 area} other{{count} areas}} defined ✓'**
  String areasDefinedCount(int count);

  /// No description provided for @pleaseDefineClickArea.
  ///
  /// In en, this message translates to:
  /// **'Please define at least one click area'**
  String get pleaseDefineClickArea;

  /// No description provided for @flashcardRandomize.
  ///
  /// In en, this message translates to:
  /// **'Randomize front/back sides'**
  String get flashcardRandomize;

  /// No description provided for @flashcardRandomizeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Each attempt randomly picks which side to show first'**
  String get flashcardRandomizeSubtitle;

  /// No description provided for @flashcardFrontSide.
  ///
  /// In en, this message translates to:
  /// **'Front side'**
  String get flashcardFrontSide;

  /// No description provided for @flashcardBackSide.
  ///
  /// In en, this message translates to:
  /// **'Back side'**
  String get flashcardBackSide;

  /// No description provided for @flashcardFrontTextOptional.
  ///
  /// In en, this message translates to:
  /// **'Front text (optional)'**
  String get flashcardFrontTextOptional;

  /// No description provided for @flashcardBackTextOptional.
  ///
  /// In en, this message translates to:
  /// **'Back text (optional)'**
  String get flashcardBackTextOptional;

  /// No description provided for @flashcardFrontImageOptional.
  ///
  /// In en, this message translates to:
  /// **'Front image (optional)'**
  String get flashcardFrontImageOptional;

  /// No description provided for @flashcardBackImageOptional.
  ///
  /// In en, this message translates to:
  /// **'Back image (optional)'**
  String get flashcardBackImageOptional;

  /// No description provided for @flashcardFrontRequired.
  ///
  /// In en, this message translates to:
  /// **'Front side needs at least text or an image'**
  String get flashcardFrontRequired;

  /// No description provided for @flashcardBackRequired.
  ///
  /// In en, this message translates to:
  /// **'Back side needs at least text or an image'**
  String get flashcardBackRequired;

  /// No description provided for @questionImageOptional.
  ///
  /// In en, this message translates to:
  /// **'Question image (optional)'**
  String get questionImageOptional;

  /// No description provided for @explanationOptional.
  ///
  /// In en, this message translates to:
  /// **'Explanation (optional)'**
  String get explanationOptional;

  /// No description provided for @saveQuestion.
  ///
  /// In en, this message translates to:
  /// **'Save Question'**
  String get saveQuestion;

  /// No description provided for @answerTypeMCLabel.
  ///
  /// In en, this message translates to:
  /// **'Multiple Choice'**
  String get answerTypeMCLabel;

  /// No description provided for @answerTypeTypedLabel.
  ///
  /// In en, this message translates to:
  /// **'Typed'**
  String get answerTypeTypedLabel;

  /// No description provided for @answerTypeImageClickLabel.
  ///
  /// In en, this message translates to:
  /// **'Image Click'**
  String get answerTypeImageClickLabel;

  /// No description provided for @answerTypeFlashcardLabel.
  ///
  /// In en, this message translates to:
  /// **'Flashcard'**
  String get answerTypeFlashcardLabel;

  /// No description provided for @answerTypeSortingLabel.
  ///
  /// In en, this message translates to:
  /// **'Sorting'**
  String get answerTypeSortingLabel;

  /// No description provided for @answerTypeSortingChip.
  ///
  /// In en, this message translates to:
  /// **'Sorting'**
  String get answerTypeSortingChip;

  /// No description provided for @answerTypeSetLabel.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get answerTypeSetLabel;

  /// No description provided for @answerTypeSetChip.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get answerTypeSetChip;

  /// No description provided for @setAnswersLabel.
  ///
  /// In en, this message translates to:
  /// **'Correct answers'**
  String get setAnswersLabel;

  /// No description provided for @setAnswerN.
  ///
  /// In en, this message translates to:
  /// **'Answer {n}'**
  String setAnswerN(int n);

  /// No description provided for @setAddAnswer.
  ///
  /// In en, this message translates to:
  /// **'Add answer'**
  String get setAddAnswer;

  /// No description provided for @setAtLeastTwo.
  ///
  /// In en, this message translates to:
  /// **'At least 2 answers required'**
  String get setAtLeastTwo;

  /// No description provided for @setHint.
  ///
  /// In en, this message translates to:
  /// **'Type an answer…'**
  String get setHint;

  /// No description provided for @setAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get setAdd;

  /// No description provided for @setMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get setMissed;

  /// No description provided for @sortingItemsLabel.
  ///
  /// In en, this message translates to:
  /// **'Items (correct order, top → bottom)'**
  String get sortingItemsLabel;

  /// No description provided for @sortingItemN.
  ///
  /// In en, this message translates to:
  /// **'Item {n}'**
  String sortingItemN(int n);

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addItem;

  /// No description provided for @showPreFilled.
  ///
  /// In en, this message translates to:
  /// **'Show items pre-filled'**
  String get showPreFilled;

  /// No description provided for @showPreFilledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Students drag items into the correct order; disable to have them type each item'**
  String get showPreFilledSubtitle;

  /// No description provided for @checkOrder.
  ///
  /// In en, this message translates to:
  /// **'Check order'**
  String get checkOrder;

  /// No description provided for @sortingDragHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get sortingDragHint;

  /// No description provided for @sortingCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct: {answer}'**
  String sortingCorrectAnswer(String answer);

  /// No description provided for @unsavedChangesQuestion.
  ///
  /// In en, this message translates to:
  /// **'Your question changes will be lost.'**
  String get unsavedChangesQuestion;

  /// No description provided for @discardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// No description provided for @discardChangesDefault.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes that will be lost.'**
  String get discardChangesDefault;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @navSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get navSync;

  /// No description provided for @navSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync all content between two devices'**
  String get navSyncSubtitle;

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncTitle;

  /// No description provided for @syncInfo.
  ///
  /// In en, this message translates to:
  /// **'Open this screen on both devices and make sure they are on the same Wi-Fi network.'**
  String get syncInfo;

  /// No description provided for @syncNearbyDevices.
  ///
  /// In en, this message translates to:
  /// **'Nearby devices'**
  String get syncNearbyDevices;

  /// No description provided for @syncDiscovering.
  ///
  /// In en, this message translates to:
  /// **'Searching for devices on your network…'**
  String get syncDiscovering;

  /// No description provided for @syncRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get syncRefresh;

  /// No description provided for @syncWaitingForIncoming.
  ///
  /// In en, this message translates to:
  /// **'Waiting for incoming sync'**
  String get syncWaitingForIncoming;

  /// No description provided for @syncWaitingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Another device can initiate a sync with you'**
  String get syncWaitingSubtitle;

  /// No description provided for @syncRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the other device to accept…'**
  String get syncRequestSent;

  /// No description provided for @syncConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Sync with {deviceName}?'**
  String syncConfirmMessage(String deviceName);

  /// No description provided for @syncAcceptTitle.
  ///
  /// In en, this message translates to:
  /// **'Incoming sync request'**
  String get syncAcceptTitle;

  /// No description provided for @syncAcceptMessage.
  ///
  /// In en, this message translates to:
  /// **'{deviceName} wants to sync with you.'**
  String syncAcceptMessage(String deviceName);

  /// No description provided for @syncAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get syncAccept;

  /// No description provided for @syncReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get syncReject;

  /// No description provided for @syncInProgress.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncInProgress;

  /// No description provided for @syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get syncComplete;

  /// No description provided for @syncAlreadyUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Everything is already up to date.'**
  String get syncAlreadyUpToDate;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncFailed;

  /// No description provided for @syncSyncAgain.
  ///
  /// In en, this message translates to:
  /// **'Sync again'**
  String get syncSyncAgain;

  /// No description provided for @syncResultFolders.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 folder added} other{{count} folders added}}'**
  String syncResultFolders(int count);

  /// No description provided for @syncResultQuizzes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 quiz added} other{{count} quizzes added}}'**
  String syncResultQuizzes(int count);

  /// No description provided for @syncResultQuestions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 question added} other{{count} questions added}}'**
  String syncResultQuestions(int count);

  /// No description provided for @syncResultSrs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 SRS entry updated} other{{count} SRS entries updated}}'**
  String syncResultSrs(int count);

  /// No description provided for @syncPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Network permission required'**
  String get syncPermissionTitle;

  /// No description provided for @syncPermissionRationale.
  ///
  /// In en, this message translates to:
  /// **'To discover nearby devices on your network, Leerlus needs the Nearby Wi-Fi Devices permission.'**
  String get syncPermissionRationale;

  /// No description provided for @syncPermissionGrantButton.
  ///
  /// In en, this message translates to:
  /// **'Grant permission'**
  String get syncPermissionGrantButton;

  /// No description provided for @syncPermissionPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission was permanently denied. Please enable it in app settings.'**
  String get syncPermissionPermanentlyDenied;

  /// No description provided for @syncOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get syncOpenSettings;

  /// No description provided for @settingsAnimations.
  ///
  /// In en, this message translates to:
  /// **'Animations'**
  String get settingsAnimations;

  /// No description provided for @settingsAnimationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show confetti and other visual effects'**
  String get settingsAnimationsSubtitle;

  /// No description provided for @syncThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get syncThisDevice;

  /// No description provided for @syncDiscoverableAs.
  ///
  /// In en, this message translates to:
  /// **'Discoverable as: {name}'**
  String syncDiscoverableAs(String name);

  /// No description provided for @occlusionSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Image Occlusion'**
  String get occlusionSectionTitle;

  /// No description provided for @defineOcclusionAreas.
  ///
  /// In en, this message translates to:
  /// **'Define Occlusion Areas'**
  String get defineOcclusionAreas;

  /// No description provided for @editOcclusionAreas.
  ///
  /// In en, this message translates to:
  /// **'Edit Occlusion Areas'**
  String get editOcclusionAreas;

  /// No description provided for @occlusionSummary.
  ///
  /// In en, this message translates to:
  /// **'{hidden} hidden, {highlight} highlighted ✓'**
  String occlusionSummary(int hidden, int highlight);

  /// No description provided for @occlusionNoImage.
  ///
  /// In en, this message translates to:
  /// **'Set an image first to add occlusion'**
  String get occlusionNoImage;

  /// No description provided for @occlusionHideMode.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get occlusionHideMode;

  /// No description provided for @occlusionHighlightMode.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get occlusionHighlightMode;

  /// No description provided for @occlusionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear occlusion'**
  String get occlusionClear;

  /// No description provided for @imageLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Image Library'**
  String get imageLibraryTitle;

  /// No description provided for @imageLibrarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage images on this device'**
  String get imageLibrarySubtitle;

  /// No description provided for @imageLibraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No images found'**
  String get imageLibraryEmpty;

  /// No description provided for @imageNotUsed.
  ///
  /// In en, this message translates to:
  /// **'Not used'**
  String get imageNotUsed;

  /// No description provided for @imageBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get imageBuiltIn;

  /// No description provided for @imageDeleteUnused.
  ///
  /// In en, this message translates to:
  /// **'Delete unused'**
  String get imageDeleteUnused;

  /// No description provided for @imageDeleteUnusedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} unused image(s)? This cannot be undone.'**
  String imageDeleteUnusedConfirm(int count);

  /// No description provided for @imageDeleteUnusedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} image(s)'**
  String imageDeleteUnusedSuccess(int count);

  /// No description provided for @imageUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload image'**
  String get imageUpload;

  /// No description provided for @imageUploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Image added to library'**
  String get imageUploadSuccess;

  /// No description provided for @imageDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this image? It is not used anywhere and will be permanently removed.'**
  String get imageDeleteConfirm;

  /// No description provided for @imageUsedByTitle.
  ///
  /// In en, this message translates to:
  /// **'Image usage'**
  String get imageUsedByTitle;

  /// No description provided for @deleteOrphanImages.
  ///
  /// In en, this message translates to:
  /// **'Also delete {count} unused image(s)'**
  String deleteOrphanImages(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'nl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'nl':
      return AppLocalizationsNl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
