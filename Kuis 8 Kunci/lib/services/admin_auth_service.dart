/// AdminAuthService - Manages admin authentication state and credentials
/// Stores: admin_id, email, token, so all operations can be filtered by admin
import 'package:logger/logger.dart';

class AdminAuthService {
  static final AdminAuthService _instance = AdminAuthService._internal();
  final logger = Logger();

  // Admin session state
  String? _adminId;
  String? _email;
  String? _fullName;
  String? _token;

  factory AdminAuthService() {
    return _instance;
  }

  static AdminAuthService get instance => _instance;

  AdminAuthService._internal();

  // ============================================
  // STATE MANAGEMENT
  // ============================================

  /// Set admin as logged in
  void setAdminLoggedIn({
    required String adminId,
    required String email,
    required String? fullName,
    required String token,
  }) {
    _adminId = adminId;
    _email = email;
    _fullName = fullName;
    _token = token;
    logger.i('Admin logged in: $email (ID: $adminId)');
  }

  /// Clear admin session on logout
  void logout() {
    _adminId = null;
    _email = null;
    _fullName = null;
    _token = null;
    logger.i('Admin logged out');
  }

  /// Check if admin is logged in
  bool isLoggedIn() => _adminId != null && _token != null;

  // ============================================
  // GETTERS
  // ============================================

  String? get adminId => _adminId;
  String? get email => _email;
  String? get fullName => _fullName;
  String? get token => _token;

  /// Get admin ID as integer (for queries)
  int? get adminIdAsInt {
    if (_adminId == null) return null;
    return int.tryParse(_adminId!);
  }

  // ============================================
  // DISPLAY METHODS
  // ============================================

  String getDisplayName() => _fullName ?? _email ?? 'Admin';

  Map<String, dynamic> toMap() => {
    'admin_id': _adminId,
    'email': _email,
    'full_name': _fullName,
    'token': _token,
  };

  @override
  String toString() =>
      'AdminAuthService{email: $_email, adminId: $_adminId, loggedIn: ${isLoggedIn()}}';
}
