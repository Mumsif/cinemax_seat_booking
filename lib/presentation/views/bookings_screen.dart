import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cinemax_seat_booking/presentation/views/qr_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.confirmation_num_outlined,
                color: Colors.grey.withOpacity(0.5),
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Please login to see your bookings',
                style: TextStyle(
                  color: Colors.grey.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Bookings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: StreamBuilder<QuerySnapshot>(
                      // FIX: Query from user's own subcollection (secure)
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user!.uid)
                          .collection('bookings')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final count = snapshot.hasData
                            ? snapshot.data!.docs.length
                            : 0;
                        return Text(
                          '$count Bookings',
                          style: const TextStyle(
                            color: Color(0xFFE50914),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Bookings List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // FIX: Query from user's own subcollection with server-side sort
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('bookings')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE50914),
                      ),
                    );
                  }

                  final bookings = snapshot.data?.docs ?? [];

                  if (bookings.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.confirmation_num_outlined,
                            color: Colors.grey.withOpacity(0.5),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No bookings yet',
                            style: TextStyle(
                              color: Colors.grey.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Book a movie to see it here',
                            style: TextStyle(
                              color: Colors.grey.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: bookings.length,
                    itemBuilder: (context, index) {
                      final ticket = bookings[index].data() as Map<String, dynamic>;
                      final ticketId = bookings[index].id;
                      // FIX: Use createdAt (saved by TicketScreen) instead of bookedAt
                      final createdAt = (ticket['createdAt'] as Timestamp?)?.toDate();

                      return _buildBookingCard(
                        ticket: ticket,
                        ticketId: ticketId,
                        createdAt: createdAt,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard({
    required Map<String, dynamic> ticket,
    required String ticketId,
    required DateTime? createdAt,
  }) {
    // NOTE: isUpcoming currently checks booking time. 
    // For show-time based logic, use selectedDate instead.
    final isUpcoming = createdAt != null &&
        createdAt.isAfter(DateTime.now().subtract(const Duration(hours: 3)));

    final double totalAmount = (ticket['total'] ?? ticket['totalPrice'] ?? 0).toDouble();
    final String showTime = ticket['showTime'] ?? ticket['time'] ?? '-';
    final String dateStr = _formatShowDate(ticket);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QRScreen(
              movieName: ticket['movieName'] ?? 'Unknown',
              cinemaName: ticket['cinemaName'] ?? 'Unknown',
              showTime: showTime,
              movieImageUrl: ticket['movieImageUrl'] ?? '',
              selectedDate: _parseDateTime(ticket['selectedDate']),
              rating: ticket['rating'] ?? '-',
              selectedSeats: List<String>.from(ticket['seats'] ?? []),
              bookingId: ticketId,
              ticketPrice: (ticket['ticketPrice'] ?? 250.0).toDouble(),
              serviceFee: (ticket['serviceFee'] ?? 500.0).toDouble(),
              totalAmount: totalAmount,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUpcoming
                ? const Color(0xFFE50914).withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            // Movie Poster
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                ticket['movieImageUrl'] ?? '',
                width: 70,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 70,
                  height: 100,
                  color: Colors.grey[800],
                  child: const Icon(Icons.movie, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ticket['movieName'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUpcoming)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'UPCOMING',
                            style: TextStyle(
                              color: Color(0xFFE50914),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.grey,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ticket['cinemaName'] ?? '-',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule, color: Colors.grey, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$showTime · $dateStr',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_seat,
                        color: Colors.grey,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(ticket['seats'] as List?)?.length ?? 0} Seats: ${(ticket['seats'] as List?)?.join(', ') ?? '-'}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rs. ${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFFE50914),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        createdAt != null ? _formatDate(createdAt) : '-',
                        style: TextStyle(
                          color: Colors.grey.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatShowDate(Map<String, dynamic> ticket) {
    final rawDate = ticket['selectedDate'] ?? ticket['date'] ?? ticket['displayDate'];
    if (rawDate == null) return '-';
    if (rawDate is String && !rawDate.contains('-') && rawDate.contains('/')) {
      return rawDate;
    }
    return _formatDate(_parseDateTime(rawDate));
  }

  DateTime _parseDateTime(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is Timestamp) return val.toDate();
    if (val is String) {
      final parsed = DateTime.tryParse(val);
      if (parsed != null) return parsed;
      final parts = val.split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    }
    return DateTime.now();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}