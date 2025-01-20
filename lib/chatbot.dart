import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:syncfusion_flutter_chat/assist_view.dart';
import 'package:syncfusion_flutter_core/theme.dart';

class Chatbot extends StatefulWidget {
  const Chatbot({super.key});

  @override
  State<Chatbot> createState() => _ChatbotState();
}

class _ChatbotState extends State<Chatbot> {
  late List<_AIMessage> _messages;
  late TextEditingController _textController;
  late TextEditingController _feedbackTextController;
  late List<String> _positiveFeedbacks;
  late List<String> _negativeFeedbacks;
  late List<int> _selectedChipFeedbackIndices;
  late ThemeData _themeData;
  late Color _actionIconColor;

  final String _aiModel = 'gemini-1.5-flash-latest';
  final String _apiKey = 'AIzaSyC80v3VwsytaZGnZXUsqP2NDfT1NXhRVtA';
  final AssistMessageAuthor _aiChatbot = AssistMessageAuthor(
    name: 'AI',
    avatar: AssetImage('assets/ai_assist_view.png'),
  );
  final EdgeInsets _contentPadding =
      const EdgeInsets.symmetric(horizontal: 7, vertical: 5);
  final BoxConstraints _actionIconConstraints =
      BoxConstraints.tightFor(width: 40, height: 40);

  String _previousText = '';
  TextPainter? _textPainter;
  int _footerMessageIndex = -1;
  double _minTextLineHeight = 0;
  bool _isPositiveFeedback = true;
  bool _isResponseLoading = false;

