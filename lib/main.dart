import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register background handler BEFORE initializing Firebase
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    } catch (_) {
      // ignore other initialization errors in dev
    }
  }

  // Must be called exactly once, and awaited, before any other GoogleSignIn
  // method is used.
  //
  // قبل از تست Google Sign-In روی اندروید، این کارها را در Firebase Console
  // انجام بده، وگرنه ورود با گوگل با خطای ApiException: 10 شکست می‌خورد:
  //
  // ۱. Firebase Console → Project settings → پروژه‌ات → بخش "Your apps" →
  //    اپ اندروید (com.example.chat_app) → "Add fingerprint"
  //
  // ۲. این دو مقدار را که از debug.keystore این دستگاه استخراج شده اضافه کن:
  //    SHA-1:   BB:3F:AB:1D:A9:37:3E:E9:93:7D:D7:49:EC:7C:37:0C:1E:54:E1:27
  //    SHA-256: 89:DF:C3:9E:92:80:54:FF:81:DE:96:9C:21:84:E0:ED:7E:54:28:8B:43:A5:D0:7B:01:54:B7:55:00:96:70:FC
  //
  //    (این مقادیر مخصوص debug.keystore خود این کامپیوتر است — روی هر
  //    دستگاه/کامپیوتر دیگری که پروژه را build می‌کنی، یا هنگام ساخت
  //    APK/AAB نهایی release با keystore واقعی، باید SHA جدید همان
  //    keystore را هم جداگانه اضافه کنی.)
  //
  // ۳. بعد از اضافه کردن fingerprint، فایل google-services.json را از همان
  //    صفحه دوباره دانلود کن و جایگزین android/app/google-services.json کن
  //    (چون این فایل حاوی OAuth client مربوط به SHA است و باید آپدیت شود).
  //
  // ۴. در Firebase Console → Authentication → Sign-in method → Google را
  //    فعال (Enable) کن — بدون این مرحله، حتی با SHA درست، ورود با گوگل رد
  //    می‌شود.
  await GoogleSignIn.instance.initialize();

  runApp(const MyApp());
}
