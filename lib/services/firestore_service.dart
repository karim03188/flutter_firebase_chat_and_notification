import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../constants.dart';
import '../model/message.dart';

class FirestoreService {
  final DatabaseReference _messagesRef = FirebaseDatabase.instance.ref(chatRoom);

  Future<void> sendMessage(String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || text.trim().isEmpty) {
      return;
    }

    // Push message to database
    // The Cloud Function will detect this and send FCM to other users
    await _messagesRef.push().set({
      'sender': user.email ?? 'unknown',
      'text': text.trim(),
      'time': ServerValue.timestamp,
    });
  }

  Stream<List<Message>> getMessages() {
    return _messagesRef.orderByChild('time').onValue.map((event) {
      final data = event.snapshot.value;
      if (data is! Map) {
        return <Message>[];
      }

      final messages = <Message>[];
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is! Map) {
          continue;
        }

        final item = Map<String, dynamic>.from(value);
        final timestamp = item['time'];
        final time = timestamp is int
            ? DateTime.fromMillisecondsSinceEpoch(timestamp)
            : DateTime.now();

        messages.add(
          Message(
            sender: item['sender']?.toString() ?? 'unknown',
            text: item['text']?.toString() ?? '',
            time: time,
          ),
        );
      }

      messages.sort((a, b) => a.time.compareTo(b.time));
      return messages;
    });
  }
}