  void _handleTextChange() {
    if (_previousText.isEmpty || _previousText != _textController.text) {
      setState(() {});
    }

    _previousText = _textController.text;
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Center(
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (Rect bounds) {
          return LinearGradient(
            colors: [Colors.blue, Colors.red],
          ).createShader(bounds);
        },
        child: Text(
          'Hello!',
          style: _themeData.textTheme.headlineLarge,
        ),
      ),
    );
  }

  AssistComposer _buildComposer(BuildContext context) {
    return AssistComposer.builder(
      builder: (BuildContext context) {
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.fromBorderSide(
              BorderSide(
                color: _themeData.colorScheme.onSurfaceVariant.withAlpha(130),
                width: 0.5,
              ),
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Padding(
              padding: _contentPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildPrefixIcon(),
                  Expanded(
                    child: Padding(
                      padding: _textContentPadding(),
                      child: TextField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: 7,
                        style: _themeData.textTheme.bodyMedium,
                        decoration: _textFieldDecoration(),
                      ),
                    ),
                  ),
                  _buildSuffixIcon(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrefixIcon() {
    return _buildIcon(
      icon: Icons.add_photo_alternate_outlined,
      tooltip: 'Upload Image',
      onPressed: () {},
    );
  }

  EdgeInsets _textContentPadding() {
    _textPainter ??= TextPainter(
      text: TextSpan(
        text: 'Hello!',
        style: _themeData.textTheme.bodyMedium,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _minTextLineHeight = _textPainter!.height;
    final double minComposerHeight = _actionIconConstraints.maxHeight;
    if (_textPainter!.height > minComposerHeight) {
      return EdgeInsets.symmetric(
        horizontal: _contentPadding.horizontal,
        vertical: 0,
      );
    } else {
      final double gapDifference = minComposerHeight - _textPainter!.height;
      return EdgeInsets.symmetric(
        horizontal: _contentPadding.horizontal,
        vertical: gapDifference / 2,
      );
    }
  }

  InputDecoration _textFieldDecoration() {
    return InputDecoration(
      hintText: 'Ask here',
      hintStyle: _themeData.textTheme.bodyMedium?.copyWith(
        color: _themeData.colorScheme.onSurface.withAlpha(192),
      ),
      border: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      isDense: true,
    );
  }

  Widget _buildSuffixIcon() {
    if (_textController.text.isEmpty) {
      if (_isResponseLoading) {
        return _buildIcon(
          icon: Icons.stop,
          tooltip: 'Stop response',
          onPressed: () {
            //
          },
        );
      } else {
        return _buildIcon(
          icon: Icons.mic,
          tooltip: 'Use microphone',
          onPressed: () {},
        );
      }
    } else {
      return _buildIcon(
        icon: Icons.send,
        tooltip: 'Submit',
        onPressed: () {
          setState(() {
            final String request = _textController.text;
            _textController.clear();
            _messages.add(_AIMessage.request(data: request));
            _generateResponse(request).then((_AIMessage response) {
              setState(() {
                _messages.add(response);
              });
            });
          });
        },
      );
    }
  }

  Widget _buildIcon({
    required IconData icon,
    required String tooltip,
    required Function() onPressed,
  }) {
    return IconButton(
      icon: Icon(icon),
      color: _actionIconColor,
      constraints: _actionIconConstraints,
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  void _intimateLoadingCompletion(int index) {
    SchedulerBinding.instance.addPostFrameCallback((Duration duration) {
      setState(() {
        _isResponseLoading = false;
        _messages[index] = _messages[index].copyWith(isLoaded: true);
      });
    });
  }

  Widget _buildContent(BuildContext context, int index, AssistMessage message) {
    if (message.isRequested) {
      return MarkdownBody(data: message.data);
    } else {
      return _AnimatedText(
        text: message.data,
        index: index,
        minLineHeight: _minTextLineHeight,
        messages: _messages,
        onLoadingCompleted: _intimateLoadingCompletion,
      );
    }
  }

  Future<_AIMessage> _generateResponse(String request) async {
    _isResponseLoading = true;
    try {
      final GenerativeModel model = GenerativeModel(
        model: _aiModel,
        apiKey: _apiKey,
      );

      final List<Content> content = [Content.text(request)];
      final GenerateContentResponse response =
          await model.generateContent(content);
      return _AIMessage.response(
        data: response.text ?? 'No response',
        author: _aiChatbot,
        toolbarItems: _buildToolbarItems(),
      );
    } on Exception catch (e) {
      return _AIMessage.response(
        data: e.toString(),
        author: _aiChatbot,
        toolbarItems: _buildToolbarItems(),
      );
    }
  }

  List<AssistMessageToolbarItem> _buildToolbarItems() {
    return <AssistMessageToolbarItem>[
      AssistMessageToolbarItem(
        content: _toolbarItem(Icons.thumb_up_off_alt),
        tooltip: 'Good Response',
      ),
      AssistMessageToolbarItem(
        content: _toolbarItem(Icons.thumb_down_off_alt),
        tooltip: 'Bad Response',
      ),
      AssistMessageToolbarItem(
        content: _toolbarItem(Icons.restart_alt),
        tooltip: 'Regenerate',
      ),
      AssistMessageToolbarItem(
        content: _buildPopupMenuItemForShareExport(Icons.share_outlined),
        tooltip: 'Share & Export',
      ),
      AssistMessageToolbarItem(
        content: _buildPopupMenuItemForMore(Icons.more_vert),
        tooltip: 'More',
      ),
    ];
  }

  // Widget _buildNavigator() {
  //   return Row(
  //     mainAxisSize: MainAxisSize.min,
  //     children: [
  //       Icon(
  //         Icons.arrow_back_ios,
  //         key: GlobalKey(),
  //         size: 18,
  //         color: _themeData.colorScheme.onSurface.withValues(alpha: 100),
  //       ),
  //       Icon(
  //         Icons.arrow_forward_ios,
  //         key: GlobalKey(),
  //         size: 18,
  //         color: _themeData.colorScheme.onSurface.withValues(alpha: 100),
  //       ),
  //     ],
  //   );
  // }

  Widget _toolbarItem(IconData data) {
    return Icon(
      data,
      key: GlobalKey(),
      size: 18,
      color: _themeData.colorScheme.onSurface.withValues(alpha: 100),
    );
  }

  Widget _buildPopupMenuItemForShareExport(IconData data) {
    return PopupMenuButton<String>(
      onSelected: (String value) {
        //
      },
      itemBuilder: (BuildContext context) {
        return <PopupMenuEntry<String>>[
          PopupMenuItem(
            value: 'Option 1',
            child: Text('Share conversation'),
          ),
          PopupMenuItem(
            value: 'Option 2',
            child: Text('Export to Docs'),
          ),
          PopupMenuItem(
            value: 'Option 3',
            child: Text('Draft in Gmail'),
          ),
          PopupMenuItem(
            value: 'Option 4',
            child: Text('Export to Replit'),
          ),
        ];
      },
      child: _toolbarItem(data),
    );
  }

  Widget _buildPopupMenuItemForMore(IconData data) {
    return PopupMenuButton<String>(
      onSelected: (String value) {
        //
      },
      itemBuilder: (BuildContext context) {
        return <PopupMenuEntry<String>>[
          PopupMenuItem(
            value: 'Option 1',
            child: Text('Double-check response'),
          ),
          PopupMenuItem(
            value: 'Option 2',
            child: Text('Copy'),
          ),
          PopupMenuItem(
            value: 'Option 3',
            child: Text('Listen'),
          ),
          PopupMenuItem(
            value: 'Option 4',
            child: Text('Report legal issue'),
          ),
        ];
      },
      child: _toolbarItem(data),
    );
  }

  Widget _buildFeedbackContainer(
      BuildContext context, int index, AssistMessage message) {
    final TextTheme textThemeData = Theme.of(context).textTheme;
    if (_footerMessageIndex == index) {
      final List<String> feedbacks =
          _isPositiveFeedback ? _positiveFeedbacks : _negativeFeedbacks;
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: _themeData.colorScheme.secondaryContainer.withAlpha(50),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFeedbackBuilderHeader(textThemeData),
                _buildPredefinedFeedbackTiles(feedbacks),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: TextField(
                    controller: _feedbackTextController,
                    decoration: InputDecoration(
                      hintText: 'Provide additional feedback',
                      hintStyle: textThemeData.bodyMedium,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: 'Learn more',
                        style: _themeData.textTheme.labelSmall?.copyWith(
                          color:
                              _themeData.colorScheme.onSurface.withAlpha(138),
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            // TODO: Handle tap event.
                          },
                      ),
                      TextSpan(
                        text: ' about how your feedback is used to improve AI.',
                        style: _themeData.textTheme.labelSmall?.copyWith(
                          color:
                              _themeData.colorScheme.onSurface.withAlpha(138),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: FilledButton(
                    onPressed: _selectedChipFeedbackIndices.isNotEmpty ||
                            _feedbackTextController.text.isNotEmpty
                        ? () {
                            setState(() {
                              _footerMessageIndex = -1;
                              _selectedChipFeedbackIndices.clear();
                            });
                          }
                        : null,
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildFeedbackBuilderHeader(TextTheme textThemeData) {
    return Row(
      children: <Widget>[
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Why did you choose this rating?',
                  style: textThemeData.titleMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
                TextSpan(
                  text: ' (Optional)',
                  style: textThemeData.titleSmall!.copyWith(
                    color: _themeData.colorScheme.onSurface.withAlpha(138),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _footerMessageIndex = -1;
            });
          },
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildPredefinedFeedbackTiles(List<String> feedbacks) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(feedbacks.length, (int index) {
          return ChoiceChip(
            label: Text(
              feedbacks[index],
              style: _themeData.textTheme.bodyMedium,
            ),
            selected: _selectedChipFeedbackIndices.contains(index),
            onSelected: (bool selected) {
              setState(() {
                if (selected) {
                  _selectedChipFeedbackIndices.add(index);
                } else {
                  _selectedChipFeedbackIndices.remove(index);
                }
              });
            },
          );
        }),
      ),
    );
  }

  void _clearFeedbackCache() {
    _footerMessageIndex = -1;
    _selectedChipFeedbackIndices.clear();
    _feedbackTextController.clear();
  }

  Widget _buildResponseLoadingBuilder(
    BuildContext context,
    int index,
    AssistMessage message,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(_isResponseLoading ? 8.0 : 0.0),
                child: CircleAvatar(
                  backgroundColor: Colors.transparent,
                  backgroundImage: _aiChatbot.avatar,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(2.0),
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  backgroundColor: Colors.transparent,
                ),
              )
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Text('Wait a sec...'),
        ),
      ],
    );
  }

  void _handleToolbarItemSelected(
    bool selected,
    int messageIndex,
    AssistMessageToolbarItem toolbarItem,
    int toolbarItemIndex,
  ) {
    if (toolbarItemIndex == 0) {
      _handleThumbUpClicked(
          selected, messageIndex, toolbarItem, toolbarItemIndex);
    } else if (toolbarItemIndex == 1) {
      _handleThumbDownClicked(
          selected, messageIndex, toolbarItem, toolbarItemIndex);
    } else if (toolbarItemIndex == 2) {
      _handleRegenerateItemClicked(
          selected, messageIndex, toolbarItem, toolbarItemIndex);
    } else if (toolbarItemIndex == 3) {
      _handleShareItemClicked(
          selected, messageIndex, toolbarItem, toolbarItemIndex);
    } else if (toolbarItemIndex == 4) {
      _handleMoreItemClicked(
          selected, messageIndex, toolbarItem, toolbarItemIndex);
    }
  }

  void _handleThumbUpClicked(
    bool selected,
    int messageIndex,
    AssistMessageToolbarItem toolbarItem,
    int toolbarItemIndex,
  ) {
    setState(() {
      _resetThumbDownIcon(messageIndex, toolbarItemIndex);
      _clearFeedbackCache();
      _isPositiveFeedback = true;
      _footerMessageIndex = messageIndex;
      if (_footerMessageIndex == messageIndex && toolbarItem.isSelected) {
        selected = false;
        _footerMessageIndex = -1;
      }

      final IconData icon =
          selected ? Icons.thumb_up_alt : Icons.thumb_up_off_alt;
      _messages[messageIndex].toolbarItems![toolbarItemIndex] = toolbarItem
          .copyWith(content: _toolbarItem(icon), isSelected: selected);
    });
  }

  void _resetThumbDownIcon(int messageIndex, int thumbUpItemIndex) {
    final List<AssistMessageToolbarItem> toolbarItems =
        _messages[messageIndex].toolbarItems!;
    if (toolbarItems.isNotEmpty) {
      final int thumbDownItemIndex = thumbUpItemIndex + 1;
      final AssistMessageToolbarItem thumbDownItem =
          toolbarItems[thumbDownItemIndex];
      if (thumbDownItem.isSelected) {
        toolbarItems[thumbDownItemIndex] = thumbDownItem.copyWith(
            content: _toolbarItem(Icons.thumb_down_off_alt), isSelected: false);
      }
    }
  }

  void _handleThumbDownClicked(
    bool selected,
    int messageIndex,
    AssistMessageToolbarItem toolbarItem,
    int toolbarItemIndex,
  ) {
    setState(() {
      _resetThumbUpIcon(messageIndex, toolbarItemIndex);
      _clearFeedbackCache();
      _isPositiveFeedback = false;
      _footerMessageIndex = messageIndex;
      if (_footerMessageIndex == messageIndex && toolbarItem.isSelected) {
        selected = false;
        _footerMessageIndex = -1;
      }

      final IconData icon =
          selected ? Icons.thumb_down_alt : Icons.thumb_down_off_alt;
      _messages[messageIndex].toolbarItems![toolbarItemIndex] = toolbarItem
          .copyWith(content: _toolbarItem(icon), isSelected: selected);
    });
  }

  void _resetThumbUpIcon(int messageIndex, int thumbDownItemIndex) {
    final List<AssistMessageToolbarItem> toolbarItems =
        _messages[messageIndex].toolbarItems!;
    if (toolbarItems.isNotEmpty) {
      final int thumbUpItemIndex = thumbDownItemIndex - 1;
      final AssistMessageToolbarItem thumbUpItem =
          toolbarItems[thumbUpItemIndex];
      if (thumbUpItem.isSelected) {
        toolbarItems[thumbUpItemIndex] = thumbUpItem.copyWith(
            content: _toolbarItem(Icons.thumb_up_off_alt), isSelected: false);
      }
    }
  }

  void _handleRegenerateItemClicked(
    bool selected,
    int messageIndex,
    AssistMessageToolbarItem toolbarItem,
    int toolbarItemIndex,
  ) {
    final String request = _messages[messageIndex - 1].data;
    setState(() {
      _messages.removeAt(messageIndex);
      _generateResponse(request).then((_AIMessage response) {
        setState(() {
          _messages.insert(messageIndex, response);
        });
      });
    });
  }

  void _handleShareItemClicked(
    bool selected,
    int messageIndex,
    AssistMessageToolbarItem toolbarItem,
    int toolbarItemIndex,
  ) {
    final RenderBox? renderBox = (toolbarItem.content.key as GlobalKey?)
        ?.currentContext
        ?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final Offset toolbarItemPosition = renderBox.localToGlobal(Offset.zero);
    final Offset pos = renderBox.globalToLocal(toolbarItemPosition);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(0.5, pos.dy, 0, 0),
      items: [
        PopupMenuItem(child: Text('Share conversation')),
        PopupMenuItem(child: Text('Export to Docs')),
        PopupMenuItem(child: Text('Draft in Gmail')),
        PopupMenuItem(child: Text('Export to Replit')),
      ],
    );
  }

  void _handleMoreItemClicked(
    bool selected,
    int messageIndex,
    AssistMessageToolbarItem toolbarItem,
    int toolbarItemIndex,
  ) {}

  @override
  void initState() {
    _messages = <_AIMessage>[];
    _textController = TextEditingController()..addListener(_handleTextChange);
    _feedbackTextController = TextEditingController();
    _selectedChipFeedbackIndices = <int>[];

    _positiveFeedbacks = [
      'Factually correct',
      'Easy to understand',
      'Informative',
      'Creative / Interesting',
      'Well formatted',
      'Other',
    ];
    _negativeFeedbacks = [
      'Offensive / Unsafe',
      'Not factually correct',
      'Didn\'t follow instructions',
      'Wrong language',
      'Poorly formatted',
      'Generic / Bland'
    ];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _themeData = Theme.of(context);
    _actionIconColor = _themeData.colorScheme.onSurface.withAlpha(175);

    return Padding(
      padding: const EdgeInsets.all(10),
      child: SelectionArea(
        child: SfAIAssistViewTheme(
          data: SfAIAssistViewThemeData(
            responseAvatarBackgroundColor: Colors.transparent,
          ),
          child: SfAIAssistView(
            messages: _messages,
            placeholderBuilder: _buildPlaceholder,
            placeholderBehavior: AssistPlaceholderBehavior.hideOnMessage,
            composer: _buildComposer(context),
            bubbleContentBuilder: _buildContent,
            bubbleFooterBuilder: _buildFeedbackContainer,
            responseLoadingBuilder: _buildResponseLoadingBuilder,
            onBubbleToolbarItemSelected: _handleToolbarItemSelected,
            requestBubbleSettings: AssistBubbleSettings(
              widthFactor: 0.95,
              contentBackgroundColor: _themeData.colorScheme.surfaceDim,
              contentPadding: EdgeInsets.all(15),
              contentShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(5),
                  bottomRight: Radius.circular(25),
                  bottomLeft: Radius.circular(25),
                ),
              ),
            ),
            responseBubbleSettings: AssistBubbleSettings(
              widthFactor: 0.95,
            ),
            responseToolbarSettings: AssistMessageToolbarSettings(
              spacing: 0,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController
      ..removeListener(_handleTextChange)
      ..dispose();
    _feedbackTextController.dispose();
    _selectedChipFeedbackIndices.clear();
    _textPainter?.dispose();
    super.dispose();
  }
}

class _MessageContent extends StatefulWidget {
  const _MessageContent({required this.message});

  final _AIMessage message;

  @override
  State<_MessageContent> createState() => _MessageContentState();
}

class _MessageContentState extends State<_MessageContent> {
  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: widget.message.data,
    );
  }
}

class _AnimatedText extends StatefulWidget {
  const _AnimatedText({
    required this.text,
    required this.index,
    required this.minLineHeight,
    required this.messages,
    required this.onLoadingCompleted,
  });

  final String text;
  final int index;
  final double minLineHeight;
  final List<_AIMessage> messages;
  final Function(int) onLoadingCompleted;

  @override
  State<_AnimatedText> createState() => _AnimatedTextState();
}

class _AnimatedTextState extends State<_AnimatedText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onLoadingCompleted(widget.index);
    }
  }

  @override
  void initState() {
    final List<String> texts = widget.text.split(' ');
    final int duration = texts.length * 25;
    _controller = AnimationController(
      duration: Duration(milliseconds: duration),
      vsync: this,
    )..addStatusListener(_handleAnimationStatus);
    if (!widget.messages[widget.index].isLoaded) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Stack(
          alignment: AlignmentDirectional.bottomCenter,
          children: [
            SizeTransition(
              sizeFactor: _controller,
              axisAlignment: -1.0,
              child: child!,
            ),
            Container(
              height: widget.minLineHeight,
              alignment: Alignment.bottomCenter,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withAlpha(0),
                    _controller.value == 1
                        ? Colors.white.withAlpha(0)
                        : Colors.white,
                  ],
                ),
              ),
            ),
          ],
        );
      },
      child: MarkdownBody(data: widget.text),
    );
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }
}

class _AIMessage extends AssistMessage {
  const _AIMessage.request({
    required super.data,
  })  : isLoaded = true,
        super.request();

  const _AIMessage.response({
    required super.data,
    super.author,
    super.toolbarItems,
    this.isLoaded = false,
  }) : super.response();

  final bool isLoaded;

  _AIMessage copyWith({
    String? data,
    AssistMessageAuthor? author,
    List<AssistMessageToolbarItem>? toolbarItems,
    bool? isLoaded,
  }) {
    if (isRequested) {
      return _AIMessage.request(data: data ?? this.data);
    } else {
      return _AIMessage.response(
        data: data ?? this.data,
        author: author ?? this.author,
        toolbarItems: toolbarItems ?? this.toolbarItems,
        isLoaded: isLoaded ?? this.isLoaded,
      );
    }
  }
}
