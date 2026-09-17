import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/detection.dart';
import '../data/advisor_repository.dart';

class ChatProvider extends ChangeNotifier {
  final AdvisorRepository _repo;

  ChatProvider(this._repo);

  final List<ChatMessage> _messages = [];
  bool _isLoading    = false;
  bool _isRecording  = false;
  String _language   = 'English';
  String _transcript = '';

  List<ChatMessage> get messages   => List.unmodifiable(_messages);
  bool   get isLoading   => _isLoading;
  bool   get isRecording => _isRecording;
  String get language    => _language;
  String get transcript  => _transcript;

  static const _suggestions = [
    'Show all red hazards',
    'Summarize today\'s mission',
    'What is the nearest ghost net?',
    'Explain the highest risk target',
    'Export mission report',
    'What are current sea conditions?',
  ];
  List<String> get suggestions => _suggestions;

  void init(List<Detection> detections) {
    if (_messages.isNotEmpty) return;
    _messages.add(ChatMessage.aiMsg(
      'Hello! I\'m **AquaCopilot** — your AI mission advisor.\n\nI have loaded **${detections.length} detection(s)** from the current survey. Ask me anything about risk, navigation hazards, debris classification, or export a mission report.',
    ));
    notifyListeners();
  }

  Future<void> sendMessage(String text, List<Detection> detections) async {
    if (text.trim().isEmpty) return;
    _messages.add(ChatMessage.userMsg(text.trim()));
    _isLoading = true;
    notifyListeners();

    // Optimistic streaming placeholder
    final placeholder = ChatMessage.aiMsg('', isStreaming: true);
    _messages.add(placeholder);
    notifyListeners();

    try {
      final response = await _repo.ask(text, detections);
      _messages[_messages.length - 1] = placeholder.copyWith(
        text: response,
        isStreaming: false,
      );
    } catch (e) {
      _messages[_messages.length - 1] = placeholder.copyWith(
        text: '⚠️ Backend unreachable. ${_localResponse(text, detections)}',
        isStreaming: false,
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  void toggleRecording() {
    _isRecording = !_isRecording;
    if (!_isRecording) _transcript = '';
    notifyListeners();
  }

  void setTranscript(String t) {
    _transcript = t;
    notifyListeners();
  }

  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
  }

  void clearChat() {
    _messages.clear();
    notifyListeners();
  }

  /// Local fallback response when backend is offline.
  String _localResponse(String input, List<Detection> detections) {
    final lower = input.toLowerCase();
    if (detections.isEmpty) return 'No detections loaded yet.';

    if (lower.contains('red') || lower.contains('hazard')) {
      final reds = detections.where((d) => d.riskTier == 'red').toList();
      if (reds.isEmpty) return 'No red-tier detections currently. All clear!';
      return 'Found **${reds.length} red-tier hazard(s)**:\n${reds.map((d) => '• **${d.displayType}** (${d.id}) — ${d.clearanceM.toStringAsFixed(1)}m clearance').join('\n')}';
    }
    if (lower.contains('summarize') || lower.contains('summary') || lower.contains('today')) {
      final avg = detections.map((d) => d.confidence).reduce((a, b) => a + b) / detections.length;
      final reds = detections.where((d) => d.riskTier == 'red').length;
      final ambers = detections.where((d) => d.riskTier == 'amber').length;
      final greens = detections.where((d) => d.riskTier == 'green').length;
      return '**Mission Summary**\n\n- Total targets: **${detections.length}**\n- 🔴 Red: **$reds** | 🟡 Amber: **$ambers** | 🟢 Green: **$greens**\n- Avg confidence: **${(avg * 100).toStringAsFixed(0)}%**\n\nRecommendation: ${reds > 0 ? "Prioritize verification of $reds red-tier objects before resuming vessel transit." : "All detections within safe parameters."}';
    }
    if (lower.contains('ghost net') || lower.contains('nearest')) {
      final nets = detections.where((d) => d.type.contains('ghost_net') || d.type.contains('net')).toList();
      if (nets.isEmpty) return 'No ghost nets detected in the current survey.';
      nets.sort((a, b) => a.clearanceM.compareTo(b.clearanceM));
      final n = nets.first;
      return 'Nearest ghost net: **${n.id}**\n- Clearance: **${n.clearanceM.toStringAsFixed(1)}m**\n- Confidence: **${(n.confidence * 100).toStringAsFixed(0)}%**\n- Risk: **${n.riskTier.toUpperCase()}**\n- Position: ${n.lat.toStringAsFixed(4)}°N, ${n.lon.toStringAsFixed(4)}°E';
    }

    return 'I can help you with:\n- 🔴 **Risk analysis** — "Show all red hazards"\n- 📊 **Mission summary** — "Summarize today\'s mission"\n- 🎯 **Specific targets** — "Explain target T-001"\n- 📄 **Reports** — "Export mission report"\n\nWhat would you like to know?';
  }
}
