/// Build-time configuration for the PrivacyPurse backend connection.
///
/// PrivacyPurse is a hosted service, so the app ships pointing at the managed
/// backend instead of asking each user for a server URL. The login screen
/// exposes an "advanced" override of [kDefaultBackendUrl] for local/dev testing
/// (e.g. `http://10.0.2.2:8082` on the Android emulator, or the host LAN IP on a
/// physical device — `localhost` is not reachable from a device/emulator).
library;

/// Default PrivacyPurse backend base URL — no trailing slash, no `/api` suffix.
const String kDefaultBackendUrl = 'https://app.privacypurse.io';

/// Public Passport OAuth client registered on the backend for this app
/// (PKCE, no client secret). Mirrors the Data Importer's public client.
/// Recreate with:
///   php artisan passport:client --public --name="PrivacyPurse App" \
///     --redirect_uri="io.privacypurse.app://oauth"
const String kOAuthClientId = '019f0fa8-b8db-70f3-a44a-62ec0b28b167';

/// OAuth redirect URI (custom-scheme deep link). Must match the Passport
/// client's redirect, the Android intent-filter, and [kOAuthCallbackScheme].
const String kOAuthRedirectUri = 'io.privacypurse.app://oauth';

/// The scheme part of [kOAuthRedirectUri], handed to flutter_web_auth_2.
const String kOAuthCallbackScheme = 'io.privacypurse.app';
