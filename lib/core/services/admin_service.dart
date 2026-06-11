import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Map<String, dynamic>? _currentAdminData;
  static bool _prefsLoaded = false;

  /// Check if current user is any type of admin.
  /// This is made resilient to transient Firestore errors (e.g. on emulator startup).
  static Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('DEBUG: No user logged in');
      return false;
    }

    print('DEBUG: Checking admin for email: ${user.email}');
    print('DEBUG: User UID: ${user.uid}');

    // Simple retry with backoff for transient "unavailable" errors
    const maxRetries = 3;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // Check by UID first
        final docByUid = await _firestore
            .collection('admin')
            .doc(user.uid)
            .get();

        if (docByUid.exists) {
          final data = docByUid.data()!;
          final role = data['role'] as String?;
          
          final isValid = role == 'admin' || role == 'super_admin' || role == 'cinema_admin';
          
          if (isValid) {
            _currentAdminData = data;
            await _saveToPrefs(data);
            print('DEBUG: Admin found by UID, role: $role, cinema: ${data['cinemaName']}');
            return true;
          }
        }

        // Fallback: check by email
        final query = await _firestore
            .collection('admin')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        print('DEBUG: Found ${query.docs.length} admin documents by email');

        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          final role = data['role'] as String?;
          
          final isValid = role == 'admin' || role == 'super_admin' || role == 'cinema_admin';
          
          if (isValid) {
            _currentAdminData = data;
            await _saveToPrefs(data);
            print('DEBUG: Admin found by email, role: $role, cinema: ${data['cinemaName']}');
            return true;
          }
        }

        _currentAdminData = null;
        await _clearPrefs();
        return false;

      } on FirebaseException catch (e) {
        print('DEBUG: Firestore error in isAdmin (attempt ${attempt + 1}): ${e.code} - ${e.message}');
        
        if (e.code == 'unavailable' && attempt < maxRetries - 1) {
          // Transient error - retry with backoff
          final backoffMs = (200 * (attempt + 1));
          print('DEBUG: Retrying admin check after ${backoffMs}ms...');
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        }
        
        // Non-retryable or final attempt - treat as not admin for now
        _currentAdminData = null;
        await _clearPrefs();
        return false;
      } catch (e) {
        print('DEBUG: Unexpected error in isAdmin: $e');
        _currentAdminData = null;
        await _clearPrefs();
        return false;
      }
    }

    return false;
  }

  static Future<void> loadFromPrefs() async {
    if (_prefsLoaded && _currentAdminData != null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('admin_role');
      final cinema = prefs.getString('admin_cinema');
      final email = prefs.getString('admin_email');
      
      if (role != null) {
        _currentAdminData = {
          'role': role,
          'cinemaName': cinema,
          'email': email,
        };
        _prefsLoaded = true;
        print('DEBUG: Loaded admin from prefs: role=$role, cinema=$cinema');
      }
    } catch (e) {
      print('DEBUG: Error loading prefs: $e');
    }
  }

  static Future<void> _saveToPrefs(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_role', data['role'] ?? '');
      await prefs.setString('admin_cinema', data['cinemaName'] ?? '');
      await prefs.setString('admin_email', data['email'] ?? '');
      _prefsLoaded = true;
    } catch (e) {
      print('DEBUG: Error saving prefs: $e');
    }
  }

  static Future<void> _clearPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('admin_role');
      await prefs.remove('admin_cinema');
      await prefs.remove('admin_email');
    } catch (e) {
      print('DEBUG: Error clearing prefs: $e');
    }
  }

  static Map<String, dynamic>? get currentAdminData => _currentAdminData;

  /// TRUE for both "admin" and "super_admin" roles
  static bool get isSuperAdmin {
    final role = _currentAdminData?['role'] as String?;
    return role == 'admin' || role == 'super_admin';
  }

  /// TRUE only for "cinema_admin" role
  static bool get isCinemaAdmin => _currentAdminData?['role'] == 'cinema_admin';

  static String? get adminCinema => _currentAdminData?['cinemaName'] as String?;

  static String? get adminEmail => _currentAdminData?['email'] as String?;

  static Future<void> signOut() async {
    _currentAdminData = null;
    _prefsLoaded = false;
    await _clearPrefs();
    await _auth.signOut();
  }

  static bool canAccessCinema(String cinemaName) {
    if (isSuperAdmin) return true;
    if (isCinemaAdmin) return adminCinema == cinemaName;
    return false;
  }

  static List<String> get manageableCinemas {
    if (isSuperAdmin) {
      return ['Archana Cinema', 'GK Cinemax', 'Shanthi Cinema', 'PCA Cinemas'];
    }
    if (isCinemaAdmin && adminCinema != null) {
      return [adminCinema!];
    }
    return [];
  }
}