import 'package:flutter/material.dart';
import 'package:cinemax_seat_booking/presentation/views/home_screen.dart';
import 'package:cinemax_seat_booking/presentation/views/search_screen.dart';
import 'package:cinemax_seat_booking/presentation/views/bookings_screen.dart';
import 'package:cinemax_seat_booking/presentation/views/account_screen.dart';

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

const _navItems = [
  _NavItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Home',
  ),
  _NavItem(
    icon: Icons.search_rounded,
    activeIcon: Icons.search_rounded,
    label: 'Search',
  ),
  _NavItem(
    icon: Icons.confirmation_num_outlined,
    activeIcon: Icons.confirmation_num_rounded,
    label: 'Bookings',
  ),
  _NavItem(
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    label: 'Profile',
  ),
];

class MainNavBar extends StatefulWidget {
  const MainNavBar({super.key});

  @override
  State<MainNavBar> createState() => _MainNavBarState();
}

class _MainNavBarState extends State<MainNavBar> with TickerProviderStateMixin {
  int _selectedIndex = 0;

  late final List<AnimationController> _iconControllers;
  late final List<Animation<double>> _bounceAnims;

  late final AnimationController _pageTransCtrl;
  late final Animation<double> _pageFade;
  late final Animation<Offset> _pageSlide;

  static const _accent = Color(0xFFE50914);
  static const _surface = Color(0xFF1A1A1A);
  static const _bg = Color(0xFF0F0F0F);

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = [
      const HomeScreen(),
      const SearchScreen(),
      const BookingsScreen(),
      const AccountScreen(),
    ];

    _iconControllers = List.generate(
      4,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );

    _bounceAnims = _iconControllers.map((ctrl) {
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.35)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.35, end: 0.88)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 0.88, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 30,
        ),
      ]).animate(ctrl);
    }).toList();

    _pageTransCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _pageFade = CurvedAnimation(
      parent: _pageTransCtrl,
      curve: Curves.easeOut,
    );
    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _pageTransCtrl, curve: Curves.easeOutCubic),
    );

    _iconControllers[0].forward();
    _pageTransCtrl.forward();
  }

  @override
  void dispose() {
    for (final c in _iconControllers) {
      c.dispose();
    }
    _pageTransCtrl.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    if (_iconControllers[_selectedIndex].status == AnimationStatus.completed) {
      _iconControllers[_selectedIndex].reverse();
    }

    setState(() {
      _selectedIndex = index;
    });

    _iconControllers[index].forward(from: 0);
    _pageTransCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _pageFade,
        child: SlideTransition(
          position: _pageSlide,
          child: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
        ),
      ),
      bottomNavigationBar: _NavBar(
        selectedIndex: _selectedIndex,
        navItems: _navItems,
        bounceAnims: _bounceAnims,
        iconControllers: _iconControllers,
        onTap: _onItemTapped,
        accent: _accent,
        surface: _surface,
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> navItems;
  final List<Animation<double>> bounceAnims;
  final List<AnimationController> iconControllers;
  final ValueChanged<int> onTap;
  final Color accent;
  final Color surface;

  const _NavBar({
    required this.selectedIndex,
    required this.navItems,
    required this.bounceAnims,
    required this.iconControllers,
    required this.onTap,
    required this.accent,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.07),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (i) {
              return _NavTile(
                item: navItems[i],
                isSelected: selectedIndex == i,
                bounceAnim: bounceAnims[i],
                iconController: iconControllers[i],
                accent: accent,
                onTap: () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final Animation<double> bounceAnim;
  final AnimationController iconController;
  final Color accent;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.isSelected,
    required this.bounceAnim,
    required this.iconController,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: bounceAnim,
              builder: (context, _) {
                final scale = isSelected && iconController.status == AnimationStatus.forward
                    ? bounceAnim.value
                    : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Icon(
                    isSelected ? item.activeIcon : item.icon,
                    color: isSelected ? accent : Colors.white38,
                    size: 24,
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? accent : Colors.white30,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: isSelected ? 0.3 : 0,
              ),
              child: Text(item.label),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: isSelected ? 4 : 0,
              height: isSelected ? 4 : 0,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}