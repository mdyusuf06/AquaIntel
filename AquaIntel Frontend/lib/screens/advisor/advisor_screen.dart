import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/detection_provider.dart';
import '../../theme/app_colors.dart';

class AdvisorScreen extends StatefulWidget {
  final String? preloadedTargetId;
  const AdvisorScreen({super.key, this.preloadedTargetId});
  @override State<AdvisorScreen> createState() => _AdvisorScreenState();
}

class _AdvisorScreenState extends State<AdvisorScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isRecording = false;
  String _language = 'English';
  final List<_Msg> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.add(_Msg(text: 'Hello! I\'m AquaCopilot — your AquaIntel mission advisor. Ask me anything about your survey, detections, or risk assessments.', isUser: false));
    if (widget.preloadedTargetId != null) {
      Future.microtask(() {
        if (!mounted) return;
        final d = context.read<DetectionProvider>().getById(widget.preloadedTargetId!);
        if (d != null) _addResponse(d.id);
      });
    }
  }

  @override
  void dispose() { _controller.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  String _generateResponse(String input, DetectionProvider prov) {
    final lower = input.toLowerCase();
    final dets  = prov.allDetections;

    if (dets.isEmpty) {
      return 'No detections loaded yet. Upload a sonar log to begin, then ask me anything!';
    }

    if (lower.contains('red') || lower.contains('show all red')) {
      final reds = dets.where((d) => d.riskTier == 'red').toList();
      if (reds.isEmpty) return 'No red-tier detections in the current survey — all clear!';
      return 'There are ${reds.length} red-tier detections: ${reds.map((d) => d.id).join(", ")}. These require immediate operator verification.';
    }
    if (lower.contains('summarize') || lower.contains('today')) {
      final avgConf = dets.map((d) => d.confidence).reduce((a, b) => a + b) / dets.length;
      final reds    = dets.where((d) => d.riskTier == 'red').length;
      final ambers  = dets.where((d) => d.riskTier == 'amber').length;
      final greens  = dets.where((d) => d.riskTier == 'green').length;
      return 'Current survey: ${dets.length} targets detected. Avg confidence: ${(avgConf * 100).round()}%. $reds red ∙ $ambers amber ∙ $greens green.';
    }
    if (lower.contains('mark resolved')) {
      return 'No targets marked as resolved yet. Use Verify or Reject on individual detections to update their status.';
    }
    final ids = dets.map((d) => d.id.toLowerCase()).where((id) => lower.contains(id));
    if (ids.isNotEmpty) {
      return _generateDetailResponse(ids.first.toUpperCase(), prov);
    }
    return 'I can answer questions about specific targets (e.g., "Why is T-001 red?"), summarize surveys, or filter by risk tier. What would you like to know?';
  }

  String _generateDetailResponse(String id, DetectionProvider prov) {
    final d = prov.getById(id);
    if (d == null) return 'I could not find target $id in the current survey.';
    final clearText = d.clearanceM < 5 ? 'Critically low clearance (<5m).' : d.clearanceM < 20 ? 'Caution clearance (<20m).' : 'Clearance is acceptable.';
    final impact = d.impactType != null ? '${d.impactType} (${d.impactSeverity})' : 'Potential navigational hazard';
    
    return 'IDENTIFICATION\n'
        'Target ${d.id} is a ${d.displayType} detected with ${(d.confidence * 100).round()}% confidence at a depth clearance of ${d.clearanceM}m.\n\n'
        'ECOLOGICAL IMPACT\n'
        '$impact. $clearText\n\n'
        'ACTION PLAN\n'
        '1. Maintain a minimum safe distance of 50m.\n'
        '2. Dispatch ROV for closer visual inspection.\n'
        '3. Log coordinates and notify maritime authorities if ${d.impactSeverity?.toLowerCase() == 'high' || d.riskTier == 'red' ? 'immediately' : 'required'}.';
  }

  void _send([String? text]) {
    final msg = text ?? _controller.text.trim();
    if (msg.isEmpty) return;
    setState(() { _messages.add(_Msg(text: msg, isUser: true)); _controller.clear(); });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final prov     = context.read<DetectionProvider>();
      final response = _generateResponse(msg, prov);
      if (!mounted) return;
      setState(() => _messages.add(_Msg(text: response, isUser: false)));
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    });
  }

  void _addResponse(String targetId) {
    final prov = context.read<DetectionProvider>();
    setState(() => _messages.add(_Msg(text: _generateDetailResponse(targetId, prov), isUser: false)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AquaCopilot'),
        actions: [
          DropdownButton<String>(
            value: _language,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.language, color: AppColors.textPrimary),
            items: ['English', 'Hindi', 'Tamil'].map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _language = v!),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Quick reply chips
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'Show all red targets', 'Summarize today\'s survey', 'Mark resolved',
                ].map((q) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(q, style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue)),
                    backgroundColor: Color.fromRGBO(2, 132, 199, 0.08),
                    side: BorderSide.none,
                    onPressed: () => _send(q),
                  ),
                )).toList(),
              ),
            ),
          ),
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _ChatBubble(msg: _messages[i]),
            ),
          ),
          // Input bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFECF2FA))),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isRecording = !_isRecording),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? Color.fromRGBO(220, 38, 38, 0.15)
                            : Color.fromRGBO(2, 132, 199, 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.mic,
                          color: _isRecording ? AppColors.danger : AppColors.primaryBlue,
                          size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: _isRecording ? 'Listening… ($_language)' : 'Ask anything…',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        fillColor: const Color(0xFFF3F8FF),
                        filled: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _send(),
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
                      child: const Icon(Icons.send, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Msg { final String text; final bool isUser; const _Msg({required this.text, required this.isUser}); }

class _ChatBubble extends StatelessWidget {
  final _Msg msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: msg.isUser ? AppColors.primaryBlue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
            bottomLeft: msg.isUser ? const Radius.circular(18) : const Radius.circular(4),
            bottomRight: msg.isUser ? const Radius.circular(4) : const Radius.circular(18),
          ),
          border: msg.isUser ? null : Border.all(color: const Color(0xFFE1EAF5)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
        ),
        child: Text(msg.text, style: TextStyle(color: msg.isUser ? Colors.white : AppColors.textPrimary, fontSize: 14, height: 1.45)),
      ),
    );
  }
}
