import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_config.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
  });

  final String id;
  final String email;
  final String? firstName;
  final String? lastName;

  String get displayName {
    final fullName = [
      firstName,
      lastName,
    ].where((part) => part != null && part.trim().isNotEmpty).join(' ');
    return fullName.isNotEmpty ? fullName : email;
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'first_name': firstName,
    'last_name': lastName,
  };
}

class AuthService extends ChangeNotifier {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  static const _userKey = 'auth.user';
  static const _accessTokenKey = 'auth.accessToken';
  static const _refreshTokenKey = 'auth.refreshToken';
  static const _pendingStateKey = 'auth.pendingState';
  static const _guestModeKey = 'auth.guestMode';

  final http.Client _client;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  bool _loaded = false;
  bool _busy = false;
  bool _guestMode = false;
  String? _error;
  AuthUser? _user;
  String? _accessToken;
  String? _refreshToken;
  Future<String?>? _refreshInFlight;

  bool get loaded => _loaded;
  bool get busy => _busy;
  bool get guestMode => _guestMode;
  bool get isAuthenticated => _user != null && _accessToken != null;
  bool get isConfigured => AuthConfig.isConfigured;
  String? get error => _error;
  AuthUser? get user => _user;
  String? get accessToken => _accessToken;

  Future<String?> validAccessToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _accessToken != null) return _accessToken;
    return refreshSession();
  }

  Future<String?> refreshSession() {
    return _refreshInFlight ??= _refreshSession().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    _accessToken = prefs.getString(_accessTokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
    _guestMode = prefs.getBool(_guestModeKey) ?? false;
    if (userJson != null) {
      _user = AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    }

    _loaded = true;
    notifyListeners();

    if (!kIsWeb) {
      _linkSubscription ??= _appLinks.uriLinkStream.listen(handleRedirect);
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await handleRedirect(initialUri);
      }
    } else {
      await handleRedirect(Uri.base);
    }
  }

  Future<void> signIn() async {
    _setBusy();
    try {
      if (!AuthConfig.isConfigured) {
        throw const AuthException(
          'WorkOS auth is not configured. Set WORKOS_CLIENT_ID, AUTH_BACKEND_BASE_URL, and exactly one connection selector at build time.',
        );
      }
      final state = _randomState();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingStateKey, state);
      final uri = AuthConfig.authorizationUri(state);
      _error = null;
      _busy = false;
      notifyListeners();

      unawaited(_openSignInPage(uri));
    } catch (e) {
      _error = e.toString();
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> handleRedirect(Uri uri) async {
    if (uri.queryParameters['code'] == null) return;

    _setBusy();
    try {
      final code = uri.queryParameters['code']!;
      final returnedState = uri.queryParameters['state'];
      final prefs = await SharedPreferences.getInstance();
      final expectedState = prefs.getString(_pendingStateKey);
      if (expectedState == null || returnedState != expectedState) {
        throw const AuthException(
          'The sign-in response could not be verified.',
        );
      }

      final response = await _client
          .post(
            AuthConfig.callbackExchangeUri(),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'code': code,
              'redirect_uri': AuthConfig.redirectUri,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(
          'Auth callback failed: ${response.statusCode} ${response.body}',
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = body['access_token'] as String?;
      _refreshToken = body['refresh_token'] as String?;
      final user = body['user'] as Map<String, dynamic>?;
      if (_accessToken == null || user == null) {
        throw const AuthException(
          'Auth callback returned an incomplete session.',
        );
      }

      _user = AuthUser.fromJson(user);
      await prefs.setString(_accessTokenKey, _accessToken!);
      if (_refreshToken != null) {
        await prefs.setString(_refreshTokenKey, _refreshToken!);
      }
      await prefs.setString(_userKey, jsonEncode(_user!.toJson()));
      await prefs.setBool(_guestModeKey, false);
      await prefs.remove(_pendingStateKey);
      _guestMode = false;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_pendingStateKey);
    await prefs.setBool(_guestModeKey, true);
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _guestMode = true;
    _error = null;
    notifyListeners();
  }

  Future<void> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestModeKey, true);
    _guestMode = true;
    _error = null;
    notifyListeners();
  }

  Future<String?> _refreshSession() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await signOut();
      return null;
    }

    try {
      final response = await _client
          .post(
            AuthConfig.refreshUri(),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 400 || response.statusCode == 401) {
          await signOut();
        }
        throw AuthException(
          'Session refresh failed: ${response.statusCode} ${response.body}',
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final nextAccessToken = body['access_token'] as String?;
      final nextRefreshToken = body['refresh_token'] as String?;
      if (nextAccessToken == null || nextRefreshToken == null) {
        throw const AuthException(
          'Session refresh returned an incomplete session.',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      _accessToken = nextAccessToken;
      _refreshToken = nextRefreshToken;
      await prefs.setString(_accessTokenKey, nextAccessToken);
      await prefs.setString(_refreshTokenKey, nextRefreshToken);
      _error = null;
      notifyListeners();
      return _accessToken;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  void _setBusy() {
    _busy = true;
    _error = null;
    notifyListeners();
  }

  Future<void> _openSignInPage(Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const AuthException('Could not open the WorkOS sign-in page.');
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  String _randomState() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _client.close();
    super.dispose();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
