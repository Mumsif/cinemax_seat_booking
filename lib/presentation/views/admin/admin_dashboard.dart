import 'package:cinemax_seat_booking/presentation/views/admin/movie_manager.dart';
import 'package:flutter/material.dart';
import 'daily_report_screen.dart';
import 'seat_manager.dart';
import 'booking_list.dart';
import 'ticket_scanner.dart';

class AdminDashboard extends StatefulWidget {
  final String? restrictedCinema;

  const AdminDashboard({super.key, this.restrictedCinema});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late final bool _isSuperAdmin;
  late final String? _resolvedCinema;

  @override
  void initState() {
    super.initState();

    // Use widget parameter only (set during login)
    final param = widget.restrictedCinema;

    if (param != null && param.isNotEmpty && param != 'null') {
      _isSuperAdmin = false;
      _resolvedCinema = param;
    } else {
      _isSuperAdmin = true;
      _resolvedCinema = null;
    }

    print(
      'AdminDashboard init:'
      '\n  widget.restrictedCinema = "${widget.restrictedCinema}"'
      '\n  → _isSuperAdmin = $_isSuperAdmin'
      '\n  → _resolvedCinema = $_resolvedCinema',
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final sp = w / 375;

    final String appBarTitle = _isSuperAdmin
        ? 'Super Admin Panel'
        : '${_resolvedCinema} Admin';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(appBarTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            tooltip: 'Scan Ticket',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TicketScanner()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16 * sp),
        child: Column(
          children: [
            // ── Manage Seats ─────────────────────────────────────────────
            _buildCard(
              icon: Icons.event_seat,
              title: 'Manage Seats',
              subtitle: _isSuperAdmin
                  ? 'All Cinemas'
                  : _resolvedCinema ?? 'My Cinema',
              color: const Color(0xFFE50914),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AdminSeatManagement(restrictedCinema: _resolvedCinema),
                ),
              ),
              sp: sp,
            ),
            SizedBox(height: 12 * sp),

            // ── Bookings ─────────────────────────────────────────────────
            // ALL admins see this, but cinema admins only see their cinema
            _buildCard(
              icon: Icons.receipt_long,
              title: _isSuperAdmin ? 'All Bookings' : 'My Bookings',
              subtitle: _isSuperAdmin
                  ? 'View all customer bookings'
                  : 'Bookings for ${_resolvedCinema ?? 'my cinema'}',
              color: const Color(0xFFD4AF37),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      BookingList(restrictedCinema: _resolvedCinema),
                ),
              ),
              sp: sp,
            ),
            SizedBox(height: 12 * sp),
            _buildCard(
              icon: Icons.movie,
              title: 'Manage Movies',
              subtitle: _isSuperAdmin
                  ? 'Add / edit all movies'
                  : 'Manage movies for ${_resolvedCinema ?? 'my cinema'}',
              color: const Color(0xFF2563EB),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AdminMovieManager(restrictedCinema: _resolvedCinema),
                ),
              ),
              sp: sp,
            ),
            SizedBox(height: 12 * sp),
            _buildCard(
              icon: Icons.analytics,
              title: 'Daily Report',
              subtitle: _isSuperAdmin
                  ? 'View booking analytics'
                  : 'Booking analytics for ${_resolvedCinema ?? 'my cinema'}',
              color: const Color(0xFF10B981),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DailyReportScreen(restrictedCinema: _resolvedCinema),
                ),
              ),
              sp: sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required double sp,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16 * sp),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12 * sp),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12 * sp),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10 * sp),
              ),
              child: Icon(icon, color: color, size: 28 * sp),
            ),
            SizedBox(width: 16 * sp),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16 * sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4 * sp),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey, fontSize: 12 * sp),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16 * sp),
          ],
        ),
      ),
    );
  }
}
