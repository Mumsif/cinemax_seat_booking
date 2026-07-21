import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cinemax_seat_booking/core/services/notification_service.dart';
import 'package:cinemax_seat_booking/core/utils/ticket_signer.dart';

class QRScreen extends StatefulWidget {
  final String movieName;
  final String cinemaName;
  final String showTime;
  final String movieImageUrl;
  final DateTime selectedDate;
  final String rating;
  final List<String> selectedSeats;
  final String? bookingId;
  final double? ticketPrice;
  final double? serviceFee;
  final double? totalAmount;
  final bool fromBookings;

  const QRScreen({
    super.key,
    required this.movieName,
    required this.cinemaName,
    required this.showTime,
    required this.movieImageUrl,
    required this.selectedDate,
    required this.rating,
    required this.selectedSeats,
    this.bookingId,
    this.ticketPrice,
    this.serviceFee,
    this.totalAmount,
    this.fromBookings = false,
  });

  @override
  State<QRScreen> createState() => _QRTicketScreenState();
}

class _QRTicketScreenState extends State<QRScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _qrKey = GlobalKey();
  bool _isSavingImage = false;
  bool _isSavingPdf = false;
  bool _isCancelling = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String get _formattedDate {
    final d = widget.selectedDate;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String get _qrData {
    // Generate booking ID only as fallback (should normally be provided by caller)
    final bookingId = widget.bookingId ?? 'BK-${DateTime.now().millisecondsSinceEpoch}';
    final signature = TicketSigner.sign(bookingId);
    // Only the signed token is encoded in the QR (no human readable details).
    // Details are fetched server-side (Firestore) after successful verification.
    return 'CINEMAX_ADMIN:$bookingId.$signature';
  }

  Future<void> _cancelBooking() async {
    if (widget.bookingId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE50914), size: 28),
            SizedBox(width: 12),
            Text('Cancel Booking', style: TextStyle(color: Colors.white, fontSize: 20)),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel this booking?\n\n${widget.movieName}\n${widget.cinemaName}\n${widget.selectedSeats.length} Seats: ${widget.selectedSeats.join(', ')}',
          style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Booking', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      // Get notification IDs before deleting
      final ticketDoc = await FirebaseFirestore.instance.collection('tickets').doc(widget.bookingId).get();
      final ticketData = ticketDoc.data();
      final List<dynamic>? notificationIds = ticketData?['notificationIds'];

      // Cancel scheduled notifications
      if (notificationIds != null) {
        final notifService = NotificationService();
        for (final id in notificationIds) {
          if (id is int) {
            await notifService.cancelNotification(id);
          }
        }
      }

      // Delete ticket
      await FirebaseFirestore.instance.collection('tickets').doc(widget.bookingId).delete();

      // Delete seat bookings
      for (final seat in widget.selectedSeats) {
        await FirebaseFirestore.instance
            .collection('seatBookings')
            .doc('${widget.cinemaName}_${widget.showTime}_$seat')
            .delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<Uint8List?> _captureQR() async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing QR: $e');
      return null;
    }
  }

  Future<Directory> _getSaveDirectory() async {
    if (Platform.isAndroid) {
      // Try public Downloads folder first (visible to user)
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) {
        return publicDownload;
      }
      // Fallback to app-specific external storage
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final appDownload = Directory('${extDir.path}/Cinemax');
        if (!await appDownload.exists()) {
          await appDownload.create(recursive: true);
        }
        return appDownload;
      }
    }
    // iOS or other: use documents
    return await getApplicationDocumentsDirectory();
  }

  Future<void> _saveAsImage() async {
    setState(() => _isSavingImage = true);
    try {
      final pngBytes = await _captureQR();
      if (pngBytes == null) throw Exception('Failed to capture QR');

      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied')),
          );
          return;
        }
      }

      final directory = await _getSaveDirectory();
      final fileName = 'Cinemax_Ticket_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to ${directory.path}/$fileName')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving image: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSavingImage = false);
    }
  }

  Future<void> _saveAsPDF() async {
    setState(() => _isSavingPdf = true);
    try {
      final pngBytes = await _captureQR();
      if (pngBytes == null) throw Exception('Failed to capture QR');

      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied')),
          );
          return;
        }
      }

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('CINEMAX TICKET', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Image(pw.MemoryImage(pngBytes), width: 250, height: 250),
                pw.SizedBox(height: 20),
                pw.Text(widget.movieName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('${widget.cinemaName} | $_formattedDate | ${widget.showTime}'),
                pw.SizedBox(height: 10),
                pw.Text('Seats: ${widget.selectedSeats.join(', ')}'),
                pw.SizedBox(height: 30),
                pw.Text('Present this QR at cinema entrance', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
              ],
            ),
          ),
        ),
      );

      final directory = await _getSaveDirectory();
      final fileName = 'Cinemax_Ticket_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to ${directory.path}/$fileName')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSavingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final sp = w / 375;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Your Ticket', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20 * sp),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16 * sp),
                border: Border.all(color: const Color(0xFFD0B781).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16 * sp),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10 * sp),
                          child: Image.network(
                            widget.movieImageUrl,
                            width: 80 * sp,
                            height: 110 * sp,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80 * sp,
                              height: 110 * sp,
                              color: Colors.grey[800],
                              child: const Icon(Icons.error, color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(width: 14 * sp),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.movieName,
                                style: TextStyle(color: Colors.white, fontSize: 17 * sp, fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 6 * sp),
                              Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber, size: 14 * sp),
                                  SizedBox(width: 4 * sp),
                                  Text(widget.rating, style: TextStyle(color: Colors.white, fontSize: 13 * sp)),
                                ],
                              ),
                              SizedBox(height: 6 * sp),
                              Text(widget.cinemaName, style: TextStyle(color: Colors.grey, fontSize: 12 * sp)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildDashedDivider(sp),
                  Padding(
                    padding: EdgeInsets.all(16 * sp),
                    child: Column(
                      children: [
                        _row('Date', _formattedDate, sp),
                        SizedBox(height: 10 * sp),
                        _row('Time', widget.showTime, sp),
                        SizedBox(height: 10 * sp),
                        _row('Seats', widget.selectedSeats.join(', '), sp),
                        SizedBox(height: 10 * sp),
                        _row('Quantity', '${widget.selectedSeats.length} Tickets', sp),
                      ],
                    ),
                  ),
                  _buildDashedDivider(sp),
                  Padding(
                    padding: EdgeInsets.all(16 * sp),
                    child: Column(
                      children: [
                        _row('Ticket Price', 'LKR ${(widget.ticketPrice ?? 250.0).toStringAsFixed(2)} x ${widget.selectedSeats.length}', sp),
                        SizedBox(height: 8 * sp),
                        _row('Service Charge', 'LKR ${(widget.serviceFee ?? 500.0).toStringAsFixed(2)}', sp),
                        SizedBox(height: 12 * sp),
                        Container(height: 1, color: Colors.grey.withOpacity(0.3)),
                        SizedBox(height: 12 * sp),
                        _row('Total Price', 'LKR ${(widget.totalAmount ?? 0).toStringAsFixed(2)}', sp, isBold: true),
                      ],
                    ),
                  ),
                  _buildDashedDivider(sp),
                  Padding(
                    padding: EdgeInsets.all(24 * sp),
                    child: Column(
                      children: [
                        Text('Scan at Cinema Entrance', style: TextStyle(color: Colors.grey, fontSize: 13 * sp)),
                        SizedBox(height: 16 * sp),
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            padding: EdgeInsets.all(12 * sp),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12 * sp),
                            ),
                            child: RepaintBoundary(
                              key: _qrKey,
                              child: QrImageView(
                                data: _qrData,
                                size: 180 * sp,
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                errorCorrectionLevel: QrErrorCorrectLevel.H,
                              ),
                            ),
                          ),
                        ),
                        // No plain-text Booking ID is shown below the QR (removed to prevent leakage).
                        // The QR encodes *only* the secure token `CINEMAX_ADMIN:$bookingId.$signature`.
                        // Human-readable details (incl. any booking reference) come from Firestore after signature verification.
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24 * sp),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSavingImage ? null : _saveAsImage,
                    icon: _isSavingImage
                        ? SizedBox(width: 16 * sp, height: 16 * sp, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : const Icon(Icons.image, size: 18),
                    label: Text('Save Image', style: TextStyle(fontSize: 13 * sp)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14 * sp),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * sp)),
                    ),
                  ),
                ),
                SizedBox(width: 12 * sp),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSavingPdf ? null : _saveAsPDF,
                    icon: _isSavingPdf
                        ? SizedBox(width: 16 * sp, height: 16 * sp, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : const Icon(Icons.picture_as_pdf, size: 18),
                    label: Text('Save PDF', style: TextStyle(fontSize: 13 * sp)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14 * sp),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * sp)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12 * sp),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final pngBytes = await _captureQR();
                  if (pngBytes != null) {
                    final tempDir = await getTemporaryDirectory();
                    final file = File('${tempDir.path}/ticket_qr.png');
                    await file.writeAsBytes(pngBytes);
                    await Share.shareXFiles([XFile(file.path)], text: 'My Cinemax Ticket: ${widget.movieName}');
                  }
                },
                icon: Icon(Icons.share, size: 18 * sp, color: Colors.white),
                label: Text('Share Ticket', style: TextStyle(fontSize: 14 * sp, color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.withOpacity(0.5)),
                  padding: EdgeInsets.symmetric(vertical: 14 * sp),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * sp)),
                ),
              ),
            ),
            SizedBox(height: 12 * sp),
            SizedBox(
              width: double.infinity,
              child: widget.fromBookings
                  ? ElevatedButton.icon(
                      onPressed: _isCancelling ? null : _cancelBooking,
                      icon: _isCancelling
                          ? SizedBox(width: 18 * sp, height: 18 * sp, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withOpacity(0.7)))
                          : Icon(Icons.cancel_outlined, size: 20 * sp, color: Colors.white),
                      label: Text(
                        'Cancel Booking',
                        style: TextStyle(fontSize: 15 * sp, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16 * sp),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * sp)),
                        elevation: 0,
                      ),
                    )
                  : TextButton(
                      onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                      child: Text('Back to Home', style: TextStyle(color: Colors.grey, fontSize: 13 * sp)),
                    ),
            ),
            SizedBox(height: 20 * sp),
          ],
        ),
      ),
    );
  }

  Widget _buildDashedDivider(double sp) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * sp),
      child: Row(
        children: List.generate(
          20,
          (i) => Expanded(
            child: Container(
              height: 1,
              margin: EdgeInsets.symmetric(horizontal: 2 * sp),
              color: Colors.grey.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, double sp, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 13 * sp)),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13 * sp,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}