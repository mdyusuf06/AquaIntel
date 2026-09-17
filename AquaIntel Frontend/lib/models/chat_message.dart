enum ChatRole { user, ai, system }

enum ChatCardType { none, detectionCard, chartCard, tableCard, mapCard }

class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final DateTime timestamp;
  final bool isStreaming;
  final ChatCardType cardType;
  final Map<String, dynamic>? cardData;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.isStreaming = false,
    this.cardType    = ChatCardType.none,
    this.cardData,
  });

  ChatMessage copyWith({String? text, bool? isStreaming}) => ChatMessage(
    id:          id,
    role:        role,
    text:        text ?? this.text,
    timestamp:   timestamp,
    isStreaming:  isStreaming ?? this.isStreaming,
    cardType:    cardType,
    cardData:    cardData,
  );

  static ChatMessage userMsg(String text) => ChatMessage(
    id:        DateTime.now().millisecondsSinceEpoch.toString(),
    role:      ChatRole.user,
    text:      text,
    timestamp: DateTime.now(),
  );

  static ChatMessage aiMsg(String text, {bool isStreaming = false, ChatCardType cardType = ChatCardType.none, Map<String, dynamic>? cardData}) =>
    ChatMessage(
      id:          DateTime.now().millisecondsSinceEpoch.toString(),
      role:        ChatRole.ai,
      text:        text,
      timestamp:   DateTime.now(),
      isStreaming:  isStreaming,
      cardType:    cardType,
      cardData:    cardData,
    );

  static ChatMessage systemMsg(String text) => ChatMessage(
    id:        DateTime.now().millisecondsSinceEpoch.toString(),
    role:      ChatRole.system,
    text:      text,
    timestamp: DateTime.now(),
  );
}
