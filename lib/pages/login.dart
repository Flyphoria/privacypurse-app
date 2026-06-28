import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:waterflyiii/animations.dart';
import 'package:waterflyiii/config.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/oauth.dart';
import 'package:waterflyiii/pages/splash.dart';
import 'package:waterflyiii/widgets/erroricon.dart';
import 'package:waterflyiii/widgets/logo.dart';

final Logger log = Logger("Pages.Login");

class UriScheme {
  static const String https = "https://";
  static const String http = "http://";

  static bool valid(String uri) {
    return uri.startsWith(http) || uri.startsWith(https);
  }

  static bool isHttp(String uri) {
    return uri.startsWith(http);
  }

  static bool isHttps(String uri) {
    return uri.startsWith(https);
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final Logger log = Logger("Pages.Login.Page");

  final TextEditingController _hostTextController = TextEditingController();
  final TextEditingController _customHeadersTextController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String _uriScheme = UriScheme.https;
  String? _hostError;
  ErrorIcon _hostErrorIcon = const ErrorIcon(false);
  // PrivacyPurse is hosted: the backend URL is hidden behind "advanced" and only
  // shown for local/dev testing. Custom headers share the same advanced section.
  bool _showAdvanced = false;
  bool _signingIn = false;

  final FocusNode _hostFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // Default to the managed PrivacyPurse backend; users normally never edit it.
    _hostTextController.text = kDefaultBackendUrl;
    _uriScheme = UriScheme.isHttp(kDefaultBackendUrl)
        ? UriScheme.http
        : UriScheme.https;
  }

  @override
  void dispose() {
    _hostTextController.dispose();
    _customHeadersTextController.dispose();
    _hostFocusNode.dispose();

    super.dispose();
  }

  bool _hostValid(String value) {
    if (!UriScheme.valid(value)) return false;

    final Uri? uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return false;

    return true;
  }

