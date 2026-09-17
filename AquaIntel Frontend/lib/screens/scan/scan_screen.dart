import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../config.dart';
import '../../models/scan_result.dart';
import '../../providers/upload_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/aq_button.dart';
import '../../widgets/pipeline_step_tile.dart';
import '../../widgets/sonar_loader.dart';
import '../../widgets/detection_row.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const _recentFiles = ['harbor_scan_042.xtf', 'port_mormugao_07.xtf', 'zone_b_deep.npy', 'survey_0829.geotiff'];

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UploadProvider>();

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: Text('Scan & Upload', style: AppTextStyles.title),
            actions: [
              if (prov.result != null)
                TextButton(onPressed: () => prov.reset(), child: const Text('New Scan')),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s24, 0, AppSpacing.s24, 160),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Upload Zone ──
                if (prov.isIdle) ...[
                  const SizedBox(height: AppSpacing.s16),
                  _UploadZone(onFileSelected: (f) => prov.startBackendUpload(f)),
                  const SizedBox(height: AppSpacing.s32),

                  // Supported Formats
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    decoration: BoxDecoration(color: AppColors.veryLightBlue, borderRadius: BorderRadius.circular(AppRadius.medium)),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.primaryBlue, size: 16),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Text('Supported formats: XTF, GeoTIFF, PNG, NPY, JSON', style: AppTextStyles.caption.copyWith(color: AppColors.primaryBlue)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s32),

                  // Recent Files
                  Text('Recent Uploads', style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.s16),
                  ..._recentFiles.map((f) => _RecentFileTile(filename: f, onTap: () => prov.startBackendUpload(f))),
                ],

                // ── Processing Pipeline ──
                if (prov.result != null) ...[
                  const SizedBox(height: AppSpacing.s24),
                  _ScanHeader(result: prov.result!),
                  const SizedBox(height: AppSpacing.s32),
                  Text('Processing Pipeline', style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.s24),
                  ...PipelineStep.values.map((step) {
                    final r = prov.result!;
                    final stepIdx = PipelineStep.values.indexOf(step);
                    bool isDone = stepIdx < r.completedSteps;
                    bool isActive = r.activeStep == step;

                    if (step == PipelineStep.missionReady && r.isComplete) {
                      final hasData = (r.detections != null && r.detections!.isNotEmpty) &&
                                      (r.missionAdvisory != null && r.missionAdvisory!.isNotEmpty);
                      if (!hasData) {
                        isActive = true;
                        isDone = false;
                      } else {
                        isActive = false;
                        isDone = true;
                      }
                    }

                    return PipelineStepTile(
                      step:     step,
                      isDone:   isDone,
                      isActive: isActive,
                      progress: r.stepProgress[step] ?? 0.0,
                      elapsed:  r.stepElapsed[step],
                    );
                  }),
                  if (prov.result!.hasError) ...[
                    const SizedBox(height: AppSpacing.s24),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.danger, size: 28),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Processing Failed', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.danger, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  prov.result!.errorMessage ?? 'An unknown error occurred during processing.',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => prov.reset(),
                            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ] else if (prov.result!.isComplete) ...[
                    const SizedBox(height: AppSpacing.s32),
                    _CompletionCard(result: prov.result!),
                  ],
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadZone extends StatefulWidget {
  final ValueChanged<String> onFileSelected;
  const _UploadZone({required this.onFileSelected});

  @override
  State<_UploadZone> createState() => _UploadZoneState();
}

