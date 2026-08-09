import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' show DriveApi;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import 'drive/drive_client.dart';

/// Bridges Google Sign-In (identity + Drive access) with Supabase Auth
/// (session/JWT used by edge functions). Two tokens, two jobs: the Supabase
/// session says "this is a legit signed-in caller of my edge functions"; the
/// Google access token is what [DriveClient] uses to read/write the user's
/// own Drive.
///
/// Web needs a different flow than mobile: Google's web SDK (GIS) splits
/// "authentication" (identity/ID token) from "authorization" (scopes/access
/// token), and `GoogleSignIn.signIn()` on web only performs the latter — it
/// does not reliably return an ID token at all. The supported web pattern is
/// the GIS-rendered button (see `google_button.dart`) for authentication,
/// plus a separate `requestScopes` call for Drive access. This class listens
/// for that button's result via [GoogleSignIn.onCurrentUserChanged] and
/// completes the same Supabase bridge automatically.
class AuthService {
  final GoogleSignIn googleSignIn;
  late final DriveClient drive;

  /// Set (non-null) if the web sign-in bridge fails; watch this in the UI
  /// since that flow has no direct caller to report an exception to.
  final ValueNotifier<String?> webSignInError = ValueNotifier(null);

  StreamSubscription<GoogleSignInAccount?>? _webAuthSub;

  AuthService()
      : googleSignIn = GoogleSignIn(
          scopes: ['email', DriveApi.driveFileScope],
          // Not supported on web (google_sign_in_web ignores it) — web
          // configures its client ID via the meta tag in web/index.html.
          serverClientId: AppConfig.googleWebClientId,
        ) {
    drive = DriveClient(googleSignIn);
    if (kIsWeb) {
      _webAuthSub = googleSignIn.onCurrentUserChanged.listen(_onWebUserChanged);
    }
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> _onWebUserChanged(GoogleSignInAccount? account) async {
    if (account == null) return;
    try {
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw StateError('Google did not return an ID token.');
      }
      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: auth.accessToken,
      );
      // The rendered button only authenticates — Drive access is a separate
      // authorization step on web.
      final hasDriveScope =
          await googleSignIn.canAccessScopes([DriveApi.driveFileScope]);
      if (!hasDriveScope) {
        await googleSignIn.requestScopes([DriveApi.driveFileScope]);
      }
      webSignInError.value = null;
    } catch (e) {
      webSignInError.value = 'Google sign-in failed: $e';
    }
  }

  /// Mobile/desktop interactive sign-in: one Google consent screen for both
  /// identity and Drive access, then bridges the ID token into Supabase.
  /// Not used on web — see the class doc.
  ///
  /// Returns `false` if the user cancelled the Google sign-in sheet.
  Future<bool> signInWithGoogle() async {
    final account = await googleSignIn.signIn();
    if (account == null) return false;
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw StateError('Google did not return an ID token.');
    }
    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: auth.accessToken,
    );
    return true;
  }

  /// Called on app start. Supabase's own session persistence (handled by
  /// `supabase_flutter`) already restores the signed-in state independently
  /// of this — what this actually does is populate `GoogleSignIn.currentUser`
  /// silently, which [DriveClient] needs in order to build an authenticated
  /// Drive client later. Safe to call even if there's no previous Google
  /// session (returns quietly).
  Future<void> warmUpGoogleSession() async {
    await googleSignIn.signInSilently();
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await googleSignIn.signOut();
    drive.reset();
  }

  /// Fully revokes the app's Google grant (used by account deletion) rather
  /// than just ending the local session.
  Future<void> disconnect() async {
    await googleSignIn.disconnect();
    drive.reset();
  }

  void dispose() {
    _webAuthSub?.cancel();
    webSignInError.dispose();
  }
}
