import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  // Flag untuk mencegah multiple initialization
  bool _isInitializing = false;
  bool _isInitialized = false;

  // Current user getter
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Generate wallet address
  String _generateWalletAddress() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final userId = _auth.currentUser?.uid ?? 'unknown';
    final hash = userId.hashCode.abs().toString().padLeft(8, '0');
    final random = (timestamp % 1000000).toString().padLeft(6, '0');
    return '0x${hash.substring(0, 4)}${random}${hash.substring(4, 8)}';
  }

  // Initialize wallet for new user
  Future<void> _initializeWallet(String userId) async {
    try {
      print('💰 Initializing wallet for user: $userId');

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();

      // Add wallet address if doesn't exist
      if (data?['walletAddress'] == null) {
        final walletAddress = _generateWalletAddress();
        await _firestore.collection('users').doc(userId).update({
          'walletAddress': walletAddress,
        });
        print('✅ Wallet address created: $walletAddress');

        // Initialize with empty portfolio (optional sample data)
        await _addSamplePortfolio(userId);
      } else {
        print('✅ Wallet already exists: ${data?['walletAddress']}');
      }
    } catch (e) {
      print('⚠️ Error initializing wallet: $e');
    }
  }

  // Add sample portfolio (optional - comment out if you don't want sample data)
  Future<void> _addSamplePortfolio(String userId) async {
    try {
      print('📊 Checking for existing portfolio...');

      // Check if portfolio already exists
      final portfolioSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('portfolio')
          .limit(1)
          .get();

      if (portfolioSnapshot.docs.isEmpty) {
        print('📦 Adding sample portfolio...');

        // Add sample holdings
        final samplePortfolio = {
          'bitcoin': {'amount': 0.04511, 'averagePrice': 45000.00},
          'ethereum': {'amount': 3.56, 'averagePrice': 2500.00},
          'ripple': {'amount': 4.0, 'averagePrice': 0.50},
        };

        for (var entry in samplePortfolio.entries) {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('portfolio')
              .doc(entry.key)
              .set({
            'amount': entry.value['amount'],
            'averagePrice': entry.value['averagePrice'],
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
        print('✅ Sample portfolio initialized');
      } else {
        print('✅ Portfolio already exists');
      }
    } catch (e) {
      print('⚠️ Error adding sample portfolio: $e');
    }
  }

  // Initialize Google Sign-In dengan safety check
  Future<void> _initializeGoogleSignIn() async {
    if (_isInitialized || _isInitializing) {
      print('⚠️ Google Sign-In already initialized or initializing');
      return;
    }

    try {
      _isInitializing = true;
      print('🔐 Initializing Google Sign-In...');

      // Cek apakah sudah signed in
      final isSignedIn = await _googleSignIn.isSignedIn();
      if (isSignedIn) {
        print('✅ Google Sign-In already authenticated');
      }

      _isInitialized = true;
      print('✅ Google Sign-In initialized successfully');
    } catch (e) {
      print('⚠️ Error initializing Google Sign-In: $e');
      _isInitialized = false;
    } finally {
      _isInitializing = false;
    }
  }

  // Sign up dengan email dan password
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      print('📝 Creating account for: $email');

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(name);

        // Save user data to Firestore
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': email,
          'name': name,
          'createdAt': FieldValue.serverTimestamp(),
          'isVerified': false,
        });

        // Initialize wallet
        await _initializeWallet(credential.user!.uid);

        // Send email verification
        await credential.user!.sendEmailVerification();

        print('✅ Account created successfully');
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      print('❌ Sign up error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Unexpected sign up error: $e');
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Sign in dengan email dan password
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔑 Signing in with email: $email');

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Initialize wallet if not exists (for existing users)
      if (credential.user != null) {
        await _initializeWallet(credential.user!.uid);
      }

      print('✅ Email sign-in successful');
      return credential;
    } on FirebaseAuthException catch (e) {
      print('❌ Sign in error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Unexpected sign in error: $e');
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Sign in dengan Google (dengan fix untuk web)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('🔐 Starting Google Sign-In process...');

      // Initialize jika belum
      await _initializeGoogleSignIn();

      // Silent sign-in attempt first (untuk mencegah multiple popup)
      GoogleSignInAccount? googleUser;

      try {
        googleUser = await _googleSignIn.signInSilently();
        if (googleUser != null) {
          print('✅ Silent Google Sign-In successful');
        }
      } catch (e) {
        print('⚠️ Silent sign-in failed, trying interactive sign-in: $e');
      }

      // Jika silent sign-in gagal, lakukan interactive sign-in
      if (googleUser == null) {
        try {
          // Sign out dulu untuk clear state
          await _googleSignIn.signOut();

          // Kemudian sign in lagi
          googleUser = await _googleSignIn.signIn();

          if (googleUser == null) {
            print('ℹ️ Google Sign-In cancelled by user');
            return null;
          }

          print('✅ Interactive Google Sign-In successful');
        } catch (e) {
          print('❌ Interactive Google Sign-In error: $e');
          // Jika error, coba sign out dan return null
          try {
            await _googleSignIn.signOut();
          } catch (_) {}

          // Ignore "Future already completed" error
          if (e.toString().toLowerCase().contains('future already completed') ||
              e.toString().toLowerCase().contains('bad state')) {
            print('⚠️ Ignored known Google Sign-In error');
            return null;
          }

          throw Exception('Google Sign-In failed. Please try again.');
        }
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth;
      try {
        googleAuth = await googleUser.authentication;
      } catch (e) {
        print('❌ Error getting Google authentication: $e');
        await _googleSignIn.signOut();

        if (e.toString().toLowerCase().contains('future already completed')) {
          print('⚠️ Ignored authentication error');
          return null;
        }

        throw Exception('Failed to get authentication details. Please try again.');
      }

      // Create credentials
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      print('🔥 Signing in to Firebase...');
      final userCredential = await _auth.signInWithCredential(credential);

      // Save user data if new user
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        print('👤 New user detected, creating profile...');
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'uid': userCredential.user!.uid,
          'email': userCredential.user!.email,
          'name': userCredential.user!.displayName,
          'createdAt': FieldValue.serverTimestamp(),
          'isVerified': true,
        });
      }

      // Initialize wallet
      if (userCredential.user != null) {
        await _initializeWallet(userCredential.user!.uid);
      }

      print('✅ Google Sign-In completed successfully');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      // Clean up Google Sign-In state
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      // Clean up Google Sign-In state
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      // Jangan throw error "Future already completed"
      if (e.toString().toLowerCase().contains('future already completed') ||
          e.toString().toLowerCase().contains('bad state')) {
        print('⚠️ Ignored "Future already completed" error');
        return null;
      }

      throw Exception('Google Sign-In failed: ${e.toString()}');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      print('📧 Sending password reset email to: $email');

      await _auth.sendPasswordResetEmail(email: email);

      print('✅ Password reset email sent');
    } on FirebaseAuthException catch (e) {
      print('❌ Reset password error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Unexpected password reset error: $e');
      throw Exception('Failed to send password reset email: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      print('🚪 Signing out...');

      // Sign out dari Google jika perlu
      final isGoogleSignedIn = await _googleSignIn.isSignedIn();
      if (isGoogleSignedIn) {
        try {
          await _googleSignIn.signOut();
          print('✅ Google Sign-Out successful');
        } catch (e) {
          print('⚠️ Google Sign-Out error (ignored): $e');
          // Ignore error saat sign out dari Google
        }
      }

      // Sign out dari Firebase
      await _auth.signOut();

      // Reset initialization flag
      _isInitialized = false;
      _isInitializing = false;

      print('✅ Sign-Out completed');
    } catch (e) {
      print('❌ Sign out error: $e');
      // Tetap reset flag meskipun ada error
      _isInitialized = false;
      _isInitializing = false;
      throw Exception('Failed to sign out: $e');
    }
  }

  // Update profile
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      print('👤 Updating user profile...');

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      if (displayName != null) {
        await user.updateDisplayName(displayName);
        await _firestore.collection('users').doc(user.uid).update({
          'name': displayName,
        });
        print('✅ Display name updated');
      }

      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
        print('✅ Photo URL updated');
      }

      await user.reload();
      print('✅ Profile updated successfully');
    } catch (e) {
      print('❌ Update profile error: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      print('🗑️ Deleting user account...');

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      // Delete user data from Firestore
      await _firestore.collection('users').doc(user.uid).delete();
      print('✅ User data deleted from Firestore');

      // Delete user account
      await user.delete();

      print('✅ Account deleted successfully');
    } catch (e) {
      print('❌ Delete account error: $e');
      throw Exception('Failed to delete account: $e');
    }
  }

  // Handle Firebase Auth Exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'popup-closed-by-user':
        return 'Sign-in popup was closed. Please try again.';
      case 'cancelled-popup-request':
        return 'Another sign-in is in progress.';
      case 'invalid-credential':
        return 'Invalid credentials provided.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  // Check if user is signed in
  bool isSignedIn() {
    return _auth.currentUser != null;
  }

  // Get current user email
  String? getCurrentUserEmail() {
    return _auth.currentUser?.email;
  }

  // Get current user display name
  String? getCurrentUserDisplayName() {
    return _auth.currentUser?.displayName;
  }

  // Cleanup method untuk dipanggil saat app dispose
  Future<void> dispose() async {
    try {
      // Disconnect Google Sign-In
      await _googleSignIn.disconnect();
      _isInitialized = false;
      _isInitializing = false;
      print('✅ Auth service disposed');
    } catch (e) {
      print('⚠️ Error disposing auth service: $e');
    }
  }
}