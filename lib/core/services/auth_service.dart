import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

// ── SharedPreferences anahtarları ─────────────────────────────────────────────
const _kIdToken      = 'auth_id_token';
const _kRefreshToken = 'auth_refresh_token';
const _kTokenExpiry  = 'auth_token_expiry';
const _kRememberMe   = 'auth_remember_me';
const _kDisplayName  = 'auth_display_name';
const _kEmail        = 'auth_email';
const _kRole         = 'auth_role';
const _kMerchantId   = 'auth_merchant_id';

// ── Firebase Auth REST endpoints ──────────────────────────────────────────────
const _signInUrl =
    'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword'
    '?key=$kFirebaseWebApiKey';
const _refreshUrl =
    'https://securetoken.googleapis.com/v1/token'
    '?key=$kFirebaseWebApiKey';

/// Singleton auth servisi.
///
/// Kullanım:
///   await AuthService.instance.init();           // main()'de
///   await AuthService.instance.login(email, pw); // LoginScreen'de
///   AuthService.instance.isLoggedIn              // Consumer'da
class AuthService extends ChangeNotifier {
  AuthService._();
  static final instance = AuthService._();

  // ── State ─────────────────────────────────────────────────────────────────
  bool    _isLoggedIn  = false;
  String? _idToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  String? _displayName;
  String? _email;
  String? _role;
  String? _merchantId;

  bool    get isLoggedIn   => _isLoggedIn;
  String? get displayName  => _displayName;
  String? get email        => _email;
  String? get role         => _role;
  String? get merchantId   => _merchantId;
  bool    get isAdmin      => _role == 'merchant_admin';
  bool    get isCashier    => _role == 'merchant_cashier';

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // ── init — uygulama başlangıcında çağır ───────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_kRememberMe) ?? false;
    if (!rememberMe) return;

    _refreshToken = prefs.getString(_kRefreshToken);
    _displayName  = prefs.getString(_kDisplayName);
    _email        = prefs.getString(_kEmail);
    _role         = prefs.getString(_kRole);
    _merchantId   = prefs.getString(_kMerchantId);

    if (_refreshToken == null) return;

    final expiryMs = prefs.getInt(_kTokenExpiry) ?? 0;
    final expiry   = DateTime.fromMillisecondsSinceEpoch(expiryMs);

