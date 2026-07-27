import 'dart:io';

import 'package:flutter/material.dart';

import '../model/message.dart';

final _rtlScriptPattern = RegExp(r'[֐-׿؀-ۿ܀-ࣿיִ-﷿ﹰ-﻿]');

TextDirection _detectTextDirection(String text) {
  return _rtlScriptPattern.hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;
}

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final void Function(MessageAction action)? onActionTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onActionTap,
  });

  Color _getSenderColor(String sender) {
    final colors = [
      Colors.blue,
      Colors.teal,
      Colors.indigo,
      Colors.deepPurple,
      Colors.pink,
      Colors.orange,
    ];
    return colors[sender.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final time = message.time.toLocal();
    final timeText =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final senderColor = _getSenderColor(message.sender);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: senderColor.withOpacity(0.15),
              child: Text(
                message.sender.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: senderColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.sender,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: senderColor,
                        ),
                      ),
                    ),
                  if (message.imagePath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(message.imagePath!),
                        width: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      textDirection: _detectTextDirection(message.text),
                      style: TextStyle(
                        fontSize: 15,
                        color: isMe ? Colors.white : Colors.black87,
                      ),
                    ),
                  if (message.action != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: onActionTap == null
                          ? null
                          : () => onActionTap!(message.action!),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isMe ? Colors.white : senderColor,
                        side: BorderSide(color: isMe ? Colors.white : senderColor),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                      child: Text(message.action!.label),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      timeText,
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.white60 : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
