import 'dart:convert';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  Future<void> initialize() async {
    await _requestPermission();
    await _setupLocalNotifications();
    await _setupFCMListeners();
    await _getAndPrintToken();
    await _subscribeToTestTopic();
  }

  Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    log('Notification permission: ${settings.authorizationStatus}');
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
      onDidReceiveNotificationResponse: (details) {},
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
    // When app is in FOREGROUND - show local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Foreground message received: ${message.notification?.title}');
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

    // When user taps notification while app is in BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('Notification opened from background: ${message.notification?.title}');
    });

    // Check if app opened from a notification (terminated state)
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      log('App opened from terminated via notification: ${initialMessage.notification?.title}');
    }
  }

  // Get FCM token and print it to console for Firebase Console testing
  Future<void> _getAndPrintToken() async {
    final token = await _firebaseMessaging.getToken();
    log('========================================');
    log('FCM TOKEN (copy this for Firebase Console):');
    log('$token');
    log('========================================');

    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      log('FCM Token refreshed: $newToken');
    });
  }

  // Subscribe to "test" topic for easy Firebase Console testing
  Future<void> _subscribeToTestTopic() async {
    await _firebaseMessaging.subscribeToTopic('test');
    log('Subscribed to "test" topic');
  }

  Future<void> deleteTokenFromDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firebaseMessaging.unsubscribeFromTopic('test');
    await FirebaseDatabase.instance.ref('fcm_tokens/${user.uid}').remove();
  }
}