    if (DateTime.now().isBefore(expiry)) {
      // Token hâlâ geçerli — sadece yükle
      _idToken    = prefs.getString(_kIdToken);
      _isLoggedIn = _idToken != null;
    } else {
      // Token süresi dolmuş — refresh et
      await _refreshIdToken();
    }
    notifyListeners();
  }

  // ── login ─────────────────────────────────────────────────────────────────
  Future<void> login(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      _signInUrl,
      data: {
        'email':             email,
        'password':          password,
        'returnSecureToken': true,
      },
      options: Options(
        headers:          {'Content-Type': 'application/json'},
        validateStatus:   (s) => s != null && s < 500,
      ),
    );

    if (resp.statusCode != 200) {
      final errCode = resp.data?['error']?['message'] as String? ?? 'UNKNOWN';
      throw _mapFirebaseError(errCode);
    }

    final data = resp.data!;
    await _applyTokens(
      idToken:      data['idToken']      as String,
      refreshToken: data['refreshToken'] as String,
      expiresIn:    int.parse(data['expiresIn'] as String),
      displayName:  data['displayName']  as String? ?? email.split('@').first,
      email:        email,
      rememberMe:   rememberMe,
    );
  }

  // ── logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    _idToken      = null;
    _refreshToken = null;
    _tokenExpiry  = null;
    _displayName  = null;
    _email        = null;
    _role         = null;
    _merchantId   = null;
    _isLoggedIn   = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIdToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kTokenExpiry);
    await prefs.remove(_kRememberMe);
    await prefs.remove(_kDisplayName);
    await prefs.remove(_kEmail);
    await prefs.remove(_kRole);
    await prefs.remove(_kMerchantId);

    notifyListeners();
  }

  // ── getValidToken — sync için kullan ──────────────────────────────────────
  Future<String?> getValidToken() async {
    if (_idToken == null) return null;
    final expiry = _tokenExpiry;
    if (expiry != null &&
        DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 5)))) {
      await _refreshIdToken();
    }
    return _idToken;
  }

  // ── _refreshIdToken ───────────────────────────────────────────────────────
  Future<void> _refreshIdToken() async {
    if (_refreshToken == null) return;
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        _refreshUrl,
        data: {
          'grant_type':    'refresh_token',
          'refresh_token': _refreshToken,
        },
        options: Options(headers: {'Content-Type': 'application/x-www-form-urlencoded'}),
      );

      if (resp.statusCode != 200) {
        await logout();
        return;
      }

      final data = resp.data!;
      await _applyTokens(
        idToken:      data['id_token']      as String,
        refreshToken: data['refresh_token'] as String,
        expiresIn:    int.parse(data['expires_in'] as String),
        displayName:  _displayName,
        email:        _email,
        rememberMe:   true,
      );
    } catch (_) {
      // Refresh başarısız → kullanıcıyı login ekranına yönlendir
      await logout();
    }
  }

  // ── _applyTokens — token aldıktan sonra state'i ve kalıcı depolamayı yaz ─
  Future<void> _applyTokens({
    required String  idToken,
    required String  refreshToken,
    required int     expiresIn,
    String?          displayName,
    String?          email,
    bool             rememberMe = false,
  }) async {
    _idToken      = idToken;
    _refreshToken = refreshToken;
    _tokenExpiry  = DateTime.now().add(Duration(seconds: expiresIn));
    _displayName  = displayName;
    _email        = email;
    _isLoggedIn   = true;

    // JWT payload'ından custom claim'leri çöz
    final claims  = _decodeJwtPayload(idToken);
    _role         = claims['role']       as String?;
    _merchantId   = claims['merchantId'] as String?;

    if (rememberMe) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kIdToken,       idToken);
      await prefs.setString(_kRefreshToken,  refreshToken);
      await prefs.setInt(   _kTokenExpiry,   _tokenExpiry!.millisecondsSinceEpoch);
      await prefs.setBool(  _kRememberMe,    true);
      if (displayName != null) await prefs.setString(_kDisplayName, displayName);
      if (email       != null) await prefs.setString(_kEmail,       email);
      if (_role       != null) await prefs.setString(_kRole,        _role!);
      if (_merchantId != null) await prefs.setString(_kMerchantId,  _merchantId!);
    }

    notifyListeners();
  }

  // ── JWT payload decode (imza doğrulaması olmaksızın) ─────────────────────
  static Map<String, dynamic> _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      var payload = parts[1]
          .replaceAll('-', '+')
          .replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2: payload += '=='; break;
        case 3: payload += '=';  break;
      }
      final decoded = utf8.decode(base64.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // ── Firebase hata kodlarını Türkçe mesaja çevir ───────────────────────────
  static Exception _mapFirebaseError(String code) {
    return switch (code) {
      'EMAIL_NOT_FOUND'       => Exception('Bu e-posta adresi kayıtlı değil.'),
      'INVALID_PASSWORD'      => Exception('Şifre hatalı.'),
      'INVALID_EMAIL'         => Exception('Geçersiz e-posta adresi.'),
      'USER_DISABLED'         => Exception('Bu hesap devre dışı bırakıldı.'),
      'TOO_MANY_ATTEMPTS_TRY_LATER' ||
      'INVALID_LOGIN_CREDENTIALS' => Exception('Çok fazla başarısız deneme. Lütfen bekleyin.'),
      _                       => Exception('Giriş başarısız. Lütfen tekrar deneyin.'),
    };
  }
}
