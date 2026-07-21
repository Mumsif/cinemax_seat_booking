import 'dart:convert';
import 'package:crypto/crypto.dart';

/// TicketSigner provides HMAC-SHA256 signing and verification for QR ticket codes.
/// 
/// This prevents forgery by ensuring only tickets signed with the secret key are accepted.
/// 
/// Usage:
///   final signature = TicketSigner.sign(bookingId);
///   final qrPayload = 'CINEMAX_ADMIN:$bookingId.$signature';
/// 
///   final isValid = TicketSigner.verify(bookingId, signature);
///
/// The secret is provided at build time via --dart-define=TICKET_SIGNING_SECRET=...
/// Never hardcode the secret in source code.
class TicketSigner {
  /// The secret key for HMAC. 
  /// Injected via dart-define. Falls back to a placeholder (DO NOT USE IN PROD).
  static const String _secretKey = String.fromEnvironment(
    'TICKET_SIGNING_SECRET',
    defaultValue: 'REPLACE_WITH_YOUR_STRONG_SECRET_VIA_DART_DEFINE',
  );

  /// Returns true if a production secret has been configured.
  static bool get isConfigured =>
      _secretKey.isNotEmpty &&
      !_secretKey.contains('REPLACE') &&
      _secretKey != 'CHANGE_ME_IN_PRODUCTION_USE_DART_DEFINE';

  static bool _warnedInsecure = false;

  /// Computes HMAC-SHA256(secret, bookingId) and returns lowercase hex string.
  static String sign(String bookingId) {
    if (bookingId.isEmpty) {
      throw ArgumentError('bookingId cannot be empty');
    }
    if (!isConfigured) {
      // In debug builds this allows development without define.
      // In release, you should enforce via assert or CI.
      // Print only once per process to avoid log spam.
      // ignore: avoid_print
      if (!_warnedInsecure) {
        _warnedInsecure = true;
        // ignore: avoid_print
        print('[TicketSigner] WARNING: using default/placeholder secret. '
            'Provide --dart-define=TICKET_SIGNING_SECRET=... at build time for production.');
      }
    }

    final key = utf8.encode(_secretKey);
    final message = utf8.encode(bookingId);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(message);
    return digest.toString(); // 64 char hex
  }

  /// Verifies that the provided signature matches the expected HMAC for this bookingId.
  /// Uses constant-time comparison to prevent timing attacks.
  static bool verify(String bookingId, String signature) {
    if (bookingId.isEmpty || signature.isEmpty) return false;

    try {
      final expected = sign(bookingId);
      return _constantTimeEquals(expected, signature.toLowerCase().trim());
    } catch (_) {
      return false;
    }
  }

  /// Constant-time string comparison.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
