// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get appTitle => 'Leerlus';

  @override
  String get settingsTooltip => 'Instellingen';

  @override
  String get navBrowse => 'Bladeren';

  @override
  String get navBrowseSubtitle => 'Verken quizzen & categorieën';

  @override
  String get navSpacedRepetition => 'Gespreide Herhaling';

  @override
  String get navSpacedRepetitionSubtitle => 'Bekijk je te herhalen kaarten';

  @override
  String get navFavorites => 'Favorieten';

  @override
  String get navFavoritesSubtitle => 'Je opgeslagen quizzen';

  @override
  String get navManageContent => 'Inhoud beheren';

  @override
  String get navManageContentSubtitle => 'Vragen aanmaken en bewerken';

  @override
  String get settingsTitle => 'Instellingen';

  @override
  String get settingsResetSrs => 'Alle SRS-gegevens resetten';

  @override
  String get settingsResetSrsDialogTitle => 'SRS-gegevens resetten';

  @override
  String get settingsResetSrsDialogContent =>
      'Weet je zeker dat je alle SRS-gegevens wilt resetten? Dit kan niet ongedaan worden gemaakt.';

  @override
  String get settingsResetSrsSuccess => 'Alle SRS-gegevens gereset';

  @override
  String get settingsLanguage => 'Taal';

  @override
  String get settingsLanguageSystem => 'Systeemstandaard';

  @override
  String get settingsLanguageEnglish => 'Engels';

  @override
  String get settingsLanguageDutch => 'Nederlands';

  @override
  String get srsAlgoSectionTitle => 'SRS-algoritme';

  @override
  String get srsAlgoSectionSubtitle => 'Planningsgedrag aanpassen';

  @override
  String get srsAlgoLapseMultiplier => 'Verval factor';

  @override
  String get srsAlgoLapseDesc =>
      'Bij \"Opnieuw\" wordt dit deel van het huidige interval bewaard.';

  @override
  String get srsAlgoAgainPenalty => 'Opnieuw - gemakspenalty';

  @override
  String get srsAlgoAgainDesc =>
      'Hoeveel de gemaksfactor daalt bij elke herhaling.';

  @override
  String get srsAlgoHardPenalty => 'Moeilijk - gemakspenalty';

  @override
  String get srsAlgoHardDesc =>
      'Hoeveel de gemaksfactor daalt bij \"Moeilijk\".';

  @override
  String get srsAlgoGoodAdjust => 'Goed - gemaksaanpassing';

  @override
  String get srsAlgoGoodDesc =>
      'Hoeveel de gemaksfactor verschuift bij \"Goed\". Standaard 0 blijft neutraal.';

  @override
  String get srsAlgoEasyBonus => 'Makkelijk - gemaksbonus';

  @override
  String get srsAlgoEasyDesc =>
      'Hoeveel de gemaksfactor stijgt bij \"Makkelijk\".';

  @override
  String get srsAlgoInitialEase => 'Beginfactor gemak';

  @override
  String get srsAlgoInitialEaseDesc =>
      'Startfactor voor nieuw toegevoegde kaarten.';

  @override
  String get srsAlgoMaxInterval => 'Max. interval';

  @override
  String get srsAlgoMaxIntervalDesc =>
      'Langste interval waarvoor een kaart ingepland kan worden.';

  @override
  String srsAlgoDays(int count) {
    return '$count dagen';
  }

  @override
  String get srsAlgoResetDefaults => 'Terugzetten naar standaard';

  @override
  String get cancel => 'Annuleren';

  @override
  String get confirm => 'Bevestigen';

  @override
  String get delete => 'Verwijderen';

  @override
  String get save => 'Opslaan';

  @override
  String get reset => 'Resetten';

  @override
  String get edit => 'Bewerken';

  @override
  String get required => 'Verplicht';

  @override
  String get start => 'Starten';

  @override
  String get retry => 'Opnieuw';

  @override
  String get back => 'Terug';

  @override
  String get home => 'Home';

  @override
  String get remove => 'Verwijderen';

  @override
  String get saveChanges => 'Wijzigingen opslaan';

  @override
  String get foldersSection => 'Mappen';

  @override
  String get quizzesSection => 'Quizzen';

  @override
  String get emptyFolder => 'Hier is nog niets.';

  @override
  String get searchTooltip => 'Zoeken';

  @override
  String get searchHint => 'Zoek mappen & quizzen…';

  @override
  String get searchNoResults => 'Geen resultaten gevonden.';

  @override
  String get streakSectionTitle => 'Streaks';

  @override
  String get streakEnabledToggle => 'Streak bijhouden';

  @override
  String get streakEnabledSubtitle =>
      'Verdien een streakdag voor elke dag dat je studeert';

  @override
  String get streakNotifsToggle => 'Dagelijkse herinnering';

  @override
  String get streakNotifsSubtitle =>
      'Ontvang een melding om je streak te bewaren';

  @override
  String get streakNotifsTime => 'Herinneringstijd';

  @override
  String get streakResetButton => 'Streak resetten';

  @override
  String get streakResetDialogTitle => 'Streak resetten?';

  @override
  String get streakResetDialogContent => 'Je huidige streak gaat verloren.';

  @override
  String streakCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagen streak',
      one: '1 dag streak',
    );
    return '$_temp0';
  }

  @override
  String streakFreezesRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bevriezingen over deze week',
      one: '1 bevriezing over deze week',
      zero: 'Geen bevriezingen meer deze week',
    );
    return '$_temp0';
  }

  @override
  String get streakContinued => 'Streak voortgezet!';

  @override
  String streakContinuedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Je hebt een streak van $count dagen!',
      one: 'Je hebt een streak van 1 dag!',
    );
    return '$_temp0';
  }

  @override
  String get streakFreezeUsed => 'Bevriezing gebruikt!';

  @override
  String streakFreezeUsedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bevriezingen over deze week',
      one: '1 bevriezing over deze week',
      zero: 'Geen bevriezingen meer deze week',
    );
    return '$_temp0';
  }

  @override
  String get streakReset => 'Streak gereset';

  @override
  String get streakResetBody =>
      'Geen bevriezingen meer — opnieuw beginnen bij 1 dag.';

  @override
  String get streakInfoTitle => 'Streak';

  @override
  String streakBest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagen',
      one: '1 dag',
    );
    return 'Beste: $_temp0';
  }

  @override
  String streakFreezesRestockOn(String date) {
    return 'Wordt bijgevuld op $date';
  }

  @override
  String get favoritesTitle => 'Favorieten';

  @override
  String get favoritesEmpty => 'Nog geen favoriete quizzen.';

  @override
  String get srsTitle => 'Gespreide Herhaling';

  @override
  String get srsNoQuestions => 'Geen spaced repetition-vragen beschikbaar';

  @override
  String srsDue(int count) {
    return '$count te herhalen';
  }

  @override
  String srsCards(int count) {
    return '$count kaarten';
  }

  @override
  String srsOldestOverdue(String time) {
    return 'oudste $time verlopen';
  }

  @override
  String srsNextIn(String time) {
    return 'volgende in $time';
  }

  @override
  String get srsStartNormalQuiz => 'Normale quiz starten';

  @override
  String get srsNoSrsScheduling => 'Geen SRS-planning';

  @override
  String get srsRemoveFromSrs => 'Uit SRS verwijderen';

  @override
  String get srsRemoveDialogTitle => 'Uit spaced repetition verwijderen?';

  @override
  String srsRemoveDialogContent(String quizTitle) {
    return 'Alle SRS-voortgang voor \"$quizTitle\" gaat verloren. Dit kan niet ongedaan worden gemaakt.';
  }

  @override
  String get srsNoQuestionsDue => 'Geen vragen te herhalen';

  @override
  String get srsSessionComplete => 'Sessie voltooid';

  @override
  String srsQuestionsReviewed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vragen herhaald',
      one: '1 vraag herhaald',
    );
    return '$_temp0';
  }

  @override
  String get srsAllCaughtUp => 'Alles bijgewerkt!';

  @override
  String get srsNoMoreDue => 'Geen vragen meer te herhalen.';

  @override
  String get srsStillDue => 'Nog te herhalen';

  @override
  String srsQuestionsDue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vragen te herhalen',
      one: '1 vraag te herhalen',
    );
    return '$_temp0';
  }

  @override
  String get srsBackToSpacedRepetition => 'Terug naar Spaced Repetition';

  @override
  String get srsHowWellKnew => 'Hoe goed kende je dit?';

  @override
  String get srsAgain => 'Opnieuw';

  @override
  String get srsHard => 'Moeilijk';

  @override
  String get srsGood => 'Goed';

  @override
  String get srsEasy => 'Makkelijk';

  @override
  String get durationNow => 'nu';

  @override
  String durationDays(int n) {
    return '${n}d';
  }

  @override
  String durationHours(int n) {
    return '${n}u';
  }

  @override
  String durationMinutes(int n) {
    return '${n}m';
  }

  @override
  String get quizCompleted => 'Quiz voltooid';

  @override
  String get noQuestions => 'Geen vragen';

  @override
  String get manageContentTitle => 'Inhoud beheren';

  @override
  String get addFolder => 'Map toevoegen';

  @override
  String get addQuiz => 'Quiz toevoegen';

  @override
  String get addQuestion => 'Vraag toevoegen';

  @override
  String get importJsonTooltip => 'Importeer (.lus / .json)';

  @override
  String get exportJsonTooltip => 'Exporteer (.lus)';

  @override
  String get exportSeedDbTooltip => 'seed.db exporteren';

  @override
  String get exportFolderTooltip => 'Map exporteren';

  @override
  String get exportQuizTooltip => 'Quiz exporteren';

  @override
  String get moveTooltip => 'Verplaatsen';

  @override
  String get moveToFolderTitle => 'Verplaats naar map';

  @override
  String get moveToRootOption => 'Root (geen map)';

  @override
  String get contentPacksTitle => 'Inhoudspakketten';

  @override
  String get contentPacksTooltip => 'Inhoudspakketten bekijken';

  @override
  String get contentPacksImport => 'Importeren';

  @override
  String contentPacksImportedCount(int count) {
    return '$count nieuwe items geïmporteerd';
  }

  @override
  String get contentPacksAlreadyUpToDate => 'Al up-to-date';

  @override
  String get importSuccess => 'Importeren geslaagd';

  @override
  String importFailed(Object error) {
    return 'Importeren mislukt: $error';
  }

  @override
  String exportFailed(Object error) {
    return 'Exporteren mislukt: $error';
  }

  @override
  String get folderContents => 'Mapinhoud';

  @override
  String get emptyFolderManage =>
      'Leeg. Tik op + om een map of quiz toe te voegen.';

  @override
  String get builtIn => 'Ingebouwd';

  @override
  String get builtInDebug => 'Ingebouwd (bewerkbaar in debug)';

  @override
  String get deleteFolderTitle => 'Map verwijderen?';

  @override
  String deleteFolderContent(String name) {
    return 'Dit verwijdert \"$name\" en alles daarin.';
  }

  @override
  String get deleteQuizTitle => 'Quiz verwijderen?';

  @override
  String deleteQuizContent(String name) {
    return 'Dit verwijdert \"$name\" en alle bijbehorende vragen.';
  }

  @override
  String get questionsSubtitle => 'Vragen';

  @override
  String get noQuestionsYet => 'Nog geen vragen. Voeg er een toe.';

  @override
  String get deleteQuestionTitle => 'Vraag verwijderen?';

  @override
  String get answerTypeMultipleChoiceChip => 'Meerkeuze';

  @override
  String get answerTypeTypedChip => 'Typen';

  @override
  String get answerTypeImageClickChip => 'Afbeelding klikken';

  @override
  String get editFolderAppBarTitle => 'Map bewerken';

  @override
  String get addFolderAppBarTitle => 'Map toevoegen';

  @override
  String get folderNameLabel => 'Mapnaam';

  @override
  String get folderImageOptional => 'Mapafbeelding (optioneel)';

  @override
  String get editQuizAppBarTitle => 'Quiz bewerken';

  @override
  String get addQuizAppBarTitle => 'Quiz toevoegen';

  @override
  String get titleLabel => 'Titel';

  @override
  String get quizImageOptional => 'Quizafbeelding (optioneel)';

  @override
  String get languageCodeLabel => 'Taalcode';

  @override
  String get languageCodeHint => 'bijv. en, nl, de, fr';

  @override
  String get editQuestionAppBarTitle => 'Vraag bewerken';

  @override
  String get addQuestionAppBarTitle => 'Vraag toevoegen';

  @override
  String get questionLabel => 'Vraag';

  @override
  String get answerTypeLabel => 'Antwoordtype';

  @override
  String get optionsLabel => 'Opties';

  @override
  String optionN(int n) {
    return 'Optie $n';
  }

  @override
  String get radioCorrectHint => 'Radioknop = juist antwoord';

  @override
  String get checkboxCorrectHint => 'Vink alle juiste antwoorden aan';

  @override
  String get addOption => 'Optie toevoegen';

  @override
  String get multipleCorrectAnswers => 'Meerdere juiste antwoorden';

  @override
  String get showCorrectCount => 'Aantal antwoorden tonen';

  @override
  String get showCorrectCountSubtitle =>
      'Vertel studenten hoeveel antwoorden ze moeten selecteren';

  @override
  String get checkAnswer => 'Antwoord controleren';

  @override
  String get selectAllThatApply => 'Selecteer alles wat van toepassing is';

  @override
  String selectNCorrectAnswers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Selecteer $count juiste antwoorden',
      one: 'Selecteer 1 juist antwoord',
    );
    return '$_temp0';
  }

  @override
  String get selectAtLeastOneCorrect => 'Markeer minimaal één optie als juist';

  @override
  String get duplicateOption => 'Opties moeten uniek zijn';

  @override
  String get acceptedAnswersLabel => 'Geaccepteerde antwoorden';

  @override
  String acceptedAnswerN(int n) {
    return 'Geaccepteerd antwoord $n';
  }

  @override
  String get atLeastOneRequired => 'Minimaal één vereist';

  @override
  String get addVariant => 'Variant toevoegen';

  @override
  String get clickAreaImageLabel => 'Klikgebiedafbeelding';

  @override
  String get defineClickAreas => 'Klikgebieden definiëren';

  @override
  String editClickAreas(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gebieden',
      one: '1 gebied',
    );
    return 'Klikgebieden bewerken ($_temp0)';
  }

  @override
  String areasDefinedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gebieden',
      one: '1 gebied',
    );
    return '$_temp0 gedefinieerd ✓';
  }

  @override
  String get pleaseDefineClickArea => 'Definieer minstens één klikgebied';

  @override
  String get flashcardRandomize => 'Voor-/achterkant willekeurig';

  @override
  String get flashcardRandomizeSubtitle =>
      'Elke poging kiest willekeurig welke kant als eerste wordt getoond';

  @override
  String get flashcardFrontSide => 'Voorkant';

  @override
  String get flashcardBackSide => 'Achterkant';

  @override
  String get flashcardFrontTextOptional => 'Voorkant tekst (optioneel)';

  @override
  String get flashcardBackTextOptional => 'Achterkant tekst (optioneel)';

  @override
  String get flashcardFrontImageOptional => 'Voorkant afbeelding (optioneel)';

  @override
  String get flashcardBackImageOptional => 'Achterkant afbeelding (optioneel)';

  @override
  String get flashcardFrontRequired =>
      'Voorkant heeft minimaal tekst of een afbeelding nodig';

  @override
  String get flashcardBackRequired =>
      'Achterkant heeft minimaal tekst of een afbeelding nodig';

  @override
  String get questionImageOptional => 'Vraagafbeelding (optioneel)';

  @override
  String get explanationOptional => 'Uitleg (optioneel)';

  @override
  String get saveQuestion => 'Vraag opslaan';

  @override
  String get answerTypeMCLabel => 'Meerkeuze';

  @override
  String get answerTypeTypedLabel => 'Typen';

  @override
  String get answerTypeImageClickLabel => 'Afbeelding klikken';

  @override
  String get answerTypeFlashcardLabel => 'Flashcard';

  @override
  String get answerTypeSortingLabel => 'Sorteren';

  @override
  String get answerTypeSortingChip => 'Sorteren';

  @override
  String get answerTypeSetLabel => 'Set';

  @override
  String get answerTypeSetChip => 'Set';

  @override
  String get setAnswersLabel => 'Correcte antwoorden';

  @override
  String setAnswerN(int n) {
    return 'Antwoord $n';
  }

  @override
  String get setAddAnswer => 'Antwoord toevoegen';

  @override
  String get setAtLeastTwo => 'Minimaal 2 antwoorden vereist';

  @override
  String get setHint => 'Typ een antwoord…';

  @override
  String get setAdd => 'Toevoegen';

  @override
  String get setMissed => 'Gemist';

  @override
  String get sortingItemsLabel => 'Items (juiste volgorde, boven → onder)';

  @override
  String sortingItemN(int n) {
    return 'Item $n';
  }

  @override
  String get addItem => 'Item toevoegen';

  @override
  String get showPreFilled => 'Items vooraf tonen';

  @override
  String get showPreFilledSubtitle =>
      'Studenten slepen items op volgorde; uitschakelen om ze elk item te laten typen';

  @override
  String get checkOrder => 'Volgorde controleren';

  @override
  String get sortingDragHint => 'Slepen om te herordenen';

  @override
  String sortingCorrectAnswer(String answer) {
    return 'Juist: $answer';
  }

  @override
  String get unsavedChangesQuestion => 'Je vraagwijzigingen gaan verloren.';

  @override
  String get discardChangesTitle => 'Wijzigingen verwerpen?';

  @override
  String get discardChangesDefault =>
      'Je hebt niet-opgeslagen wijzigingen die verloren gaan.';

  @override
  String get keepEditing => 'Blijf bewerken';

  @override
  String get discard => 'Verwerpen';

  @override
  String get navSync => 'Synchroniseren';

  @override
  String get navSyncSubtitle =>
      'Alle inhoud synchroniseren tussen twee apparaten';

  @override
  String get syncTitle => 'Synchroniseren';

  @override
  String get syncInfo =>
      'Open dit scherm op beide apparaten en zorg ervoor dat ze op hetzelfde Wi-Fi-netwerk zijn.';

  @override
  String get syncNearbyDevices => 'Apparaten in de buurt';

  @override
  String get syncDiscovering => 'Zoeken naar apparaten in je netwerk…';

  @override
  String get syncRefresh => 'Vernieuwen';

  @override
  String get syncWaitingForIncoming => 'Wachten op inkomende sync';

  @override
  String get syncWaitingSubtitle =>
      'Een ander apparaat kan een sync met jou starten';

  @override
  String get syncRequestSent => 'Wachten tot het andere apparaat accepteert…';

  @override
  String syncConfirmMessage(String deviceName) {
    return 'Synchroniseren met $deviceName?';
  }

  @override
  String get syncAcceptTitle => 'Inkomend synchronisatieverzoek';

  @override
  String syncAcceptMessage(String deviceName) {
    return '$deviceName wil synchroniseren met jou.';
  }

  @override
  String get syncAccept => 'Accepteren';

  @override
  String get syncReject => 'Weigeren';

  @override
  String get syncInProgress => 'Synchroniseren…';

  @override
  String get syncComplete => 'Synchronisatie voltooid';

  @override
  String get syncAlreadyUpToDate => 'Alles is al up-to-date.';

  @override
  String get syncFailed => 'Synchronisatie mislukt';

  @override
  String get syncSyncAgain => 'Opnieuw synchroniseren';

  @override
  String syncResultFolders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mappen toegevoegd',
      one: '1 map toegevoegd',
    );
    return '$_temp0';
  }

  @override
  String syncResultQuizzes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quizzen toegevoegd',
      one: '1 quiz toegevoegd',
    );
    return '$_temp0';
  }

  @override
  String syncResultQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vragen toegevoegd',
      one: '1 vraag toegevoegd',
    );
    return '$_temp0';
  }

  @override
  String syncResultSrs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SRS-invoeren bijgewerkt',
      one: '1 SRS-invoer bijgewerkt',
    );
    return '$_temp0';
  }

  @override
  String get syncPermissionTitle => 'Netwerktoestemming vereist';

  @override
  String get syncPermissionRationale =>
      'Om apparaten op je netwerk te ontdekken heeft Leerlus de toestemming \'Nabijgelegen Wi-Fi-apparaten\' nodig.';

  @override
  String get syncPermissionGrantButton => 'Toestemming geven';

  @override
  String get syncPermissionPermanentlyDenied =>
      'Toestemming is permanent geweigerd. Schakel deze in via de app-instellingen.';

  @override
  String get syncOpenSettings => 'Instellingen openen';

  @override
  String get settingsAnimations => 'Animaties';

  @override
  String get settingsAnimationsSubtitle =>
      'Toon confetti en andere visuele effecten';

  @override
  String get syncThisDevice => 'Dit apparaat';

  @override
  String syncDiscoverableAs(String name) {
    return 'Zichtbaar als: $name';
  }

  @override
  String get occlusionSectionTitle => 'Afbeelding Verbergen';

  @override
  String get defineOcclusionAreas => 'Gebieden definiëren';

  @override
  String get editOcclusionAreas => 'Gebieden bewerken';

  @override
  String occlusionSummary(int hidden, int highlight) {
    return '$hidden verborgen, $highlight gemarkeerd ✓';
  }

  @override
  String get occlusionNoImage => 'Stel eerst een afbeelding in';

  @override
  String get occlusionHideMode => 'Verbergen';

  @override
  String get occlusionHighlightMode => 'Markeren';

  @override
  String get occlusionClear => 'Verwijderen';

  @override
  String get imageLibraryTitle => 'Afbeeldingsbibliotheek';

  @override
  String get imageLibrarySubtitle => 'Beheer afbeeldingen op dit apparaat';

  @override
  String get imageLibraryEmpty => 'Geen afbeeldingen gevonden';

  @override
  String get imageNotUsed => 'Niet gebruikt';

  @override
  String get imageBuiltIn => 'Ingebouwd';

  @override
  String get imageDeleteUnused => 'Verwijder ongebruikte';

  @override
  String imageDeleteUnusedConfirm(int count) {
    return 'Verwijder $count ongebruikte afbeelding(en)? Dit kan niet ongedaan worden gemaakt.';
  }

  @override
  String imageDeleteUnusedSuccess(int count) {
    return '$count afbeelding(en) verwijderd';
  }

  @override
  String get imageUpload => 'Afbeelding uploaden';

  @override
  String get imageUploadSuccess => 'Afbeelding toegevoegd aan bibliotheek';

  @override
  String get imageDeleteConfirm =>
      'Afbeelding verwijderen? Het wordt nergens gebruikt en wordt permanent verwijderd.';

  @override
  String get imageUsedByTitle => 'Afbeeldingsgebruik';

  @override
  String deleteOrphanImages(int count) {
    return 'Verwijder ook $count ongebruikte afbeelding(en)';
  }
}
