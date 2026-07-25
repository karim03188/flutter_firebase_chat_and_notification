import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> onDidReceiveBackgroundNotificationResponse(
  NotificationResponse response,
) async {}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> initialize() async {
    await _requestPermission();
    await _setupLocalNotifications();
    await _setupFCMListeners();
    await _getAndSendToken();
    await _subscribeToTestTopic();
  }

  Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('Notification permission: ${settings.authorizationStatus}');
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationTap(details.payload);
      },
    );

    const androidChannel = AndroidNotificationChannel(
      'chat_messages',
      'Chat Messages',
      description: 'Notifications for new chat messages',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> _setupFCMListeners() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received: ${message.notification?.title}');
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'chat_messages',
            'Chat Messages',
            channelDescription: 'Notifications for new chat messages',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification opened from background: ${message.notification?.title}');
      _handleMessageNavigation(message.data);
    });

    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('App opened from terminated via notification: ${initialMessage.notification?.title}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleMessageNavigation(initialMessage.data);
      });
    }
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload);
      _handleMessageNavigation(data);
    } catch (e) {
      print('Error parsing notification payload: $e');
    }
  }

  void _handleMessageNavigation(Map<String, dynamic> data) {
    final type = data['type'];
    if (type == 'chat') {
      final roomId = data['room_id'] ?? '';
      final chatId = data['chat_id'] ?? '';
      print('Navigate to room: $roomId');
    }
  }

  Future<void> _getAndSendToken() async {
    final token = await _firebaseMessaging.getToken();
    print('========================================');
    print('FCM TOKEN (copy this for Firebase Console):');
    print('$token');
    print('========================================');

    if (token != null) {
      await ApiService.registerDevice(token, 'android');
    }

    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      print('FCM Token refreshed: $newToken');
      await ApiService.registerDevice(newToken, 'android');
    });
  }

  Future<void> _subscribeToTestTopic() async {
    await _firebaseMessaging.subscribeToTopic('test');
    print('Subscribed to "test" topic');
  }

  Future<void> deleteTokenFromDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _firebaseMessaging.getToken();
    await _firebaseMessaging.unsubscribeFromTopic('test');

    if (token != null) {
      await ApiService.deleteDevice(token);
    }

    await FirebaseDatabase.instance.ref('fcm_tokens/${user.uid}').remove();
    ApiService.logout();
  }
}
