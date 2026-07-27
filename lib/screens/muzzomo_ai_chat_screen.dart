import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../model/message.dart';
import '../services/api_service.dart';
import '../widgets/message_bubble.dart';
import 'rooms_screen.dart';

const _muzzomoSenderName = 'Muzzomo AI';

class MuzzomoAiChatScreen extends StatefulWidget {
  const MuzzomoAiChatScreen({super.key});

  @override
  State<MuzzomoAiChatScreen> createState() => _MuzzomoAiChatScreenState();
}

class _MuzzomoAiChatScreenState extends State<MuzzomoAiChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Message> _messages = [];
  final _imagePicker = ImagePicker();

  int? _conversationId;
  bool _isSending = false;
  File? _pendingImage;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _pendingImage = File(picked.path));
  }

  void _handleAction(MessageAction action) {
    switch (action.id) {
      case 'open_rooms':
      case 'open_create_room':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RoomsScreen()),
        );
        break;
      case 'open_users':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RoomsScreen()),
        );
        break;
      case 'open_notification_preferences':
        // No dedicated preferences screen yet — surface where it will live.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification preferences screen coming soon.')),
        );
        break;
    }
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
    if ((text.isEmpty && _pendingImage == null) || _isSending) return;

    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final imageToSend = _pendingImage;

    setState(() {
      _messages.add(Message(
        sender: currentEmail,
        text: text,
        time: DateTime.now(),
        imagePath: imageToSend?.path,
      ));
      _isSending = true;
      _messageController.clear();
      _pendingImage = null;
    });
    _scrollToBottom();

    final result = await ApiService.askMuzzomoAi(
      question: text.isEmpty ? 'What do you see in this image?' : text,
      conversationId: _conversationId,
      image: imageToSend,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _messages.add(Message(
          sender: _muzzomoSenderName,
          text: 'Something went wrong getting a response. Please try again.',
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
    final actionJson = lastAssistantMessage['action'] as Map<String, dynamic>?;

    setState(() {
      _messages.add(Message(
        sender: _muzzomoSenderName,
        text: answer.isEmpty ? 'No response received.' : answer,
        time: DateTime.now(),
        action: actionJson == null ? null : MessageAction.fromJson(actionJson),
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
              'Chat with Muzzomo AI',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            Text(
              'Document-grounded AI assistant',
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
                          'Ask Muzzomo AI',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Answers are grounded in the trained documents',
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
                              Text('Muzzomo is typing a response...'),
                            ],
                          ),
                        );
                      }

                      final message = _messages[index];
                      final isMe = message.sender == currentEmail;

                      return MessageBubble(
                        message: message,
                        isMe: isMe,
                        onActionTap: _handleAction,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pendingImage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(_pendingImage!, width: 64, height: 64, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: -8,
                            right: -8,
                            child: GestureDetector(
                              onTap: () => setState(() => _pendingImage = null),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                children: [
                  IconButton(
                    onPressed: _isSending ? null : _pickImage,
                    icon: Icon(Icons.image_outlined, color: Colors.grey.shade600),
                  ),
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
                        // No explicit textDirection here: Flutter's text
                        // layout already auto-detects per-paragraph bidi
                        // direction from the Unicode bidi algorithm. Forcing
                        // textDirection via setState on every keystroke was
                        // resetting the IME composing region and made
                        // Persian/Arabic characters vanish while typing.
                        textAlign: TextAlign.start,
                        decoration: InputDecoration(
                          hintText: 'Ask a question in any language...',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
