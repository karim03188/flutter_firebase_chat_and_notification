import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';

class ApiService {
  static String? _accessToken;
  static String? _refreshToken;

  static bool get isAuthenticated => _accessToken != null;

  static Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$djangoBaseUrl/token/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access'];
      _refreshToken = data['refresh'];
    } else if (response.statusCode == 401) {
      await _register(email, password);
    } else {
      throw Exception('Failed to authenticate with backend');
    }
  }

  static Future<void> _register(String email, String password) async {
    final response = await http.post(
      Uri.parse('$djangoBaseUrl/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      await login(email, password);
    } else {
      throw Exception('Failed to register with backend');
    }
  }

  static Future<void> refreshAccessToken() async {
    if (_refreshToken == null) return;

    final response = await http.post(
      Uri.parse('$djangoBaseUrl/token/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': _refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access'];
    }
  }

  static Future<http.Response> _authenticatedRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated');

    final uri = Uri.parse('$djangoBaseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };

    http.Response response;

    switch (method) {
      case 'POST':
        response = await http.post(uri, headers: headers, body: jsonEncode(body));
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        response = await http.get(uri, headers: headers);
    }

    if (response.statusCode == 401) {
      await refreshAccessToken();
      headers['Authorization'] = 'Bearer $_accessToken';

      switch (method) {
        case 'POST':
          response = await http.post(uri, headers: headers, body: jsonEncode(body));
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
          break;
        default:
          response = await http.get(uri, headers: headers);
      }
    }

    return response;
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

  static void logout() {
    _accessToken = null;
    _refreshToken = null;
  }
}
