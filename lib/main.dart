import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemax_seat_booking/app.dart';
import 'package:cinemax_seat_booking/core/services/notification_service.dart';
import 'package:cinemax_seat_booking/presentation/views/bookings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // Enable offline persistence (helps with transient "unavailable" errors on emulators/network)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await NotificationService().init();

  runApp(
    const ProviderScope(
      child: CinemaxApp(),
    ),
  );

  // If the app was opened by tapping a booking notification, navigate to Bookings.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final launchedFromNotif =
        await NotificationService().wasLaunchedFromNotification();
    if (launchedFromNotif) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const BookingsScreen()),
      );
    }
  });
}