  Future<void> _signIn() async {
    _formKey.currentState!.validate();
    if (_hostError != null && _hostError!.isNotEmpty) {
      return;
    }
    final String host = _hostTextController.text;
    final String customHeadersRaw = _showAdvanced
        ? _customHeadersTextController.text
        : "";

    setState(() => _signingIn = true);
    try {
      final OAuthResult result = await OAuthService.login(host);
      if (!mounted) {
        return;
      }
      unawaited(
        Navigator.push(
          context,
          MaterialPageRoute<Widget>(
            builder: (BuildContext context) => SplashPage(
              host: host,
              apiKey: result.accessToken,
              customHeadersRaw: customHeadersRaw,
            ),
          ),
        ),
      );
    } catch (e) {
      log.warning("OAuth sign-in failed", e);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).loginErrorOAuth)),
      );
    } finally {
      if (mounted) {
        setState(() => _signingIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    log.finest(() => "build()");
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              Column(
                children: <Widget>[
                  const SizedBox(height: 20),
                  const AppLogo(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
                    child: Text(
                      S.of(context).loginWelcome,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: Card(
                      elevation: 0,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          S.of(context).loginAbout,
                          style: const TextStyle(height: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Advanced: backend URL + custom headers, for dev/self-host only.
                  AnimatedHeight(
                    child: _showAdvanced
                        ? Column(
                            children: <Widget>[
                              SegmentedButton<String>(
                                segments: const <ButtonSegment<String>>[
                                  ButtonSegment<String>(
                                    value: UriScheme.https,
                                    label: Text("HTTPS"),
                                    icon: Icon(Icons.lock_outline),
                                  ),
                                  ButtonSegment<String>(
                                    value: UriScheme.http,
                                    label: Text("HTTP"),
                                    icon: Icon(Icons.lock_open_outlined),
                                  ),
                                ],
                                selected: <String>{_uriScheme},
                                onSelectionChanged: (Set<String> newSelection) {
                                  _hostFocusNode.requestFocus();
                                  if (!UriScheme.valid(newSelection.first) ||
                                      _uriScheme == newSelection.first) {
                                    return;
                                  }
                                  final String currentUrl =
                                      _hostTextController.text;
                                  String oldScheme, newScheme;
                                  if (UriScheme.isHttp(newSelection.first)) {
                                    oldScheme = UriScheme.https;
                                    newScheme = UriScheme.http;
                                  } else {
                                    oldScheme = UriScheme.http;
                                    newScheme = UriScheme.https;
                                  }
                                  if (currentUrl.isEmpty) {
                                    _hostTextController.text = newScheme;
                                  } else if (currentUrl.startsWith(oldScheme)) {
                                    _hostTextController.text =
                                        "$newScheme${currentUrl.substring(oldScheme.length)}";
                                  } else {
                                    _hostTextController.text =
                                        "$newScheme$currentUrl";
                                  }
                                  _hostTextController.selection =
                                      TextSelection.fromPosition(
                                        TextPosition(
                                          offset: _hostTextController.text.length,
                                        ),
                                      );

                                  final bool error =
                                      _hostTextController.text.isNotEmpty &&
                                      !_hostValid(_hostTextController.text);
                                  setState(() {
                                    _uriScheme = newScheme;
                                    if (error != _hostErrorIcon.isError) {
                                      _hostErrorIcon = ErrorIcon(error);
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _hostTextController,
                                focusNode: _hostFocusNode,
                                decoration: InputDecoration(
                                  filled: true,
                                  labelText: S.of(context).loginFormLabelHost,
                                  suffixIcon: _hostErrorIcon,
                                  errorText: _hostError,
                                ),
                                onChanged: (String value) {
                                  String newUriScheme = _uriScheme;

                                  if (!UriScheme.valid(value)) {
                                    newUriScheme = "";
                                  } else if (UriScheme.isHttp(value)) {
                                    newUriScheme = UriScheme.http;
                                  } else if (UriScheme.isHttps(value)) {
                                    newUriScheme = UriScheme.https;
                                  }
                                  if (newUriScheme != _uriScheme) {
                                    setState(() {
                                      _uriScheme = newUriScheme;
                                    });
                                  }

                                  final bool error =
                                      value.isNotEmpty &&
                                      (!UriScheme.valid(value) ||
                                          !_hostValid(value));
                                  if (error != _hostErrorIcon.isError ||
                                      (_hostError != null &&
                                          _hostError!.isNotEmpty &&
                                          _hostError !=
                                              S.of(context).errorInvalidURL)) {
                                    setState(() {
                                      _hostErrorIcon = ErrorIcon(error);
                                      _hostError = error
                                          ? S.of(context).errorInvalidURL
                                          : null;
                                    });
                                  }
                                },
                                autovalidateMode: AutovalidateMode.disabled,
                                validator: (String? value) {
                                  final String? error =
                                      value == null || value.isEmpty
                                      ? S.of(context).errorFieldRequired
                                      : !_hostValid(value)
                                      ? S.of(context).errorInvalidURL
                                      : null;
                                  if (_hostError != error ||
                                      _hostErrorIcon.isError != (error != null)) {
                                    setState(() {
                                      _hostErrorIcon = ErrorIcon(error != null);
                                      _hostError = error;
                                    });
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _customHeadersTextController,
                                decoration: InputDecoration(
                                  filled: true,
                                  labelText: S.of(context).loginFormLabelHeaders,
                                  helperText: S
                                      .of(context)
                                      .loginFormLabelHeadersHelp,
                                ),
                                minLines: 2,
                                maxLines: 5,
                                autocorrect: false,
                                autovalidateMode: AutovalidateMode.disabled,
                              ),
                              const SizedBox(height: 12),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 12,
                    overflowSpacing: 12,
                    children: <Widget>[
                      OutlinedButton(
                        onPressed: _signingIn
                            ? null
                            : () {
                                setState(() {
                                  _showAdvanced = !_showAdvanced;
                                });
                              },
                        child: Text(
                          _showAdvanced
                              ? S.of(context).loginFormButtonHideAdvanced
                              : S.of(context).loginFormButtonShowAdvanced,
                        ),
                      ),
                      FilledButton(
                        onPressed: _signingIn ? null : _signIn,
                        child: _signingIn
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(S.of(context).formButtonLogin),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
