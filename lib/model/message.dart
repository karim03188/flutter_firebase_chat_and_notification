class MessageAction {
  final String id;
  final String label;

  const MessageAction({required this.id, required this.label});

  factory MessageAction.fromJson(Map<String, dynamic> json) {
    return MessageAction(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

class Message {
  final String sender;
  final String text;
  final DateTime time;
  final String? imagePath;
  final MessageAction? action;

  Message({
    required this.sender,
    required this.text,
    required this.time,
    this.imagePath,
    this.action,
  });
}
