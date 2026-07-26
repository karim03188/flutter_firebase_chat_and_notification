import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps Google Sign-In + Firebase credential exchange.
///
/// There is no separate "create account" step for Google — Firebase resolves
/// this automatically: if no account exists for the Google user's email, one
/// is created; if one already exists (whether originally created via Google
/// or via email/password), that same account is signed into. The caller
/// never needs to know or choose which case applies.
class AuthService {
  static Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount account = await GoogleSignIn.instance.authenticate();

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw Exception('Google sign-in did not return an ID token');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  /// Whether the signed-in user can currently sign in with a password
  /// (false for an account that only ever used Google Sign-In).
  static bool get hasPasswordProvider {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  /// Adds an email/password sign-in method to the *currently signed-in*
  /// account, without creating a separate account or touching Google Sign-In.
  /// Typically used for a Google-only account that wants a fallback password.
  static Future<void> addPassword(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final email = user.email;
    if (email == null) throw Exception('Account has no email to attach a password to');

    final credential = EmailAuthProvider.credential(email: email, password: password);
    await user.linkWithCredential(credential);
  }

  static Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }
}
