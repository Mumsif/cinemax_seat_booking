import 'package:flutter/material.dart';
import 'package:cinemax_seat_booking/core/theme/app_theme.dart';
import 'package:cinemax_seat_booking/presentation/views/splash_screen.dart';

/// Global navigator key so that taps on system notifications can navigate
/// even when the app was in background or terminated.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class CinemaxApp extends StatelessWidget {
  const CinemaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cinemax',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      navigatorKey: navigatorKey,
      home: const SplashScreen(),
    );
  }
}