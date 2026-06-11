import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cinemax_seat_booking/core/theme/app_theme.dart';
import 'login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding data model
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingData {
  final String title;
  final String subtitle;
  final String tag; // small eyebrow label
  const _OnboardingData({
    required this.title,
    required this.subtitle,
    required this.tag,
  });
}

const _pages = [
  _OnboardingData(
    tag: 'DISCOVER',
    title: 'Movies &\nTheaters',
    subtitle: 'Explore thousands of films and\nfind cinemas near you instantly.',
  ),
  _OnboardingData(
    tag: 'RESERVE',
    title: 'Pick Your\nPerfect Seat',
    subtitle: 'Real-time seat maps with premium\nand standard section filters.',
  ),
  _OnboardingData(
    tag: 'ENJOY',
    title: 'Your Ticket,\nInstantly',
    subtitle: 'Scan your QR code at the gate —\nno printing, no hassle.',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Per-page animation controller (resets on page change)
  late AnimationController _pageEnterCtrl;
  late Animation<double> _pageFade;
  late Animation<Offset> _pageSlide;
  late Animation<double> _pageScale;

  // Button press controller
  late AnimationController _btnPressCtrl;
  late Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();

    _pageEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pageFade = CurvedAnimation(parent: _pageEnterCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _pageEnterCtrl, curve: Curves.easeOutCubic));
    _pageScale = Tween<double>(begin: 0.94, end: 1.0).animate(
        CurvedAnimation(parent: _pageEnterCtrl, curve: Curves.easeOutCubic));

    _btnPressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _btnScale = Tween<double>(begin: 1.0, end: 0.93).animate(
        CurvedAnimation(parent: _btnPressCtrl, curve: Curves.easeInOut));

    _pageEnterCtrl.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageEnterCtrl.dispose();
    _btnPressCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _pageEnterCtrl.forward(from: 0);
  }

  void _goToNext() async {
    await _btnPressCtrl.forward();
    _btnPressCtrl.reverse();

    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary, AppTheme.surface],
            begin: Alignment.topLeft,
            end: Alignment.center,
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // ── Subtle background glow orb ─────────────────────────────
              Positioned(
                top: -size.height * 0.1,
                right: -size.width * 0.2,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  width: size.width * 0.8,
                  height: size.width * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.accent.withOpacity(
                            _currentPage == 0 ? 0.12 : _currentPage == 1 ? 0.09 : 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Column(
                children: [
                  // ── Top bar ────────────────────────────────────────────
                  _TopBar(
                    currentPage: _currentPage,
                    onSkip: _navigateToLogin,
                  ),

                  // ── PageView ───────────────────────────────────────────
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      scrollBehavior:
                          ScrollConfiguration.of(context).copyWith(
                        dragDevices: {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.trackpad,
                        },
                      ),
                      onPageChanged: _onPageChanged,
                      children: [
                        _PageContent(
                          data: _pages[0],
                          visual: _Page1Visual(
                            enterCtrl: _currentPage == 0
                                ? _pageEnterCtrl
                                : AnimationController(vsync: this)
                                  ..value = 1,
                            scale: _pageScale,
                          ),
                          fadeAnim: _currentPage == 0 ? _pageFade : const AlwaysStoppedAnimation(1),
                          slideAnim: _currentPage == 0
                              ? _pageSlide
                              : const AlwaysStoppedAnimation(Offset.zero),
                        ),
                        _PageContent(
                          data: _pages[1],
                          visual: _Page2Visual(
                            enterCtrl: _currentPage == 1
                                ? _pageEnterCtrl
                                : AnimationController(vsync: this)
                                  ..value = 1,
                            scale: _pageScale,
                          ),
                          fadeAnim: _currentPage == 1 ? _pageFade : const AlwaysStoppedAnimation(1),
                          slideAnim: _currentPage == 1
                              ? _pageSlide
                              : const AlwaysStoppedAnimation(Offset.zero),
                        ),
                        _PageContent(
                          data: _pages[2],
                          visual: _Page3Visual(
                            enterCtrl: _currentPage == 2
                                ? _pageEnterCtrl
                                : AnimationController(vsync: this)
                                  ..value = 1,
                            scale: _pageScale,
                          ),
                          fadeAnim: _currentPage == 2 ? _pageFade : const AlwaysStoppedAnimation(1),
                          slideAnim: _currentPage == 2
                              ? _pageSlide
                              : const AlwaysStoppedAnimation(Offset.zero),
                        ),
                      ],
                    ),
                  ),

                  // ── Bottom controls ────────────────────────────────────
                  _BottomBar(
                    currentPage: _currentPage,
                    btnScale: _btnScale,
                    onDotTap: (i) => _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOutCubic,
                    ),
                    onNext: _goToNext,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int currentPage;
  final VoidCallback onSkip;

  const _TopBar({required this.currentPage, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand mark
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
              children: [
                TextSpan(
                    text: 'Cine',
                    style: TextStyle(color: AppTheme.accent)),
                TextSpan(
                    text: 'max',
                    style: TextStyle(color: AppTheme.textPrimary)),
              ],
            ),
          ),

          // Skip button (hidden on last page)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: currentPage < 2 ? 1.0 : 0.0,
            child: TextButton(
              onPressed: currentPage < 2 ? onSkip : null,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                      color: Colors.white.withOpacity(0.15), width: 1),
                ),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page content wrapper (text block with animations)
// ─────────────────────────────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final _OnboardingData data;
  final Widget visual;
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;

  const _PageContent({
    required this.data,
    required this.visual,
    required this.fadeAnim,
    required this.slideAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Visual area
          Expanded(flex: 5, child: visual),

          const SizedBox(height: 28),

          // Text block — staggered fade+slide
          Expanded(
            flex: 3,
            child: FadeTransition(
              opacity: fadeAnim,
              child: SlideTransition(
                position: slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Eyebrow tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.accent.withOpacity(0.3),
                            width: 1),
                      ),
                      child: Text(
                        data.tag,
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title
                    Text(
                      data.title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      data.subtitle,
                      style: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.65),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom bar (dots + button)
// ─────────────────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int currentPage;
  final Animation<double> btnScale;
  final ValueChanged<int> onDotTap;
  final VoidCallback onNext;

  const _BottomBar({
    required this.currentPage,
    required this.btnScale,
    required this.onDotTap,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentPage == 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Dot indicators
          Row(
            children: List.generate(3, (i) {
              final active = i == currentPage;
              return GestureDetector(
                onTap: () => onDotTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  margin: const EdgeInsets.only(right: 7),
                  width: active ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.accent
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),

          // Next / Get Started button
          ScaleTransition(
            scale: btnScale,
            child: GestureDetector(
              onTap: onNext,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                height: 52,
                padding: EdgeInsets.symmetric(
                  horizontal: isLast ? 28 : 20,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: Text(
                        isLast ? 'Get Started' : 'Next',
                        key: ValueKey(isLast),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 350),
                      turns: isLast ? 0.125 : 0, // 45° for last page
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 1 Visual — Three movie posters with staggered float-in
// ─────────────────────────────────────────────────────────────────────────────

class _Page1Visual extends StatefulWidget {
  final AnimationController enterCtrl;
  final Animation<double> scale;

  const _Page1Visual({required this.enterCtrl, required this.scale});

  @override
  State<_Page1Visual> createState() => _Page1VisualState();
}

class _Page1VisualState extends State<_Page1Visual> {
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return ScaleTransition(
      scale: widget.scale,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _AnimatedPoster(
            name: 'johnwick.jpg',
            width: w * 0.22,
            height: w * 0.33,
            delay: 0.0,
            ctrl: widget.enterCtrl,
          ),
          _AnimatedPoster(
            name: 'spiderman.jpg',
            width: w * 0.28,
            height: w * 0.44,
            delay: 0.1,
            ctrl: widget.enterCtrl,
            elevated: true,
          ),
          _AnimatedPoster(
            name: 'batman.jpg',
            width: w * 0.22,
            height: w * 0.33,
            delay: 0.2,
            ctrl: widget.enterCtrl,
          ),
        ],
      ),
    );
  }
}

class _AnimatedPoster extends StatelessWidget {
  final String name;
  final double width;
  final double height;
  final double delay;
  final AnimationController ctrl;
  final bool elevated;

  const _AnimatedPoster({
    required this.name,
    required this.width,
    required this.height,
    required this.delay,
    required this.ctrl,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: ctrl,
      curve: Interval(delay, delay + 0.7, curve: Curves.easeOut),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: ctrl,
      curve: Interval(delay, delay + 0.7, curve: Curves.easeOutBack),
    ));

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(elevated ? 0.5 : 0.3),
                blurRadius: elevated ? 24 : 12,
                offset: Offset(0, elevated ? 12 : 6),
              ),
              if (elevated)
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/onboarding/$name',
                  fit: BoxFit.cover,
                ),
                // Gradient overlay at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: height * 0.35,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Accent border for elevated poster
                if (elevated)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.accent.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 2 Visual — Seat map with glass morphism + animated seat reveals
// ─────────────────────────────────────────────────────────────────────────────

class _Page2Visual extends StatefulWidget {
  final AnimationController enterCtrl;
  final Animation<double> scale;

  const _Page2Visual({required this.enterCtrl, required this.scale});

  @override
  State<_Page2Visual> createState() => _Page2VisualState();
}

class _Page2VisualState extends State<_Page2Visual>
    with SingleTickerProviderStateMixin {
  late AnimationController _seatCtrl;

  @override
  void initState() {
    super.initState();
    _seatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    widget.enterCtrl.addStatusListener((status) {
      if (status == AnimationStatus.forward) {
        _seatCtrl.forward(from: 0);
      }
    });
    if (widget.enterCtrl.isAnimating || widget.enterCtrl.isCompleted) {
      _seatCtrl.forward();
    }
  }

  @override
  void dispose() {
    _seatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final boxSize = (w * 0.72).clamp(0.0, 290.0);

    return ScaleTransition(
      scale: widget.scale,
      child: FadeTransition(
        opacity: CurvedAnimation(
            parent: widget.enterCtrl, curve: Curves.easeOut),
        child: Center(
          child: Container(
            width: boxSize,
            height: boxSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withOpacity(0.12), width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.1),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Screen label
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          children: [
                            Container(
                              width: boxSize * 0.62,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.15),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'SCREEN',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 9,
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Seat rows
                      ..._buildSeatRows(_seatCtrl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _seatData = [
    [Colors.grey, Colors.red, null, Colors.grey, Colors.grey],
    [Colors.red, Colors.red, Colors.amber, null, Colors.grey, Colors.red, Colors.amber],
    [Colors.grey, Colors.red, Colors.amber, null, Colors.red, Colors.red, Colors.red],
    [Colors.red, Colors.red, Colors.red, null, Colors.amber, Colors.amber, Colors.red],
    [Colors.amber, Colors.amber, Colors.grey, null, Colors.red, Colors.amber, Colors.grey],
    [null, null, null, null, null, null, null, null], // spacer
    [Colors.grey, Colors.grey, Colors.grey, null, Colors.grey, Colors.grey, Colors.grey, Colors.grey],
    [Colors.grey, Colors.grey, Colors.grey, null, Colors.grey, Colors.grey, Colors.grey, Colors.grey],
  ];

  List<Widget> _buildSeatRows(AnimationController ctrl) {
    return List.generate(_seatData.length, (rowIndex) {
      final delay = rowIndex * 0.08;
      final rowAnim = CurvedAnimation(
        parent: ctrl,
        curve: Interval(delay, (delay + 0.4).clamp(0, 1), curve: Curves.easeOut),
      );
      final slideAnim = Tween<Offset>(
        begin: const Offset(0.15, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: ctrl,
        curve: Interval(delay, (delay + 0.4).clamp(0, 1), curve: Curves.easeOutCubic),
      ));

      return FadeTransition(
        opacity: rowAnim,
        child: SlideTransition(
          position: slideAnim,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _buildSeats(_seatData[rowIndex]),
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _buildSeats(List<Color?> seats) {
    List<Widget> widgets = [];
    for (int i = 0; i < seats.length; i++) {
      if (seats[i] != null) {
        widgets.add(_Seat(color: seats[i]!));
        if (i < seats.length - 1 && seats[i + 1] != null) {
          widgets.add(const SizedBox(width: 5));
        }
      } else {
        widgets.add(const SizedBox(width: 14));
      }
    }
    return widgets;
  }
}

class _Seat extends StatelessWidget {
  final Color color;
  const _Seat({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(4),
        boxShadow: color == Colors.amber || color == Colors.red
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 3 Visual — QR ticket with shimmer + float animation
// ─────────────────────────────────────────────────────────────────────────────

class _Page3Visual extends StatefulWidget {
  final AnimationController enterCtrl;
  final Animation<double> scale;

  const _Page3Visual({required this.enterCtrl, required this.scale});

  @override
  State<_Page3Visual> createState() => _Page3VisualState();
}

class _Page3VisualState extends State<_Page3Visual>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cardW = (w * 0.58).clamp(0.0, 230.0);
    final cardH = cardW * 1.22;

    return ScaleTransition(
      scale: widget.scale,
      child: FadeTransition(
        opacity: CurvedAnimation(
            parent: widget.enterCtrl, curve: Curves.easeOut),
        child: Center(
          child: AnimatedBuilder(
            animation: _floatAnim,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatAnim.value),
                child: child,
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow backdrop
                Container(
                  width: cardW * 0.9,
                  height: cardH * 0.9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.accent.withOpacity(0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // Ticket card
                Container(
                  width: cardW,
                  height: cardH,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppTheme.accent.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.12),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Top section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CINEMAX',
                                  style: TextStyle(
                                    color: AppTheme.accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'E-Ticket',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Text(
                                '✓ VALID',
                                style: TextStyle(
                                  color: Colors.green.shade300,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Dashed divider
                      _DashedDivider(),
                      // QR code
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/images/onboarding/qr_ticket.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Dashed divider
                      _DashedDivider(),
                      // Seat info row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _TicketInfo(label: 'ROW', value: 'D'),
                            _TicketDot(),
                            _TicketInfo(label: 'SEAT', value: '07'),
                            _TicketDot(),
                            _TicketInfo(label: 'HALL', value: '3'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final count = (constraints.maxWidth / 8).floor();
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                count,
                (_) => Container(
                  width: 4,
                  height: 1,
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
            );
          }),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _TicketInfo extends StatelessWidget {
  final String label;
  final String value;
  const _TicketInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 9,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _TicketDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
    );
  }
}