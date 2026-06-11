import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cinemax_seat_booking/presentation/views/navigation_bar.dart';
import 'package:cinemax_seat_booking/presentation/views/login_screen.dart';
import 'package:cinemax_seat_booking/core/services/admin_service.dart';
import 'package:cinemax_seat_booking/presentation/views/admin/admin_dashboard.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isChecking = true;
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _checkAuthAndRole();
  }

  Future<void> _checkAuthAndRole() async {
    // Small delay for splash feel (can be removed in production)
    await Future.delayed(const Duration(milliseconds: 400));

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _destination = const LoginScreen();
        _isChecking = false;
      });
      return;
    }

    // IMPORTANT: Prevent admins from entering the regular user side.
    // Admins must always use the dedicated Admin panel (bad UX + security separation).
    bool isAdminUser = false;
    try {
      isAdminUser = await AdminService.isAdmin();
    } catch (e) {
      // If we can't reach Firestore (transient emulator issue, network, etc.),
      // fall back to user mode instead of crashing the startup flow.
      print('AuthWrapper: Failed to check admin status: $e. Falling back to user mode.');
      isAdminUser = false;
    }

    if (!mounted) return;

    if (isAdminUser) {
      // Determine restricted cinema for cinema_admins (super admins get null = all cinemas)
      String? restrictedCinema;
      if (AdminService.isCinemaAdmin) {
        restrictedCinema = AdminService.adminCinema;
      }

      setState(() {
        _destination = AdminDashboard(restrictedCinema: restrictedCinema);
        _isChecking = false;
      });
    } else {
      setState(() {
        _destination = const MainNavBar();
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking || _destination == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFE50914)),
        ),
      );
    }

    return _destination!;
  }
}
