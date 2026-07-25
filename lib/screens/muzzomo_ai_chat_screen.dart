import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../model/message.dart';
import '../services/api_service.dart';
import '../widgets/message_bubble.dart';

const _muzzomoSenderName = 'Muzzomo AI';

final _rtlScriptPattern = RegExp(r'[֐-׿؀-ۿ܀-ࣿיִ-﷿ﹰ-﻿]');

TextDirection _detectTextDirection(String text) {
  return _rtlScriptPattern.hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;
}

class MuzzomoAiChatScreen extends StatefulWidget {
  const MuzzomoAiChatScreen({super.key});

  @override
  State<MuzzomoAiChatScreen> createState() => _MuzzomoAiChatScreenState();
}

class _MuzzomoAiChatScreenState extends State<MuzzomoAiChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Message> _messages = [];

  int? _conversationId;
  bool _isSending = false;
  TextDirection _inputDirection = TextDirection.rtl;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    final direction = _detectTextDirection(_messageController.text);
    if (direction != _inputDirection) {
      setState(() => _inputDirection = direction);
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onInputChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    setState(() {
      _messages.add(Message(sender: currentEmail, text: text, time: DateTime.now()));
      _isSending = true;
      _messageController.clear();
    });
    _scrollToBottom();

    final result = await ApiService.askMuzzomoAi(
      question: text,
      conversationId: _conversationId,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _messages.add(Message(
          sender: _muzzomoSenderName,
          text: 'مشکلی در دریافت پاسخ پیش آمد. دوباره تلاش کنید.',
          time: DateTime.now(),
        ));
        _isSending = false;
      });
      _scrollToBottom();
      return;
    }

    _conversationId = result['id'] as int?;
    final messages = List<Map<String, dynamic>>.from(result['messages'] ?? []);
    final lastAssistantMessage = messages.lastWhere(
      (m) => m['role'] == 'assistant',
      orElse: () => const {},
    );
    final answer = lastAssistantMessage['content'] as String? ?? '';

    setState(() {
      _messages.add(Message(
        sender: _muzzomoSenderName,
        text: answer.isEmpty ? 'پاسخی دریافت نشد.' : answer,
        time: DateTime.now(),
      ));
      _isSending = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'چت با مزومو AI',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            Text(
              'دستیار هوشمند مبتنی بر اسناد',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.smart_toy_outlined, size: 64, color: Colors.grey.shade200),
                        const SizedBox(height: 16),
                        Text(
                          'از مزومو AI بپرس',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'پاسخ‌ها بر اساس اسناد آموزش‌دیده است',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text('مزومو در حال نوشتن پاسخ است...'),
                            ],
                          ),
                        );
                      }

                      final message = _messages[index];
                      final isMe = message.sender == currentEmail;

                      return MessageBubble(
                        message: message,
                        isMe: isMe,
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: _messageController,
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !_isSending,
                        textDirection: _inputDirection,
                        textAlign: _inputDirection == TextDirection.rtl
                            ? TextAlign.right
                            : TextAlign.left,
                        decoration: InputDecoration(
                          hintText: 'سوال خود را بپرسید...',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          hintTextDirection: TextDirection.rtl,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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
