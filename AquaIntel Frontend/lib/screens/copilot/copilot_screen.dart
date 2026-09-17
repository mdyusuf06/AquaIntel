import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_message.dart';
import '../../providers/chat_provider.dart';
import '../../providers/detection_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_animations.dart';

class CopilotScreen extends StatefulWidget {
  const CopilotScreen({super.key});
  @override State<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends State<CopilotScreen> with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dets = context.read<DetectionProvider>().allDetections;
      context.read<ChatProvider>().init(dets);
    });
  }

  @override
  void dispose() { _controller.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  void _send([String? text]) {
    final msg  = text ?? _controller.text.trim();
    final dets = context.read<DetectionProvider>().allDetections;
    _controller.clear();
    context.read<ChatProvider>().sendMessage(msg, dets).then((_) => _scrollToBottom());
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: AppAnimations.normal, curve: AppAnimations.spring);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat    = context.watch<ChatProvider>();
    final msgs    = chat.messages;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── App Bar ──
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s24, AppSpacing.s16, AppSpacing.s24, AppSpacing.s12),
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(AppRadius.small)),
                    child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AquaCopilot', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                        Row(children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('Online · Sarvam connected', style: AppTextStyles.micro.copyWith(color: AppColors.success)),
                        ]),
                      ],
                    ),
                  ),
                  // Language selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s6),
                    decoration: BoxDecoration(color: AppColors.surfaceGray, borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: DropdownButton<String>(
                      value: chat.language,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.language_rounded, size: 16, color: AppColors.textSecondary),
                      isDense: true,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                      items: ['English','Hindi','Tamil','Telugu','Malayalam']
                        .map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                      onChanged: (v) => chat.setLanguage(v!),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 20), onPressed: chat.clearChat, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),

          // ── Suggestion Chips ──
          Container(
            color: Colors.white,
            child: Column(
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                    child: Row(
                      children: chat.suggestions.map((s) => Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.s8),
                        child: GestureDetector(
                          onTap: () => _send(s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s8),
                            decoration: BoxDecoration(
                              color: AppColors.veryLightBlue,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              border: Border.all(color: AppColors.lightBlue),
                            ),
                            child: Text(s, style: AppTextStyles.caption.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Voice Mode Overlay ──
          if (chat.isRecording)
            Container(
              padding: const EdgeInsets.all(AppSpacing.s24),
              color: AppColors.dangerBg,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _VoiceWaveform(),
                  const SizedBox(width: AppSpacing.s16),
                  Text('Listening in ${chat.language}...', style: AppTextStyles.body.copyWith(color: AppColors.danger, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          // ── Messages ──
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s12),
              itemCount: msgs.length,
              itemBuilder: (_, i) => _ChatBubble(message: msgs[i]),
            ),
          ),

          // ── Input Bar ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [BoxShadow(color: AppColors.shadow.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4))],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s12),
                child: Row(
                  children: [
                    // Mic button
                    GestureDetector(
                      onTap: () { context.read<ChatProvider>().toggleRecording(); },
                      child: AnimatedContainer(
                        duration: AppAnimations.fast,
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: chat.isRecording ? AppColors.dangerBg : AppColors.veryLightBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.mic_rounded, color: chat.isRecording ? AppColors.danger : AppColors.primaryBlue, size: 22),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    // Text field
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: AppTextStyles.body,
                        minLines: 1, maxLines: 3,
                        decoration: InputDecoration(
                          hintText: chat.isRecording ? 'Listening...' : 'Ask about detections, risk, or mission...',
                          hintStyle: AppTextStyles.body.copyWith(color: AppColors.textDisabled),
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.pill), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.pill), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.pill), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
                          fillColor: AppColors.surfaceGray,
                          filled: true,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    // Send button
                    GestureDetector(
                      onTap: chat.isLoading ? null : _send,
                      child: AnimatedContainer(
                        duration: AppAnimations.fast,
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: chat.isLoading ? AppColors.border : AppColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(chat.isLoading ? Icons.hourglass_top_rounded : Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  bool get _isUser => message.role == ChatRole.user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Row(
        mainAxisAlignment: _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isUser) ...[
            Container(
              width: 30, height: 30,
              margin: const EdgeInsets.only(right: AppSpacing.s8),
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: _isUser ? AppColors.primaryBlue : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(18),
                  topRight:    const Radius.circular(18),
                  bottomLeft:  Radius.circular(_isUser ? 18 : 4),
                  bottomRight: Radius.circular(_isUser ? 4 : 18),
                ),
                border: _isUser ? null : Border.all(color: AppColors.border),
                boxShadow: [BoxShadow(color: AppColors.shadow.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: message.isStreaming
                ? const _TypingIndicator()
                : _BubbleText(text: message.text, isUser: _isUser),
            ),
          ),
          if (_isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Parses **bold**, *italic* and renders them inline.
class _BubbleText extends StatelessWidget {
  final String text;
  final bool isUser;
  const _BubbleText({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final baseStyle = AppTextStyles.body.copyWith(
      color: isUser ? Colors.white : AppColors.textPrimary,
      height: 1.5,
    );
    return Text(text, style: baseStyle);
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with TickerProviderStateMixin {
  late List<AnimationController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600)));
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _ctrls[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() { for (final c in _ctrls) { c.dispose(); } super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => AnimatedBuilder(
        animation: _ctrls[i],
        builder: (_, __) => Container(
          margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.3 + _ctrls[i].value * 0.7),
            shape: BoxShape.circle,
          ),
        ),
      )),
    );
  }
}

class _VoiceWaveform extends StatefulWidget {
  const _VoiceWaveform();
  @override State<_VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<_VoiceWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _ctrl.repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        children: List.generate(7, (i) {
          final height = 8.0 + sin((_ctrl.value * 2 * pi) + i * 0.8).abs() * 16;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 4, height: height,
            decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(2)),
          );
        }),
      ),
    );
  }
}

