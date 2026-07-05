import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:leerlus/models/answer_state.dart';
import 'package:leerlus/models/answer_type.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/models/user_question_data.dart';
import 'package:leerlus/screens/question_display/answer_area.dart';
import 'package:leerlus/screens/question_display/continue_button.dart';
import 'package:leerlus/screens/question_display/srs_buttons.dart';
import 'package:leerlus/services/settings_service.dart';
import 'package:leerlus/services/statistics_service.dart';
import 'package:leerlus/widgets/auto_scale_text.dart';

class QuestionDisplayScreen extends StatefulWidget {
  final QuestionData question;
  final bool spacedRepetitionMode;
  final Function(bool wasCorrect, SrsQuality? quality) onContinue;

  const QuestionDisplayScreen({
    super.key,
    required this.question,
    required this.onContinue,
    this.spacedRepetitionMode = false,
  });

  @override
  State<QuestionDisplayScreen> createState() => _QuestionDisplayScreenState();
}

class _QuestionDisplayScreenState extends State<QuestionDisplayScreen>
    with SingleTickerProviderStateMixin {
  AnswerState answerState = AnswerState.unanswered;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  late final ConfettiController _confettiController;
  late final FocusNode _continueFocusNode;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _shakeAnimation = Tween<double>(begin: 0, end: 8)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
    _continueFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _confettiController.dispose();
    _continueFocusNode.dispose();
    super.dispose();
  }

  void _handleAnswer(bool isCorrect) {
    StatisticsService().recordAnswer(
      widget.question.answerType.name, isCorrect, widget.spacedRepetitionMode);
    setState(() {
      answerState = isCorrect ? AnswerState.correct : AnswerState.incorrect;
    });

    // Only focus the continue button when it will actually be shown.
    // In SRS mode after a correct answer the sheet appears instead — focusing
    // the continue button here would let Enter skip the quality selection.
    final srsSheetWillAppear = widget.spacedRepetitionMode &&
        isCorrect &&
        widget.question.answerType != AnswerType.flashcard;
    if (!srsSheetWillAppear) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _continueFocusNode.requestFocus();
      });
    }

    if (!isCorrect) {
      _shakeController.forward(from: 0);
    } else if (SettingsService().animationsEnabled) {
      _confettiController.play();
    }

    if (srsSheetWillAppear) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _showSrsBottomSheet();
      });
    }
  }

  // Flashcards in SRS mode never route through _handleAnswer — the card's
  // quality buttons answer directly — so record the daily/answer-type stats
  // here. "again" counts as an incorrect answer; hard/good/easy as correct.
  // Either way the question counts as answered.
  void _handleFlashcardSrsAnswered(SrsQuality quality) {
    final wasCorrect = quality != SrsQuality.again;
    StatisticsService().recordAnswer(
        widget.question.answerType.name, wasCorrect, widget.spacedRepetitionMode);
    widget.onContinue(wasCorrect, quality);
  }

  void _showSrsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => PopScope(
        canPop: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: SrsButtons(
              question: widget.question,
              onAnswered: (quality) {
                Navigator.pop(ctx);
                widget.onContinue(true, quality);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _handleContinue() {
    final wasCorrect = answerState == AnswerState.correct;
    setState(() {
      answerState = AnswerState.unanswered;
    });
    widget.onContinue(wasCorrect, null);
  }

  @override
  Widget build(BuildContext context) {
    final showContinue = answerState != AnswerState.unanswered &&
        !(widget.spacedRepetitionMode && answerState == AnswerState.correct);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [

          /// MAIN CONTENT
          SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Question text is large by default but capped to ~40% of the
                // available height; AutoScaleText shrinks the font when the
                // text (e.g. a long question above a big image) needs the room.
                final maxQuestionHeight = constraints.maxHeight * 0.4;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) {
                        final offset = _shakeAnimation.value *
                            (_shakeController.status == AnimationStatus.forward
                                ? 1
                                : 0);
                        return Transform.translate(
                          offset: Offset(offset, 0),
                          child: child,
                        );
                      },
                      child: widget.question.answerType == AnswerType.flashcard
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxHeight: maxQuestionHeight),
                                child: AutoScaleText(
                                  text: widget.question.questionVariants.first,
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                  expand: false,
                                ),
                              ),
                            ),
                    ),
                    Expanded(
                      child: AnswerArea(
                        question: widget.question,
                        locked: answerState != AnswerState.unanswered,
                        answerState: answerState,
                        onAnswered: _handleAnswer,
                        spacedRepetitionMode: widget.spacedRepetitionMode,
                        onFlashcardSrsAnswered: widget.spacedRepetitionMode
                            ? _handleFlashcardSrsAnswered
                            : null,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          /// CONTINUE BUTTON — overlaid, never affects layout
          Positioned(
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom,
            child: AnimatedSlide(
              offset: showContinue ? Offset.zero : const Offset(0, 0.3),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: showContinue ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !showContinue,
                  child: ContinueButton(onContinue: _handleContinue, focusNode: _continueFocusNode),
                ),
              ),
            ),
          ),

          /// CONFETTI
          Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                ],
                numberOfParticles: 10,
                maxBlastForce: 20,
                minBlastForce: 10,
              ),
            ),
          ),

        ],
      ),
    );
  }
}