import 'package:flutter/material.dart';
import 'package:cinemax_seat_booking/core/theme/app_theme.dart';
import 'package:cinemax_seat_booking/presentation/views/splash_screen.dart';


class CinemaxApp extends StatelessWidget {
  const CinemaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cinemax',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
      
    );
  }
}