import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Notifies when auth state changes so GoRouter can re-run redirect.
class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _sub;

  /// Current user. Null if not signed in.
  User? get currentUser => FirebaseAuth.instance.currentUser;

  /// True if user is signed in and is not anonymous (staff login).
  bool get isStaffSignedIn {
    final u = currentUser;
    return u != null && !u.isAnonymous;
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