class _UploadZoneState extends State<_UploadZone> {
  final bool _hovering = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      widget.onFileSelected(result.files.single.path!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 200,
        decoration: BoxDecoration(
          color: _hovering ? AppColors.veryLightBlue : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(
            color: _hovering ? AppColors.primaryBlue : AppColors.border,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(color: AppColors.veryLightBlue, shape: BoxShape.circle),
              child: const Icon(Icons.cloud_upload_outlined, color: AppColors.primaryBlue, size: 40),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text('Tap to browse or drag sonar log', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.s4),
            Text('XTF • GeoTIFF • NPY • PNG', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.s16),
            TextButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: const Text('Browse File'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentFileTile extends StatelessWidget {
  final String filename;
  final VoidCallback onTap;
  const _RecentFileTile({required this.filename, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: AppColors.veryLightBlue, borderRadius: BorderRadius.circular(AppRadius.small)),
          child: const Icon(Icons.insert_drive_file_outlined, color: AppColors.primaryBlue, size: 20),
        ),
        title: Text(filename, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text('2 days ago', style: AppTextStyles.caption),
        trailing: IconButton(
          icon: const Icon(Icons.play_circle_outline_rounded, color: AppColors.primaryBlue),
          onPressed: onTap,
        ),
      ),
    );
  }
}

class _ScanHeader extends StatelessWidget {
  final ScanResult result;
  const _ScanHeader({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Row(
        children: [
          const SonarLoader(size: 56, color: Colors.white),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.fileName, style: AppTextStyles.bodyLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  result.isComplete ? '? Processing complete' : 'Processing...',
                  style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionCard extends StatefulWidget {
  final ScanResult result;
  const _CompletionCard({required this.result});
  @override
  State<_CompletionCard> createState() => _CompletionCardState();
}

class _CompletionCardState extends State<_CompletionCard> {
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();
  final List<_ChatMsg> _messages = [];
  bool _isSending = false;
  bool _chatExpanded = false;
  String? _lastSurveyId;

  @override
  void didUpdateWidget(_CompletionCard old) {
    super.didUpdateWidget(old);
    final newId = widget.result.uploadId;
    if (newId != null && newId != _lastSurveyId) {
      _messages.clear();
      _lastSurveyId = newId;
    }
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isSending) return;
    _chatController.clear();

    setState(() {
      _messages.add(_ChatMsg(role: 'user', content: text));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final history = _messages.sublist(0, _messages.length - 1).map((m) => {
        'role': m.role,
        'content': m.content,
      }).toList();

      final uri = Uri.parse('${AppConfig.baseUrl}/mission-advisor/chat');
      final response = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'survey_id': widget.result.uploadId ?? 'unknown',
          'message': text,
          'history': history,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        setState(() => _messages.add(_ChatMsg(role: 'assistant', content: data['reply']?.toString() ?? 'No response.')));
      } else {
        setState(() => _messages.add(_ChatMsg(role: 'assistant', content: 'Error ${response.statusCode}. Please retry.')));
      }
    } catch (e) {
      setState(() => _messages.add(_ChatMsg(role: 'assistant', content: 'Network error: $e')));
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final hasData = (result.detections != null && result.detections!.isNotEmpty) &&
                    (result.missionAdvisory != null && result.missionAdvisory!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Mission Ready Card ──
        Container(
          padding: const EdgeInsets.all(AppSpacing.s24),
          decoration: BoxDecoration(
            color: hasData ? AppColors.successBg : AppColors.veryLightBlue,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: hasData ? AppColors.success.withValues(alpha: 0.3) : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  hasData
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28)
                    : const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue)),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Text(
                      hasData ? 'Mission Ready' : 'Finalizing Mission Analysis...',
                      style: AppTextStyles.title.copyWith(color: hasData ? AppColors.success : AppColors.primaryBlue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s20),

              // Detections
              Text('Detections', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.s12),
              if (result.detections == null || result.detections!.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.medium)),
                  child: Text('Analyzing...', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                )
              else
                ...result.detections!.map((d) => DetectionRow(detection: d, onTap: () {})),

              const SizedBox(height: AppSpacing.s24),

              // Mission Advisory
              Text('Mission Advisory', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.s12),
              _AdvisorySection(advisory: result.missionAdvisory),

              if (hasData) ...[
                const SizedBox(height: AppSpacing.s24),
                AqButton(label: 'View on Map', icon: Icons.map_outlined, isFullWidth: true, onPressed: () => context.go('/map')),
              ],
            ],
          ),
        ),

        // ── Ask Copilot ──
        const SizedBox(height: AppSpacing.s16),
        _CopilotPanel(
          expanded: _chatExpanded,
          messages: _messages,
          isSending: _isSending,
          controller: _chatController,
          scrollController: _chatScrollController,
          onToggle: () => setState(() => _chatExpanded = !_chatExpanded),
          onSend: _sendMessage,
        ),
      ],
    );
  }
}

class _ChatMsg {
  final String role;
  final String content;
  const _ChatMsg({required this.role, required this.content});
}

/// Null-safe advisory display with structured sections
class _AdvisorySection extends StatelessWidget {
  final String? advisory;
  const _AdvisorySection({required this.advisory});

  @override
  Widget build(BuildContext context) {
    if (advisory == null || advisory!.trim().isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.medium)),
        child: Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue)),
            const SizedBox(width: AppSpacing.s12),
            Text('Awaiting AI analysis...', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.medium)),
      child: Text(
        advisory!,
        style: AppTextStyles.body.copyWith(height: 1.6),
      ),
    );
  }
}

/// Expandable Copilot chat panel
class _CopilotPanel extends StatelessWidget {
  final bool expanded;
  final List<_ChatMsg> messages;
  final bool isSending;
  final TextEditingController controller;
  final ScrollController scrollController;
  final VoidCallback onToggle;
  final VoidCallback onSend;

  const _CopilotPanel({
    required this.expanded,
    required this.messages,
    required this.isSending,
    required this.controller,
    required this.scrollController,
    required this.onToggle,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Header / toggle
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppRadius.large),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.veryLightBlue, shape: BoxShape.circle),
                    child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryBlue, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ask Copilot', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                        Text('Follow-up questions about detections & risks', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),

          if (expanded) ...[
            const Divider(height: 1),

            // Message thread
            if (messages.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _MessageBubble(msg: messages[i]),
                ),
              ),

            if (isSending)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
                child: Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue)),
                    SizedBox(width: 8),
                    Text('Copilot is thinking...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),

            // Input row
            Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s8, AppSpacing.s16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onSubmitted: (_) => onSend(),
                      decoration: InputDecoration(
                        hintText: 'Ask about detections, risks, retrieval...',
                        hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.veryLightBlue,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Material(
                    color: AppColors.primaryBlue,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onSend,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMsg msg;
  const _MessageBubble({required this.msg});

  bool get isUser => msg.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
            ),
            const SizedBox(width: AppSpacing.s8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primaryBlue : AppColors.veryLightBlue,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                msg.content,
                style: AppTextStyles.caption.copyWith(
                  color: isUser ? Colors.white : AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: AppSpacing.s8),
        ],
      ),
    );
  }
}




