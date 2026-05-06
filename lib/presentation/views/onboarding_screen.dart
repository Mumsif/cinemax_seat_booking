import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cinemax_seat_booking/core/theme/app_theme.dart';
import 'login_screen.dart';


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  void _goToNext() {
    if (_currentPage < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary, AppTheme.surface],
            begin: Alignment.topLeft,
            end: Alignment.center,
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16, top: 8),
                  child: TextButton(
                    onPressed: _navigateToLogin,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),

              // Pages
              Expanded(
                child: PageView(
                  controller: _controller,
                  scrollBehavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  children: const [
                    _Page1(),
                    _Page2(),
                    _Page3(),
                  ],
                ),
              ),

              // Bottom nav: dots + Next/Get Started button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dot indicators
                    Row(
                      children: List.generate(3, (index) {
                        return GestureDetector(
                          onTap: () {
                            _controller.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            width: _currentPage == index ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? AppTheme.primary
                                  : AppTheme.textMuted,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),

                    GestureDetector(
                      onTap: _goToNext,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: EdgeInsets.symmetric(
                          horizontal: _currentPage == 2 ? 28 : 32,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          _currentPage == 2 ? 'Get Started' : 'Next',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// Page 1 

class _Page1 extends StatelessWidget {
  const _Page1();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _image('johnwick.jpg', screenWidth * 0.24, screenWidth * 0.36),
              _image('spiderman.jpg', screenWidth * 0.30, screenWidth * 0.46),
              _image('batman.jpg', screenWidth * 0.24, screenWidth * 0.36),
            ],
          ),
          const SizedBox(height: 48),
          const Text(
            "Discover Movies\n& Theaters",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Discover Movies and diverse\ntheaters booking",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _image(String name, double width, double height) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/images/onboarding/$name',
        width: width,
        height: height,
        fit: BoxFit.cover,
      ),
    );
  }
}

// Page 2

class _Page2 extends StatelessWidget {
  const _Page2();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boxSize = screenWidth * 0.65 > 260.0 ? 260.0 : screenWidth * 0.65;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          SizedBox(
            width: boxSize,
            height: boxSize,
            child: FittedBox(
              fit: BoxFit.contain,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 170,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5E5351),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        _seatRow([Colors.grey, Colors.red, null, Colors.grey, Colors.grey]),
                        _seatRow([Colors.red, Colors.red, Colors.amber, null, Colors.grey, Colors.red, Colors.amber]),
                        _seatRow([Colors.grey, Colors.red, Colors.amber, null, Colors.red, Colors.red, Colors.red]),
                        _seatRow([Colors.red, Colors.red, Colors.red, null, Colors.amber, Colors.amber, Colors.red]),
                        _seatRow([Colors.amber, Colors.amber, Colors.grey, null, Colors.red, Colors.amber, Colors.grey]),
                        const SizedBox(height: 12),
                        _seatRow(List.filled(8, Colors.grey)),
                        const SizedBox(height: 6),
                        _seatRow(List.filled(8, Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 44),
          const Text(
            "Choose Showtimes\n& Seats",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Premium seat map and time picker",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _seatRow(List<Color?> seats) {
    List<Widget> row = [];
    for (int i = 0; i < seats.length; i++) {
      if (seats[i] != null) {
        row.add(_seat(seats[i]!));
        if (i < seats.length - 1 && seats[i + 1] != null) {
          row.add(const SizedBox(width: 5));
        }
      } else {
        row.add(const SizedBox(width: 18));
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(mainAxisSize: MainAxisSize.min, children: row),
    );
  }

  Widget _seat(Color color) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}


// Page 3
class _Page3 extends StatelessWidget {
  const _Page3();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boxWidth = screenWidth * 0.55 > 210.0 ? 210.0 : screenWidth * 0.55;
    final boxHeight = boxWidth * (250 / 210);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          SizedBox(
            width: boxWidth,
            height: boxHeight,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Container(
                width: 210,
                height: 250,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0B781).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/onboarding/qr_ticket.png',
                    width: 150,
                    height: 190,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          const Text(
            "Book Tickets Easily",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Scan your ticket at the cinema gate",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}