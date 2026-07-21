# cinemax_seat_booking

A new Flutter project.

## Secure QR Ticket Signing (HMAC-SHA256)

QR tickets now use cryptographic signatures to prevent forgery.

### How it works
- `TicketSigner` (in `lib/core/utils/ticket_signer.dart`) computes `HMAC-SHA256(secret, bookingId)`.
- The QR payload contains **only** `CINEMAX_ADMIN:$bookingId.$signatureHex` (no user details).
- On scan (`ticket_scanner.dart`), the signature is verified **before** any Firestore query.
- If the signature does not match, the ticket is rejected immediately ("possible forgery").

Details (movie, seats, etc.) are always fetched from Firestore after verification.

### Storing the secret key securely

**Recommended: `--dart-define` (compile-time, no source commit)**

1. Generate a strong secret (example):
   ```
   openssl rand -hex 32
   ```

2. Build / run with the secret (DO NOT commit the value):
   ```bash
   flutter run --dart-define=TICKET_SIGNING_SECRET=your_64_char_hex_secret_here
   flutter build apk --dart-define=TICKET_SIGNING_SECRET=your_64_char_hex_secret_here
   flutter build appbundle --dart-define=TICKET_SIGNING_SECRET=...
   ```

   For CI / release pipelines, pass via environment variables:
   ```bash
   flutter build apk --dart-define=TICKET_SIGNING_SECRET=$TICKET_SIGNING_SECRET
   ```

3. In code, `TicketSigner` reads it via:
   ```dart
   static const String _secretKey = String.fromEnvironment('TICKET_SIGNING_SECRET', ...);
   ```

**Alternative: Firebase Remote Config (runtime, supports rotation)**

- Add `firebase_remote_config` to pubspec.
- Fetch a key named e.g. `ticket_hmac_secret` on app startup (and on admin scanner init).
- Make `TicketSigner` async or provide a setter/initializer for the secret before any QR generation or scan.
- This is more advanced; only the admin app needs the secret for verification, but since the user-facing QR generator also needs to sign, the secret ends up on all clients.

**Security notes**
- The secret is embedded in the app binary either way (client must be able to sign).
- Rotate the secret periodically by forcing app updates.
- Use a long random value (32+ bytes).
- Never commit the real secret to git.
- Add `.env` or similar only for local scripts if you wrap the build commands; still do not check real values in.
- In `TicketSigner.isConfigured` you can add runtime guards or `assert(TicketSigner.isConfigured)` in release mode for the scanner.

See `TicketSigner.sign()` / `verify()` and the updated `_qrData` + `_processQR` for implementation details.
