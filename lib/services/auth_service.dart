import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' show DriveApi;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import 'drive/drive_client.dart';

/// Bridges native Google Sign-In (identity + Drive access) with Supabase
/// Auth (session/JWT used by edge functions). Two tokens, two jobs: the
/// Supabase session says "this is a legit signed-in caller of my edge
/// functions"; the Google access token is what [DriveClient] uses to read
/// and write the user's own Drive.
class AuthService {
  final GoogleSignIn googleSignIn;
  late final DriveClient drive;

  AuthService()
      : googleSignIn = GoogleSignIn(
          scopes: ['email', DriveApi.driveFileScope],
          serverClientId: AppConfig.googleWebClientId,
        ) {
    drive = DriveClient(googleSignIn);
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Interactive sign-in: Google consent (identity + Drive access) then
  /// bridges the resulting ID token into a Supabase session.
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
}
