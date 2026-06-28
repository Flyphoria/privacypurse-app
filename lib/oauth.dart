import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:waterflyiii/config.dart';

final Logger log = Logger("OAuth");

/// Thrown when the OAuth2 authorization-code + PKCE flow fails or is cancelled.
class OAuthError implements Exception {
  const OAuthError(this.message);

  final String message;

  @override
  String toString() => "OAuthError: $message";
}

/// Tokens returned by a successful OAuth login.
class OAuthResult {
  const OAuthResult({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
  });

  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;
}

/// Runs the OAuth2 authorization-code flow with PKCE against a PrivacyPurse
/// (Firefly III / Laravel Passport) backend and returns the access token, which
/// is then used as a normal Bearer token by [FireflyService.signIn].
class OAuthService {
  static final Random _random = Random.secure();

  /// base64url (no padding) of [length] random bytes — used for the PKCE
  /// verifier and the anti-CSRF state.
  static String _randomUrlToken(int length) {
    final List<int> bytes = List<int>.generate(
      length,
      (_) => _random.nextInt(256),
    );
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// S256 PKCE challenge for [verifier].
  static String _codeChallenge(String verifier) {
    final Digest digest = sha256.convert(ascii.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  static String _normalizeHost(String host) {
    host = host.trim();
    while (host.endsWith('/')) {
      host = host.substring(0, host.length - 1);
    }
    return host;
  }

  /// Opens the system browser to the backend's consent screen, captures the
  /// redirect via the custom-scheme deep link, and exchanges the code for tokens.
  ///
  /// [host] is the backend base URL (no trailing slash, no `/api`).
  static Future<OAuthResult> login(String host) async {
    host = _normalizeHost(host);

    final String verifier = _randomUrlToken(64);
    final String challenge = _codeChallenge(verifier);
    final String state = _randomUrlToken(16);

    final Uri authorizeUrl = Uri.parse(
      '$host/oauth/authorize',
    ).replace(
      queryParameters: <String, String>{
        'client_id': kOAuthClientId,
        'redirect_uri': kOAuthRedirectUri,
        'response_type': 'code',
        'scope': '',
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      },
    );

    log.fine(() => "OAuth authorize -> $authorizeUrl");

    final String resultUrl = await FlutterWebAuth2.authenticate(
      url: authorizeUrl.toString(),
      callbackUrlScheme: kOAuthCallbackScheme,
    );

    final Uri result = Uri.parse(resultUrl);
    final String? error = result.queryParameters['error'];
    if (error != null) {
      throw OAuthError(error);
    }
    if (result.queryParameters['state'] != state) {
      throw const OAuthError("state_mismatch");
    }
    final String? code = result.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const OAuthError("missing_authorization_code");
    }

    log.fine(() => "OAuth code received, exchanging for token");

    final http.Response response = await http.post(
      Uri.parse('$host/oauth/token'),
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: <String, String>{
        'grant_type': 'authorization_code',
        'client_id': kOAuthClientId,
        'redirect_uri': kOAuthRedirectUri,
        'code_verifier': verifier,
        'code': code,
      },
    );

    if (response.statusCode != 200) {
      log.warning("Token exchange failed: ${response.statusCode} ${response.body}");
      throw OAuthError("token_exchange_failed_${response.statusCode}");
    }

    final Map<String, dynamic> data =
        json.decode(response.body) as Map<String, dynamic>;
    final String? accessToken = data['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw const OAuthError("missing_access_token");
    }

    return OAuthResult(
      accessToken: accessToken,
      refreshToken: data['refresh_token'] as String?,
      expiresIn: data['expires_in'] as int?,
    );
  }
}
