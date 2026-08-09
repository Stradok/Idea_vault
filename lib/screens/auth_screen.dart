import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/google_button.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().signInWithGoogle();
    } catch (e) {
      setState(() =>
          _error = 'Google sign-in failed. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 8),
                  Text(
                    'IdeaVault',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Capture ideas. Research them. Grow them.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your ideas, photos, and voice notes are saved to your '
                    'own Google Drive — never our servers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'IdeaVault is in private testing — only invited test '
                    'accounts can sign in right now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                  if (kIsWeb)
                    ValueListenableBuilder<String?>(
                      valueListenable:
                          context.read<AuthService>().webSignInError,
                      builder: (context, error, _) => error == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Text(
                                error,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: theme.colorScheme.error),
                              ),
                            ),
                    )
                  else if (_error != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 28),
                  // Web must use Google's own rendered button (GIS) — see
                  // AuthService's class doc for why signIn() doesn't work
                  // the same way there.
                  if (kIsWeb)
                    Center(child: buildGoogleSignInButton())
                  else
                    FilledButton.icon(
                      onPressed: _loading ? null : _signIn,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.g_mobiledata, size: 26),
                      label:
                          Text(_loading ? 'Signing in...' : 'Continue with Google'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
