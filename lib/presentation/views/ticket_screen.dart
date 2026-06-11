import 'package:cinemax_seat_booking/core/theme/app_theme.dart';
import 'package:cinemax_seat_booking/core/services/notification_service.dart';
import 'package:cinemax_seat_booking/presentation/views/qr_screen.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TicketScreen extends StatefulWidget {
  final List<String>? selectedSeats;
  final String movieName;
  final String cinemaName;
  final String showTime;
  final String movieImageUrl;
  final DateTime selectedDate;
  final String rating;

  const TicketScreen({
    super.key,
    this.selectedSeats,
    required this.movieName,
    required this.cinemaName,
    required this.showTime,
    required this.movieImageUrl,
    required this.selectedDate,
    required this.rating,
  });

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  bool _isSaving = false;

  double get _ticketPrice => 250.0;
  double get _serviceFee => 500.0;
  int get _seatCount => widget.selectedSeats?.length ?? 0;
  double get _subtotal => _seatCount * _ticketPrice;
  double get _total => _subtotal + _serviceFee;

  String get _formattedDate {
    final d = widget.selectedDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String get _displayDate {
    final d = widget.selectedDate;
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _confirmAndSaveBooking() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final bookingId = 'BK-${DateTime.now().millisecondsSinceEpoch}';
      final user = FirebaseAuth.instance.currentUser;

      final ticketData = {
        'bookingId': bookingId,
        'userId': user?.uid ?? 'guest',
        'userEmail': user?.email ?? 'guest',
        'movieName': widget.movieName,
        'cinemaName': widget.cinemaName,
        'movieImageUrl': widget.movieImageUrl,
        'rating': widget.rating,
        'date': _formattedDate,
        'displayDate': _displayDate,
        'time': widget.showTime,
        'seats': widget.selectedSeats ?? [],
        'seatCount': _seatCount,
        'ticketPrice': _ticketPrice,
        'subtotal': _subtotal,
        'serviceFee': _serviceFee,
        'total': _total,
        'status': 'confirmed',
        'createdAt': FieldValue.serverTimestamp(),
        'usedAt': null,
        'usedByAdmin': false,
      };

      // Save ticket
      await FirebaseFirestore.instance.collection('tickets').doc(bookingId).set(ticketData);

      // Save seat bookings for real-time tracking
      for (final seat in widget.selectedSeats ?? []) {
        await FirebaseFirestore.instance.collection('seatBookings').doc('${widget.cinemaName}_${widget.showTime}_$seat').set({
          'seatId': seat,
          'cinemaName': widget.cinemaName,
          'showTime': widget.showTime,
          'date': _formattedDate,
          'movieName': widget.movieName,
          'bookingId': bookingId,
          'userId': user?.uid ?? 'guest',
          'status': 'booked',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Save to user's history
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('bookings').doc(bookingId).set(ticketData);
      }

      // ─── SEND BOOKING CONFIRMATION NOTIFICATION ───
      try {
        final notifService = NotificationService();
        await notifService.showNotification(
          id: bookingId.hashCode,
          title: '🎬 Booking Confirmed!',
          body: '${widget.movieName} at ${widget.cinemaName}\n$_displayDate | ${widget.showTime}\nSeats: ${widget.selectedSeats?.join(', ')}',
          payload: bookingId,
        );
      } catch (_) {
        // Notification failed — booking is already saved, continue normally.
      }

      setState(() => _isSaving = false);

      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => QRScreen(
          movieName: widget.movieName,
          cinemaName: widget.cinemaName,
          showTime: widget.showTime,
          movieImageUrl: widget.movieImageUrl,
          selectedDate: widget.selectedDate,
          rating: widget.rating,
          selectedSeats: widget.selectedSeats ?? [],
          bookingId: bookingId,
          ticketPrice: _ticketPrice,
          serviceFee: _serviceFee,
          totalAmount: _total,
        )));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Your Ticket', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 270,
                height: 500,
                decoration: BoxDecoration(
                  image: const DecorationImage(image: AssetImage('assets/images/movies/ticket_image.png'), fit: BoxFit.cover),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Row(children: [
                        const SizedBox(width: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: widget.movieImageUrl,
                            width: 90,
                            height: 130,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(width: 85, height: 120, color: Colors.grey[800], child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)))),
                            errorWidget: (_, __, ___) => Container(width: 85, height: 120, color: Colors.grey[800], child: const Icon(Icons.movie, color: Colors.white54, size: 30)),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.movieName, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 10),
                              Row(children: [const Icon(Icons.star, color: Colors.yellow, size: 15), const SizedBox(width: 5), Text(widget.rating, style: const TextStyle(fontSize: 14, color: Colors.white))]),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 35),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.cinemaName, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Container(height: 1, color: Colors.grey),
                            const SizedBox(height: 10),
                            _buildRow('Date: ', _formattedDate),
                            const SizedBox(height: 10),
                            _buildRow('Time: ', widget.showTime),
                            const SizedBox(height: 10),
                            _buildRow('Seats: ', widget.selectedSeats?.join(', ') ?? 'N/A'),
                            const SizedBox(height: 55),
                            _buildPaymentRow('Selected Seats', '$_seatCount x Rs.${_ticketPrice.toStringAsFixed(0)}'),
                            const SizedBox(height: 8),
                            _buildPaymentRow('Service Charge', 'Rs. ${_serviceFee.toStringAsFixed(0)}'),
                            const SizedBox(height: 18),
                            Container(height: 1, color: Colors.grey),
                            const SizedBox(height: 18),
                            _buildPaymentRow('Total Price', 'Rs. ${_total.toStringAsFixed(0)}', isBold: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 150),
              Container(
                height: 56,
                width: 340,
                decoration: BoxDecoration(color: _isSaving ? Colors.grey : AppTheme.seatSelected, borderRadius: BorderRadius.circular(28)),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _confirmAndSaveBooking,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
                  child: _isSaving
                    ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), SizedBox(width: 12), Text('Saving...', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold))])
                    : const Text('Confirm Booking', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 15, color: Colors.white)),
      Flexible(child: Text(value, style: const TextStyle(fontSize: 14, color: Colors.white), textAlign: TextAlign.end, overflow: TextOverflow.ellipsis, maxLines: 2)),
    ]);
  }

  Widget _buildPaymentRow(String label, String value, {bool isBold = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      Text(value, style: TextStyle(fontSize: isBold ? 14 : 13, color: Colors.white, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
    ]);
  }
}