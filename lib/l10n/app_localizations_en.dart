// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Leerlus';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get navBrowse => 'Browse';

  @override
  String get navBrowseSubtitle => 'Explore quizzes & categories';

  @override
  String get navSpacedRepetition => 'Spaced Repetition';

  @override
  String get navSpacedRepetitionSubtitle => 'Review your due cards';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navFavoritesSubtitle => 'Your saved quizzes';

  @override
  String get navManageContent => 'Manage Content';

  @override
  String get navManageContentSubtitle => 'Create & edit questions';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsResetSrs => 'Reset all SRS data';

  @override
  String get settingsResetSrsDialogTitle => 'Reset SRS Data';

  @override
  String get settingsResetSrsDialogContent =>
      'Are you sure you want to reset all SRS data? This cannot be undone.';

  @override
  String get settingsResetSrsSuccess => 'All SRS data reset';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageDutch => 'Dutch';

  @override
  String get srsAlgoSectionTitle => 'SRS Algorithm';

  @override
  String get srsAlgoSectionSubtitle => 'Adjust scheduling behaviour';

  @override
  String get srsAlgoLapseMultiplier => 'Lapse multiplier';

  @override
  String get srsAlgoLapseDesc =>
      'On \"Again\", keep this fraction of the card\'s current interval.';

  @override
  String get srsAlgoAgainPenalty => 'Again - ease penalty';

  @override
  String get srsAlgoAgainDesc =>
      'How much the ease factor drops on each lapse.';

  @override
  String get srsAlgoHardPenalty => 'Hard - ease penalty';

  @override
  String get srsAlgoHardDesc => 'How much the ease factor drops on \"Hard\".';

  @override
  String get srsAlgoGoodAdjust => 'Good - ease adjustment';

  @override
  String get srsAlgoGoodDesc =>
      'How much the ease factor shifts on \"Good\". Default 0 keeps it neutral.';

  @override
  String get srsAlgoEasyBonus => 'Easy - ease bonus';

  @override
  String get srsAlgoEasyDesc => 'How much the ease factor rises on \"Easy\".';

  @override
  String get srsAlgoEasyMinInterval => 'Easy - min. interval';

  @override
  String get srsAlgoEasyMinIntervalDesc =>
      'Minimum next-review interval when pressing Easy. Prevents small intervals from multiplying into hours instead of days. Set to Off to disable.';

  @override
  String get srsAlgoEasyMinOff => 'Off';

  @override
  String get srsAlgoInitialEase => 'Initial ease factor';

  @override
  String get srsAlgoInitialEaseDesc =>
      'Starting ease factor for newly enrolled cards.';

  @override
  String get srsAlgoMaxInterval => 'Max interval';

  @override
  String get srsAlgoMaxIntervalDesc =>
      'Longest interval a card can be scheduled.';

  @override
  String srsAlgoDays(int count) {
    return '$count days';
  }

  @override
  String srsAlgoMonths(int count) {
    return '$count mo';
  }

  @override
  String srsAlgoYears(int count) {
    return '$count yr';
  }

  @override
  String get srsAlgoResetDefaults => 'Reset to defaults';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get reset => 'Reset';

  @override
  String get edit => 'Edit';

  @override
  String get required => 'Required';

  @override
  String get start => 'Start';

  @override
  String get retry => 'Retry';

  @override
  String get back => 'Back';

  @override
  String get home => 'Home';

  @override
  String get remove => 'Remove';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get foldersSection => 'Folders';

  @override
  String get quizzesSection => 'Quizzes';

  @override
  String get emptyFolder => 'Nothing here yet.';

  @override
  String get searchTooltip => 'Search';

  @override
  String get searchHint => 'Search folders & quizzes…';

  @override
  String get searchNoResults => 'No results found.';

  @override
  String get streakSectionTitle => 'Streak';

  @override
  String get streakEnabledToggle => 'Enable streak tracking';

  @override
  String get streakEnabledSubtitle =>
      'Earn a streak day for each day you study';

  @override
  String get streakNotifsToggle => 'Daily reminder';

  @override
  String get streakNotifsSubtitle => 'Get a notification to keep your streak';

  @override
  String get streakNotifsTime => 'Reminder time';

  @override
  String get streakResetButton => 'Reset streak';

  @override
  String get streakResetDialogTitle => 'Reset streak?';

  @override
  String get streakResetDialogContent => 'Your current streak will be lost.';

  @override
  String streakCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count day streak',
      one: '1 day streak',
    );
    return '$_temp0';
  }

  @override
  String streakFreezesRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count freezes left this week',
      one: '1 freeze left this week',
      zero: 'No freezes left this week',
    );
    return '$_temp0';
  }

  @override
  String get streakContinued => 'Streak continued!';

  @override
  String streakContinuedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You\'re on a $count-day streak!',
      one: 'You\'re on a 1-day streak!',
    );
    return '$_temp0';
  }

  @override
  String get streakFreezeUsed => 'Freeze used!';

  @override
  String streakFreezeUsedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count freezes left this week',
      one: '1 freeze left this week',
      zero: 'No freezes left this week',
    );
    return '$_temp0';
  }

  @override
  String get streakReset => 'Streak reset';

  @override
  String get streakResetBody => 'Out of freezes, starting fresh at 1 day.';

  @override
  String get streakInfoTitle => 'Streak';

  @override
  String streakBest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return 'Best: $_temp0';
  }

  @override
  String streakFreezesRestockOn(String date) {
    return 'Restocks on $date';
  }

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritesEmpty => 'No favorite quizzes yet.';

  @override
  String get srsTitle => 'Spaced Repetition';

  @override
  String get srsNoQuestions => 'No spaced repetition questions available';

  @override
  String srsDue(int count) {
    return '$count due';
  }

  @override
  String srsCards(int count) {
    return '$count cards';
  }

  @override
  String srsOldestOverdue(String time) {
    return 'oldest $time overdue';
  }

  @override
  String srsNextIn(String time) {
    return 'next in $time';
  }

  @override
  String get srsStartNormalQuiz => 'Start normal quiz';

  @override
  String get srsNoSrsScheduling => 'No SRS scheduling';

  @override
  String get srsRemoveFromSrs => 'Remove from SRS';

  @override
  String get srsRemoveDialogTitle => 'Remove from spaced repetition?';

  @override
  String srsRemoveDialogContent(String quizTitle) {
    return 'All SRS progress for \"$quizTitle\" will be lost. This cannot be undone.';
  }

  @override
  String get srsNoQuestionsDue => 'No questions due';

  @override
  String get srsSessionComplete => 'Session Complete';

  @override
  String srsQuestionsReviewed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions reviewed',
      one: '1 question reviewed',
    );
    return '$_temp0';
  }

  @override
  String get srsAllCaughtUp => 'All caught up!';

  @override
  String get srsNoMoreDue => 'No more questions due right now.';

  @override
  String get srsStillDue => 'Still due';

  @override
  String srsQuestionsDue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions due',
      one: '1 question due',
    );
    return '$_temp0';
  }

  @override
  String get srsBackToSpacedRepetition => 'Back to Spaced Repetition';

  @override
  String get srsReviewAll => 'Review all';

  @override
  String get srsAllDueTitle => 'All due questions';

  @override
  String get srsHowWellKnew => 'How well did you know this?';

  @override
  String get srsAgain => 'Again';

  @override
  String get srsHard => 'Hard';

  @override
  String get srsGood => 'Good';

  @override
  String get srsEasy => 'Easy';

  @override
  String get durationNow => 'now';

  @override
  String durationSeconds(int n) {
    return '${n}s';
  }

  @override
  String durationDays(int n) {
    return '${n}d';
  }

  @override
  String durationHours(int n) {
    return '${n}h';
  }

  @override
  String durationMinutes(int n) {
    return '${n}m';
  }

  @override
  String get quizCompleted => 'Quiz Completed';

  @override
  String get noQuestions => 'No questions';

  @override
  String get manageContentTitle => 'Manage Content';

  @override
  String get addFolder => 'Add Folder';

  @override
  String get addQuiz => 'Add Quiz';

  @override
  String get addQuestion => 'Add Question';

  @override
  String get importJsonTooltip => 'Import (.lus)';

  @override
  String get exportJsonTooltip => 'Export (.lus)';

  @override
  String get exportFolderTooltip => 'Export folder';

  @override
  String get exportQuizTooltip => 'Export quiz';

  @override
  String get moveTooltip => 'Move';

  @override
  String get moveToFolderTitle => 'Move to folder';

  @override
  String get moveToRootOption => 'Root (no folder)';

  @override
  String get contentPacksTitle => 'Content Packs';

  @override
  String get contentPacksTooltip => 'Browse content packs';

  @override
  String get contentPacksImport => 'Import';

  @override
  String contentPacksImportedCount(int count) {
    return 'Imported $count new items';
  }

  @override
  String get contentPacksAlreadyUpToDate => 'Already up to date';

  @override
  String get contentPacksNoneAvailable => 'No content packs available';

  @override
  String get importSuccess => 'Import successful';

  @override
  String importFailed(Object error) {
    return 'Import failed: $error';
  }

  @override
  String exportFailed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get folderContents => 'Folder contents';

  @override
  String get emptyFolderManage => 'Empty. Tap + to add a folder or quiz.';

  @override
  String get builtIn => 'Built-in';

  @override
  String get builtInDebug => 'Built-in (editable in debug)';

  @override
  String get deleteFolderTitle => 'Delete Folder?';

  @override
  String deleteFolderContent(String name) {
    return 'This will delete \"$name\" and everything inside it.';
  }

  @override
  String get deleteQuizTitle => 'Delete Quiz?';

  @override
  String deleteQuizContent(String name) {
    return 'This will delete \"$name\" and all its questions.';
  }

  @override
  String get questionsSubtitle => 'Questions';

  @override
  String get noQuestionsYet => 'No questions yet. Add one below.';

  @override
  String get deleteQuestionTitle => 'Delete Question?';

  @override
  String get answerTypeMultipleChoiceChip => 'Multiple choice';

  @override
  String get answerTypeTypedChip => 'Typed';

  @override
  String get answerTypeImageClickChip => 'Image click';

  @override
  String get editFolderAppBarTitle => 'Edit Folder';

  @override
  String get addFolderAppBarTitle => 'Add Folder';

  @override
  String get folderNameLabel => 'Folder name';

  @override
  String get folderImageOptional => 'Folder image (optional)';

  @override
  String get editQuizAppBarTitle => 'Edit Quiz';

  @override
  String get addQuizAppBarTitle => 'Add Quiz';

  @override
  String get titleLabel => 'Title';

  @override
  String get quizImageOptional => 'Quiz image (optional)';

  @override
  String get languageCodeLabel => 'Language code';

  @override
  String get languageCodeHint => 'e.g. en, nl, de, fr';

  @override
  String get editQuestionAppBarTitle => 'Edit Question';

  @override
  String get addQuestionAppBarTitle => 'Add Question';

  @override
  String get questionLabel => 'Question';

  @override
  String get answerTypeLabel => 'Answer type';

  @override
  String get optionsLabel => 'Options';

  @override
  String optionN(int n) {
    return 'Option $n';
  }

  @override
  String get radioCorrectHint => 'Radio button = correct answer';

  @override
  String get checkboxCorrectHint => 'Check all correct answers';

  @override
  String get addOption => 'Add option';

  @override
  String get multipleCorrectAnswers => 'Multiple correct answers';

  @override
  String get showCorrectCount => 'Show answer count';

  @override
  String get showCorrectCountSubtitle =>
      'Tell students how many answers to select';

  @override
  String get checkAnswer => 'Check answer';

  @override
  String get selectAllThatApply => 'Select all that apply';

  @override
  String selectNCorrectAnswers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Select $count correct answers',
      one: 'Select 1 correct answer',
    );
    return '$_temp0';
  }

  @override
  String get selectAtLeastOneCorrect =>
      'Please mark at least one option as correct';

  @override
  String get duplicateOption => 'Options must be unique';

  @override
  String get acceptedAnswersLabel => 'Accepted Answers';

  @override
  String acceptedAnswerN(int n) {
    return 'Accepted answer $n';
  }

  @override
  String get atLeastOneRequired => 'At least one required';

  @override
  String get addVariant => 'Add variant';

  @override
  String get clickAreaImageLabel => 'Click area image';

  @override
  String get defineClickAreas => 'Define Click Areas';

  @override
  String editClickAreas(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count areas',
      one: '1 area',
    );
    return 'Edit Click Areas ($_temp0)';
  }

  @override
  String areasDefinedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count areas',
      one: '1 area',
    );
    return '$_temp0 defined ✓';
  }

  @override
  String get pleaseDefineClickArea => 'Please define at least one click area';

  @override
  String get flashcardRandomize => 'Randomize front/back sides';

  @override
  String get flashcardRandomizeSubtitle =>
      'Each attempt randomly picks which side to show first';

  @override
  String get flashcardFrontSide => 'Front side';

  @override
  String get flashcardBackSide => 'Back side';

  @override
  String get flashcardFrontTextOptional => 'Front text (optional)';

  @override
  String get flashcardBackTextOptional => 'Back text (optional)';

  @override
  String get flashcardFrontImageOptional => 'Front image (optional)';

  @override
  String get flashcardBackImageOptional => 'Back image (optional)';

  @override
  String get flashcardFrontRequired =>
      'Front side needs at least text or an image';

  @override
  String get flashcardBackRequired =>
      'Back side needs at least text or an image';

  @override
  String get flashcardSaveAndAddReversed => 'Save & add reversed copy';

  @override
  String get questionImageOptional => 'Question image (optional)';

  @override
  String get explanationOptional => 'Explanation (optional)';

  @override
  String get saveQuestion => 'Save Question';

  @override
  String get answerTypeMCLabel => 'Multiple Choice';

  @override
  String get answerTypeTypedLabel => 'Typed';

  @override
  String get answerTypeImageClickLabel => 'Image Click';

  @override
  String get answerTypeFlashcardLabel => 'Flashcard';

  @override
  String get answerTypeSortingLabel => 'Sorting';

  @override
  String get answerTypeSortingChip => 'Sorting';

  @override
  String get answerTypeSetLabel => 'Set';

  @override
  String get answerTypeSetChip => 'Set';

  @override
  String get setAnswersLabel => 'Correct answers';

  @override
  String setAnswerN(int n) {
    return 'Answer $n';
  }

  @override
  String get setAddAnswer => 'Add answer';

  @override
  String get setAtLeastTwo => 'At least 2 answers required';

  @override
  String get setHint => 'Type an answer…';

  @override
  String get setAdd => 'Add';

  @override
  String get setMissed => 'Missed';

  @override
  String get sortingItemsLabel => 'Items (correct order, top → bottom)';

  @override
  String sortingItemN(int n) {
    return 'Item $n';
  }

  @override
  String get addItem => 'Add item';

  @override
  String get showPreFilled => 'Show items pre-filled';

  @override
  String get showPreFilledSubtitle =>
      'Students drag items into the correct order; disable to have them type each item';

  @override
  String get checkOrder => 'Check order';

  @override
  String get sortingDragHint => 'Drag to reorder';

  @override
  String sortingCorrectAnswer(String answer) {
    return 'Correct: $answer';
  }

  @override
  String get unsavedChangesQuestion => 'Your question changes will be lost.';

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discardChangesDefault =>
      'You have unsaved changes that will be lost.';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get discard => 'Discard';

  @override
  String get navSync => 'Sync';

  @override
  String get navSyncSubtitle => 'Sync all content between two devices';

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncInfo =>
      'Open this screen on both devices and make sure they are on the same Wi-Fi network.';

  @override
  String get syncNearbyDevices => 'Nearby devices';

  @override
  String get syncDiscovering => 'Searching for devices on your network…';

  @override
  String get syncRefresh => 'Refresh';

  @override
  String get syncWaitingForIncoming => 'Waiting for incoming sync';

  @override
  String get syncWaitingSubtitle =>
      'Another device can initiate a sync with you';

  @override
  String get syncRequestSent => 'Waiting for the other device to accept…';

  @override
  String syncConfirmMessage(String deviceName) {
    return 'Sync with $deviceName?';
  }

  @override
  String get syncAcceptTitle => 'Incoming sync request';

  @override
  String syncAcceptMessage(String deviceName) {
    return '$deviceName wants to sync with you.';
  }

  @override
  String get syncAccept => 'Accept';

  @override
  String get syncReject => 'Reject';

  @override
  String get syncInProgress => 'Syncing…';

  @override
  String get syncComplete => 'Sync complete';

  @override
  String get syncAlreadyUpToDate => 'Everything is already up to date.';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get syncSyncAgain => 'Sync again';

  @override
  String syncResultFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count folders added',
      one: '1 folder added',
    );
    return '$_temp0';
  }

  @override
  String syncResultQuizzes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quizzes added',
      one: '1 quiz added',
    );
    return '$_temp0';
  }

  @override
  String syncResultQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions added',
      one: '1 question added',
    );
    return '$_temp0';
  }

  @override
  String syncResultFoldersUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count folders updated',
      one: '1 folder updated',
    );
    return '$_temp0';
  }

  @override
  String syncResultQuizzesUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quizzes updated',
      one: '1 quiz updated',
    );
    return '$_temp0';
  }

  @override
  String syncResultQuestionsUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions updated',
      one: '1 question updated',
    );
    return '$_temp0';
  }

  @override
  String syncResultSrs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SRS entries updated',
      one: '1 SRS entry updated',
    );
    return '$_temp0';
  }

  @override
  String get syncPermissionTitle => 'Network permission required';

  @override
  String get syncPermissionRationale =>
      'To discover nearby devices on your network, Leerlus needs the Nearby Wi-Fi Devices permission.';

  @override
  String get syncPermissionGrantButton => 'Grant permission';

  @override
  String get syncPermissionPermanentlyDenied =>
      'Permission was permanently denied. Please enable it in app settings.';

  @override
  String get syncOpenSettings => 'Open settings';

  @override
  String get syncTroubleshootingTitle => 'Experiencing problems?';

  @override
  String get syncFirewallHint =>
      'Windows Firewall may be blocking network traffic. When prompted, allow Leerlus through the firewall, or go to Windows Security → Firewall & network protection → Allow an app through Firewall.';

  @override
  String get syncSetupFailed => 'Could not start sync';

  @override
  String get syncHardSyncLabel => 'Override other device';

  @override
  String get syncHardSyncWarning =>
      'Content on the other device that doesn\'t exist on this device will be permanently deleted.';

  @override
  String syncOverrideTitle(String deviceName) {
    return 'Override $deviceName?';
  }

  @override
  String syncOverrideConfirm(String deviceName) {
    return 'All content on $deviceName that doesn\'t exist on this device will be permanently deleted. This cannot be undone.';
  }

  @override
  String get syncOverride => 'Override';

  @override
  String syncHardSyncComplete(String deviceName) {
    return 'Hard sync complete, $deviceName has been overridden.';
  }

  @override
  String syncResultFoldersDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count folders removed',
      one: '1 folder removed',
    );
    return '$_temp0';
  }

  @override
  String syncResultQuizzesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quizzes removed',
      one: '1 quiz removed',
    );
    return '$_temp0';
  }

  @override
  String syncResultQuestionsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions removed',
      one: '1 question removed',
    );
    return '$_temp0';
  }

  @override
  String syncResultImagesFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images failed to sync',
      one: '1 image failed to sync',
    );
    return '$_temp0';
  }

  @override
  String get settingsAnimations => 'Animations';

  @override
  String get settingsAnimationsSubtitle =>
      'Show confetti and other visual effects';

  @override
  String get settingsDefaultQuizLanguage => 'Default quiz language';

  @override
  String get settingsDefaultQuizLanguageNone => 'None (don\'t set)';

  @override
  String get syncThisDevice => 'This device';

  @override
  String syncDiscoverableAs(String name) {
    return 'Discoverable as: $name';
  }

  @override
  String get occlusionSectionTitle => 'Image Occlusion';

  @override
  String get defineOcclusionAreas => 'Define Occlusion Areas';

  @override
  String get editOcclusionAreas => 'Edit Occlusion Areas';

  @override
  String occlusionSummary(int hidden, int highlight) {
    return '$hidden hidden, $highlight highlighted ✓';
  }

  @override
  String get occlusionNoImage => 'Set an image first to add occlusion';

  @override
  String get occlusionHideMode => 'Hide';

  @override
  String get occlusionHighlightMode => 'Highlight';

  @override
  String get occlusionClear => 'Clear occlusion';

  @override
  String get occlusionClearAll => 'Clear all';

  @override
  String occlusionImagesCount(int setCount, int totalCount) {
    return '$setCount/$totalCount images have occlusion';
  }

  @override
  String get occlusionTypeChangeTitle => 'Occlusion data will be lost';

  @override
  String occlusionTypeChangeContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images have occlusion areas that',
      one: '1 image has occlusion areas that',
    );
    return '$_temp0 will be removed when switching question type.';
  }

  @override
  String get occlusionTypeChangeContinue => 'Switch anyway';

  @override
  String get imageLibraryTitle => 'Image Library';

  @override
  String get imageLibrarySubtitle => 'Manage images on this device';

  @override
  String get imageLibraryEmpty => 'No images found';

  @override
  String get imageNotUsed => 'Not used';

  @override
  String get imageBuiltIn => 'Built-in';

  @override
  String get imageDeleteUnused => 'Delete unused';

  @override
  String imageDeleteUnusedConfirm(int count) {
    return 'Delete $count unused image(s)? This cannot be undone.';
  }

  @override
  String imageDeleteUnusedSuccess(int count) {
    return 'Deleted $count image(s)';
  }

  @override
  String get imageUpload => 'Upload image';

  @override
  String get imageUploadSuccess => 'Image added to library';

  @override
  String get imageDeleteConfirm =>
      'Delete this image? It is not used anywhere and will be permanently removed.';

  @override
  String get imageUsedByTitle => 'Image usage';

  @override
  String deleteOrphanImages(int count) {
    return 'Also delete $count unused image(s)';
  }

  @override
  String get saveOrphanImagesTitle => 'Remove unused images?';

  @override
  String get saveOrphanImagesContent =>
      'Saving removed images that are no longer referenced anywhere.';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statsToday => 'Today';

  @override
  String get statsAllTime => 'All Time';

  @override
  String get statsTotalAnswered => 'Questions answered';

  @override
  String get statsTotalSessions => 'Sessions completed';

  @override
  String get statsAccuracy => 'Accuracy';

  @override
  String get statsBestDay => 'Best day';

  @override
  String get statsActivity7Days => '7-Day Activity';

  @override
  String get statsAnswerTypes => 'By Answer Type';

  @override
  String get statsSrs => 'SRS Quality';

  @override
  String get statsFunFacts => 'Fun Facts';

  @override
  String get statsMostActiveDay => 'Most active day';

  @override
  String get statsUniqueQuestions => 'Unique questions practiced';

  @override
  String get statsPerfectSessions => 'Perfect sessions';

  @override
  String get statsNoData =>
      'No activity recorded yet. Start a quiz to see your stats!';

  @override
  String get syncResultStatisticsUpdated => 'Statistics synced';
}
