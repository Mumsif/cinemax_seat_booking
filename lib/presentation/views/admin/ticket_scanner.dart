import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cinemax_seat_booking/core/utils/ticket_signer.dart';

class TicketScanner extends StatefulWidget {
  const TicketScanner({super.key});

  @override
  State<TicketScanner> createState() => _TicketScannerState();
}

class _TicketScannerState extends State<TicketScanner>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isScanning = true;
  bool _showResult = false;
  bool _isProcessing = false;
  bool _torchOn = false;

  Map<String, dynamic>? _ticketData;
  String? _errorMessage;
  String? _scannedBookingId;

  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _processQR(String qrData) async {
    if (_isProcessing || !_isScanning) return;

    const String secretPrefix = 'CINEMAX_ADMIN';

    if (!qrData.startsWith('$secretPrefix:')) {
      setState(() {
        _errorMessage = 'Invalid QR - Not an official Cinemax ticket';
        _showResult = true;
        _isProcessing = false;
      });
      _animationController.forward();
      return; // Stop processing - reject fake QR
    }

    setState(() {
      _isProcessing = true;
      _isScanning = false;
    });

    try {
      // New secure format (post HMAC signing):
      //   CINEMAX_ADMIN:$bookingId.$signature
      // No human-readable details are embedded; they are looked up from Firestore
      // only after signature verification succeeds.
      final afterPrefix = qrData.substring('$secretPrefix:'.length).trim();

      final dotIndex = afterPrefix.indexOf('.');
      if (dotIndex == -1 || dotIndex == 0 || dotIndex == afterPrefix.length - 1) {
        setState(() {
          _errorMessage = 'Invalid QR format - missing signature';
          _showResult = true;
          _isProcessing = false;
        });
        _animationController.forward();
        return;
      }

      final bookingId = afterPrefix.substring(0, dotIndex);
      final signature = afterPrefix.substring(dotIndex + 1);

      if (bookingId.isEmpty) {
        setState(() {
          _errorMessage = 'Invalid QR - Booking ID not found';
          _showResult = true;
          _isProcessing = false;
        });
        _animationController.forward();
        return;
      }

      // CRITICAL: Verify HMAC-SHA256 signature BEFORE any Firestore access.
      // Recompute signature from bookingId using same secret; reject immediately on mismatch.
      if (!TicketSigner.verify(bookingId, signature)) {
        setState(() {
          _errorMessage = 'Invalid ticket signature - possible forgery. Access denied.';
          _showResult = true;
          _isProcessing = false;
        });
        _animationController.forward();
        return;
      }

      _scannedBookingId = bookingId;

      // Signature OK — safe to proceed to Firestore lookup
      final doc = await FirebaseFirestore.instance
          .collection('tickets')
          .doc(bookingId)
          .get();

      if (!doc.exists) {
        setState(() {
          _errorMessage = 'Ticket not found in database';
          _showResult = true;
          _isProcessing = false;
        });
        _animationController.forward();
        return;
      }

      final data = doc.data()!;
      data['bookingId'] = bookingId;

      // Check ticket status
      final status = data['status'] ?? 'unknown';

      if (status == 'used') {
        final usedAt = data['usedAt']?.toDate();
        final usedTime = usedAt != null
            ? '${usedAt.day}/${usedAt.month}/${usedAt.year} ${usedAt.hour}:${usedAt.minute.toString().padLeft(2, '0')}'
            : 'Unknown time';

        setState(() {
          _errorMessage = 'Ticket already used on $usedTime';
          _ticketData = data;
          _showResult = true;
          _isProcessing = false;
        });
        _animationController.forward();
        return;
      }

      if (status == 'cancelled') {
        setState(() {
          _errorMessage = 'Ticket has been cancelled';
          _ticketData = data;
          _showResult = true;
          _isProcessing = false;
        });
        _animationController.forward();
        return;
      }

      // Valid ticket
      setState(() {
        _ticketData = data;
        _showResult = true;
        _isProcessing = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing ticket: $e';
        _showResult = true;
        _isProcessing = false;
      });
      _animationController.forward();
    }
  }

  Future<void> _markAsUsed() async {
    if (_ticketData == null || _scannedBookingId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(_scannedBookingId)
          .update({
            'status': 'used',
            'usedAt': FieldValue.serverTimestamp(),
            'usedByAdmin': true,
          });

      // Update local data
      setState(() {
        _ticketData!['status'] = 'used';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Ticket marked as USED - Entry confirmed'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _resetScanner() {
    _animationController.reverse().then((_) {
      setState(() {
        _showResult = false;
        _isScanning = true;
        _ticketData = null;
        _errorMessage = null;
        _scannedBookingId = null;
        _isProcessing = false;
      });
    });
  }

  void _toggleTorch() {
    _cameraController.toggleTorch();
    setState(() {
      _torchOn = !_torchOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final sp = w / 375;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          // Camera Scanner
          if (_isScanning) ...[
            MobileScanner(
              controller: _cameraController,
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null &&
                      _isScanning &&
                      !_isProcessing) {
                    _processQR(barcode.rawValue!);
                    break;
                  }
                }
              },
            ),

            // Dark overlay with cutout
            CustomPaint(
              size: Size(w, h),
              painter: ScannerOverlayPainter(
                cutoutSize: 250 * sp,
                borderRadius: 20 * sp,
              ),
            ),

            // Scanner frame
            Center(
              child: Container(
                width: 250 * sp,
                height: 250 * sp,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20 * sp),
                  border: Border.all(
                    color: const Color(0xFFE50914).withOpacity(0.8),
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Corner markers
                    Positioned(
                      top: 0,
                      left: 0,
                      child: _cornerMarker(true, true, sp),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _cornerMarker(false, true, sp),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: _cornerMarker(true, false, sp),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: _cornerMarker(false, false, sp),
                    ),

                    // Scanning line animation
                    if (!_isProcessing)
                      Positioned.fill(child: _scanningLine(sp)),
                  ],
                ),
              ),
            ),

            // Top controls
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20 * sp),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(10 * sp),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12 * sp),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24 * sp,
                        ),
                      ),
                    ),

                    // Title
                    Text(
                      'Scan Ticket',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18 * sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // Torch button
                    GestureDetector(
                      onTap: _toggleTorch,
                      child: Container(
                        padding: EdgeInsets.all(10 * sp),
                        decoration: BoxDecoration(
                          color: _torchOn
                              ? const Color(0xFFE50914).withOpacity(0.3)
                              : Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12 * sp),
                          border: _torchOn
                              ? Border.all(
                                  color: const Color(0xFFE50914),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Icon(
                          _torchOn ? Icons.flash_on : Icons.flash_off,
                          color: _torchOn
                              ? const Color(0xFFE50914)
                              : Colors.white,
                          size: 24 * sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom instructions
            Positioned(
              bottom: h * 0.12,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  if (_isProcessing) ...[
                    Container(
                      padding: EdgeInsets.all(16 * sp),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16 * sp),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 40 * sp,
                            height: 40 * sp,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFFE50914),
                              ),
                            ),
                          ),
                          SizedBox(height: 12 * sp),
                          Text(
                            'Processing ticket...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14 * sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24 * sp,
                        vertical: 12 * sp,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(30 * sp),
                      ),
                      child: Text(
                        'Point camera at customer QR code',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14 * sp,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Result Overlay
          if (_showResult)
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value * h * 0.5),
                  child: child,
                );
              },
              child: _buildResultView(sp),
            ),
        ],
      ),
    );
  }

  Widget _cornerMarker(bool left, bool top, double sp) {
    return Container(
      width: 30 * sp,
      height: 30 * sp,
      decoration: BoxDecoration(
        border: Border(
          left: left
              ? const BorderSide(color: Color(0xFFE50914), width: 3)
              : BorderSide.none,
          right: !left
              ? const BorderSide(color: Color(0xFFE50914), width: 3)
              : BorderSide.none,
          top: top
              ? const BorderSide(color: Color(0xFFE50914), width: 3)
              : BorderSide.none,
          bottom: !top
              ? const BorderSide(color: Color(0xFFE50914), width: 3)
              : BorderSide.none,
        ),
      ),
    );
  }

  Widget _scanningLine(double sp) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 2000),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Positioned(
          top: value * 250 * sp,
          left: 10 * sp,
          right: 10 * sp,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFE50914).withOpacity(0.8),
                  const Color(0xFFE50914).withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE50914).withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted && _isScanning) {
          setState(() {}); // Restart animation
        }
      },
    );
  }

  Widget _buildResultView(double sp) {
    if (_errorMessage != null && _ticketData == null) {
      return _buildErrorCard(sp);
    }

    final data = _ticketData!;
    final isUsed = data['status'] == 'used';
    final isCancelled = data['status'] == 'cancelled';
    final isValid = !isUsed && !isCancelled;

    final seatCount = (data['seatCount'] as num?)?.toInt() ?? 0;
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final serviceFee = (data['serviceFee'] as num?)?.toDouble() ?? 0.0;
    final calculatedPrice = seatCount > 0 ? (total - serviceFee) / seatCount : 0.0;
    final ticketPrice = (data['ticketPrice'] as num?)?.toDouble() ?? (calculatedPrice > 0 ? calculatedPrice : 250.0);

    return Container(
      color: const Color(0xFF0F0F0F),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20 * sp),
          child: Column(
            children: [
              // Header with status
              Row(
                children: [
                  GestureDetector(
                    onTap: _resetScanner,
                    child: Container(
                      padding: EdgeInsets.all(10 * sp),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12 * sp),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24 * sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 16 * sp),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 10 * sp,
                        horizontal: 16 * sp,
                      ),
                      decoration: BoxDecoration(
                        color: isValid
                            ? Colors.green.withOpacity(0.2)
                            : isUsed
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12 * sp),
                        border: Border.all(
                          color: isValid
                              ? Colors.green
                              : isUsed
                              ? Colors.orange
                              : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isValid
                            ? '✓ VALID TICKET'
                            : isUsed
                            ? '⚠ ALREADY USED'
                            : '✗ CANCELLED',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isValid
                              ? Colors.green
                              : isUsed
                              ? Colors.orange
                              : Colors.red,
                          fontSize: 14 * sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20 * sp),

              // Ticket Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20 * sp),
                  border: Border.all(
                    color: const Color(0xFFD0B781).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Movie Info
                    Padding(
                      padding: EdgeInsets.all(16 * sp),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12 * sp),
                            child: Image.network(
                              data['movieImageUrl'] ?? '',
                              width: 85 * sp,
                              height: 120 * sp,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 85 * sp,
                                height: 120 * sp,
                                color: Colors.grey[800],
                                child: Icon(
                                  Icons.movie,
                                  color: Colors.white,
                                  size: 40 * sp,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16 * sp),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['movieName'] ?? 'Unknown Movie',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18 * sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 8 * sp),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16 * sp,
                                    ),
                                    SizedBox(width: 4 * sp),
                                    Text(
                                      '${data['rating'] ?? '0.0'}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14 * sp,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8 * sp),
                                Text(
                                  data['cinemaName'] ?? 'Unknown Cinema',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13 * sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Divider with circles
                    _ticketDivider(sp),

                    // Details
                    Padding(
                      padding: EdgeInsets.all(16 * sp),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['cinemaName'] ?? 'Unknown Cinema',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20 * sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12 * sp),
                          _detailRow('Date:', data['date'] ?? '-', sp),
                          SizedBox(height: 10 * sp),
                          _detailRow('Time:', data['time'] ?? '-', sp),
                          SizedBox(height: 10 * sp),
                          _detailRow(
                            'Seats:',
                            (data['seats'] as List<dynamic>?)?.join(', ') ??
                                '-',
                            sp,
                          ),
                          SizedBox(height: 10 * sp),
                          _detailRow(
                            'Quantity:',
                            '${data['seatCount'] ?? 0} Tickets',
                            sp,
                          ),
                        ],
                      ),
                    ),

                    // Divider
                    _ticketDivider(sp),

                    // Payment
                    Padding(
                      padding: EdgeInsets.all(16 * sp),
                      child: Column(
                        children: [
                          _paymentRow(
                            'Selected Seats',
                            '$seatCount x Rs.${ticketPrice.toStringAsFixed(0)}',
                            sp,
                          ),
                          SizedBox(height: 10 * sp),
                          _paymentRow(
                            'Service Charge',
                            'Rs. ${data['serviceFee']?.toStringAsFixed(0) ?? '0'}',
                            sp,
                          ),
                          Container(
                            height: 1,
                            color: Colors.grey.withOpacity(0.3),
                            margin: EdgeInsets.symmetric(vertical: 12 * sp),
                          ),
                          _paymentRow(
                            'Total Price',
                            'Rs. ${data['total']?.toStringAsFixed(0) ?? '0'}',
                            sp,
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24 * sp),

              // Action Buttons
              if (isValid) ...[
                SizedBox(
                  width: double.infinity,
                  height: 55 * sp,
                  child: ElevatedButton.icon(
                    onPressed: _markAsUsed,
                    icon: Icon(Icons.check_circle, size: 22 * sp),
                    label: Text(
                      'Confirm Entry - Mark as Used',
                      style: TextStyle(
                        fontSize: 16 * sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30 * sp),
                      ),
                      elevation: 8,
                      shadowColor: const Color(0xFFE50914).withOpacity(0.4),
                    ),
                  ),
                ),
                SizedBox(height: 12 * sp),
              ],

              SizedBox(
                width: double.infinity,
                height: 50 * sp,
                child: OutlinedButton.icon(
                  onPressed: _resetScanner,
                  icon: Icon(Icons.qr_code_scanner, size: 20 * sp),
                  label: Text(
                    'Scan Next Ticket',
                    style: TextStyle(fontSize: 14 * sp),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30 * sp),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 20 * sp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(double sp) {
    return Container(
      color: const Color(0xFF0F0F0F),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(30 * sp),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(30 * sp),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(24 * sp),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 70 * sp,
                      ),
                      SizedBox(height: 20 * sp),
                      Text(
                        'Invalid Ticket',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24 * sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8 * sp),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.grey, fontSize: 14 * sp),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 30 * sp),
                      SizedBox(
                        width: double.infinity,
                        height: 50 * sp,
                        child: ElevatedButton.icon(
                          onPressed: _resetScanner,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE50914),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25 * sp),
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
      ),
    );
  }

  Widget _ticketDivider(double sp) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * sp),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: List.generate(
              25,
              (i) => Expanded(
                child: Container(
                  height: 1,
                  margin: EdgeInsets.symmetric(horizontal: 2 * sp),
                  color: Colors.grey.withOpacity(0.3),
                ),
              ),
            ),
          ),
          Positioned(
            left: -22 * sp,
            child: Container(
              width: 22 * sp,
              height: 22 * sp,
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F0F),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -22 * sp,
            child: Container(
              width: 22 * sp,
              height: 22 * sp,
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F0F),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, double sp) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey, fontSize: 15 * sp),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15 * sp,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _paymentRow(
    String label,
    String value,
    double sp, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? Colors.white : Colors.grey,
            fontSize: isTotal ? 18 * sp : 14 * sp,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: isTotal ? 18 * sp : 14 * sp,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final double cutoutSize;
  final double borderRadius;

  ScannerOverlayPainter({required this.cutoutSize, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: cutoutSize,
            height: cutoutSize,
          ),
          Radius.circular(borderRadius),
        ),
      );

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addPath(cutoutPath, Offset.zero);

    canvas.drawPath(
      Path.combine(PathOperation.difference, backgroundPath, cutoutPath),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
