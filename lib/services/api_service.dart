import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';

class ApiService {
  static bool get isAuthenticated => FirebaseAuth.instance.currentUser != null;

  /// Firebase is the single source of truth for auth — Django verifies the
  /// same Firebase ID token on every request instead of issuing its own JWT.
  /// `getIdToken()` returns the cached token and transparently refreshes it
  /// when it's close to expiry, so callers never need to manage it manually.
  static Future<String?> _idToken() async {
    return FirebaseAuth.instance.currentUser?.getIdToken();
  }

  static Future<http.Response> _authenticatedRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _idToken();
    if (token == null) throw Exception('Not authenticated');

    final uri = Uri.parse('$djangoBaseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    switch (method) {
      case 'POST':
        return http.post(uri, headers: headers, body: jsonEncode(body));
      case 'DELETE':
        return http.delete(uri, headers: headers);
      default:
        return http.get(uri, headers: headers);
    }
  }

  static Future<void> registerDevice(String deviceToken, String platform) async {
    try {
      final response = await _authenticatedRequest(
        'POST',
        '/device/register/',
        body: {'device_token': deviceToken, 'platform': platform},
      );

      if (response.statusCode == 201) {
        print('Device registered with Django backend');
      } else {
        print('Failed to register device: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error registering device: $e');
    }
  }

  static Future<void> deleteDevice(String token) async {
    try {
      await _authenticatedRequest('DELETE', '/device/$token/');
    } catch (e) {
      print('Error deleting device: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> listUsers() async {
    try {
      final response = await _authenticatedRequest('GET', '/users/');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      print('Error listing users: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> createRoom(String name, List<String> memberEmails) async {
    try {
      final response = await _authenticatedRequest(
        'POST',
        '/rooms/create/',
        body: {'name': name, 'members': memberEmails},
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error creating room: $e');
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> listRooms() async {
    try {
      final response = await _authenticatedRequest('GET', '/rooms/');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      print('Error listing rooms: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getRoom(String roomId) async {
    try {
      final response = await _authenticatedRequest('GET', '/rooms/$roomId/');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error getting room: $e');
    }
    return null;
  }

  static Future<void> joinRoom(String roomId) async {
    try {
      await _authenticatedRequest('POST', '/rooms/$roomId/join/');
    } catch (e) {
      print('Error joining room: $e');
    }
  }

  /// Muzzomo AI chat is open to unauthenticated use — no auth token required.
  static Future<Map<String, dynamic>?> askMuzzomoAi({
    required String question,
    int? conversationId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$djangoBaseUrl/muzzomo-ai/ask/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'question': question,
          'conversation_id': conversationId,
        }),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      print('Failed to get Muzzomo AI answer: ${response.statusCode} ${response.body}');
    } catch (e) {
      print('Error asking Muzzomo AI: $e');
    }
    return null;
  }

  static Future<void> sendChatNotification({
    required String roomId,
    required String messageText,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final senderName = user?.email ?? 'Unknown';

      final response = await _authenticatedRequest(
        'POST',
        '/notification/chat/',
        body: {
          'room_id': roomId,
          'sender_name': senderName,
          'message': messageText,
          'chat_id': roomId,
        },
      );

      if (response.statusCode == 200) {
        print('Chat notification sent');
      } else {
        print('Failed to send chat notification: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error sending chat notification: $e');
    }
  }
}
