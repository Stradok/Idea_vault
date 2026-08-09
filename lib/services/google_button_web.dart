import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// The GIS (Google Identity Services) native sign-in button — required on
/// web because `GoogleSignIn.signIn()` there only returns an access token,
/// not the ID token Supabase needs (see google_sign_in_web's own README).
/// Completing this button's flow fires [GoogleSignIn.onCurrentUserChanged],
/// which AuthService listens to in order to bridge into Supabase.
Widget buildGoogleSignInButton() => web.renderButton();
