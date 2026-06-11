import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingList extends StatelessWidget {
  final String? restrictedCinema;

  const BookingList({super.key, this.restrictedCinema});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final sp = w / 375;

    // Robust check for cinema restriction
    final bool hasRestriction = restrictedCinema != null && 
                                restrictedCinema!.isNotEmpty && 
                                restrictedCinema != 'null' && 
                                restrictedCinema!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(
          hasRestriction ? '$restrictedCinema Bookings' : 'All Bookings', 
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: hasRestriction
            ? FirebaseFirestore.instance
                .collection('tickets')
                .where('cinemaName', isEqualTo: restrictedCinema)
                .snapshots()
            : FirebaseFirestore.instance
                .collection('tickets')
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading bookings:\n${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            );
          }

          final bookings = snapshot.data!.docs.toList();

          // Sort if filtered (Firestore can't sort with where on different field)
          if (hasRestriction) {
            bookings.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['createdAt'] as Timestamp?;
              final bTime = bData['createdAt'] as Timestamp?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });
          }

          if (bookings.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long, color: Colors.grey, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'No bookings found',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 8 * sp),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final data = bookings[index].data() as Map<String, dynamic>;
              final bookingId = data['bookingId'] ?? bookings[index].id;
              final movieName = data['movieName'] ?? 'Unknown Movie';
              final cinemaName = data['cinemaName'] ?? 'Unknown Cinema';
              final seats = data['seats'] is List
                  ? List<String>.from(data['seats'])
                  : <String>[];
              final total = (data['total'] as num?)?.toStringAsFixed(0) ?? '0';
              final date = data['date'] ?? '-';
              final time = data['time'] ?? '-';
              final status = data['status'] ?? 'unknown';
              final userEmail = data['userEmail'] ?? 'guest';

              Color statusColor;
              switch (status) {
                case 'confirmed':
                  statusColor = Colors.green;
                  break;
                case 'used':
                  statusColor = Colors.blue;
                  break;
                case 'cancelled':
                  statusColor = Colors.red;
                  break;
                default:
                  statusColor = Colors.grey;
              }

              return Container(
                margin: EdgeInsets.symmetric(
                  horizontal: 12 * sp,
                  vertical: 6 * sp,
                ),
                padding: EdgeInsets.all(14 * sp),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12 * sp),
                  border: Border.all(
                    color: statusColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            bookingId,
                            style: TextStyle(
                              color: const Color(0xFFD0B781),
                              fontSize: 11 * sp,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10 * sp,
                            vertical: 4 * sp,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6 * sp),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10 * sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10 * sp),

                    Text(
                      movieName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15 * sp,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6 * sp),

                    Text(
                      cinemaName,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12 * sp,
                      ),
                    ),
                    SizedBox(height: 8 * sp),

                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.grey, size: 13 * sp),
                        SizedBox(width: 4 * sp),
                        Text(date, style: TextStyle(color: Colors.white70, fontSize: 12 * sp)),
                        SizedBox(width: 14 * sp),
                        Icon(Icons.access_time, color: Colors.grey, size: 13 * sp),
                        SizedBox(width: 4 * sp),
                        Text(time, style: TextStyle(color: Colors.white70, fontSize: 12 * sp)),
                      ],
                    ),
                    SizedBox(height: 6 * sp),

                    Row(
                      children: [
                        Icon(Icons.event_seat, color: Colors.grey, size: 13 * sp),
                        SizedBox(width: 4 * sp),
                        Expanded(
                          child: Text(
                            seats.isNotEmpty ? seats.join(', ') : 'N/A',
                            style: TextStyle(color: Colors.white70, fontSize: 12 * sp),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6 * sp),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rs. $total',
                          style: TextStyle(
                            color: const Color(0xFFD4AF37),
                            fontSize: 14 * sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            userEmail,
                            style: TextStyle(color: Colors.grey, fontSize: 10 * sp),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10 * sp),

                    if (status == 'confirmed')
                      SizedBox(
                        width: double.infinity,
                        height: 38 * sp,
                        child: ElevatedButton.icon(
                          onPressed: () => _cancelBooking(context, bookingId, data),
                          icon: Icon(Icons.cancel, size: 16 * sp),
                          label: Text(
                            'Cancel Booking',
                            style: TextStyle(
                              fontSize: 12 * sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.15),
                            foregroundColor: Colors.red,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8 * sp),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _cancelBooking(BuildContext context, String bookingId, Map<String, dynamic> ticketData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Cancel Booking', style: TextStyle(color: Colors.white)),
        content: Text(
          'Cancel booking $bookingId?\nThis will free all associated seats.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      final seatDocs = await FirebaseFirestore.instance
          .collection('seatBookings')
          .where('bookingId', isEqualTo: bookingId)
          .get();

      for (final doc in seatDocs.docs) {
        batch.update(doc.reference, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': 'admin',
        });
      }

      batch.update(
        FirebaseFirestore.instance.collection('tickets').doc(bookingId),
        {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        },
      );

      final userId = ticketData['userId'] as String?;
      if (userId != null && userId != 'guest') {
        batch.update(
          FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('bookings')
              .doc(bookingId),
          {
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
          },
        );
      }

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking $bookingId cancelled (${seatDocs.docs.length} seats freed)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}