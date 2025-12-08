import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_colors.dart';

class DatabaseInitializer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize SEMUA data yang diperlukan
  Future<Map<String, dynamic>> initializeUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ Initialization failed: User not logged in');
        return {
          'success': false,
          'message': 'User not logged in!',
        };
      }

      final userId = user.uid;
      print('🚀 Starting initialization for user: $userId');

      // 1. Check & Add Wallet Address
      await _initializeWalletAddress(userId);

      // 2. Add Portfolio
      await _initializePortfolio(userId);

      print('✅ Initialization completed successfully!');
      return {
        'success': true,
        'message': 'Database initialized successfully!',
      };
    } on FirebaseException catch (e) {
      print('❌ Firebase error during initialization: ${e.code} - ${e.message}');
      return {
        'success': false,
        'message': 'Firebase error: ${e.message}',
      };
    } catch (e) {
      print('❌ Unexpected error during initialization: ${e.toString()}');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  Future<void> _initializeWalletAddress(String userId) async {
    try {
      print('📍 Initializing wallet address for user: $userId');

      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        print('   Creating new user document...');
        final walletAddress = _generateWalletAddress();
        await _firestore.collection('users').doc(userId).set({
          'walletAddress': walletAddress,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('✅ User document created with wallet: $walletAddress');
        return;
      }

      final data = userDoc.data();

      if (data?['walletAddress'] == null || data!['walletAddress'].isEmpty) {
        print('   Wallet address missing, generating new one...');
        final walletAddress = _generateWalletAddress();
        await _firestore.collection('users').doc(userId).update({
          'walletAddress': walletAddress,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Wallet address created: $walletAddress');
      } else {
        print('ℹ️  Wallet address already exists: ${data['walletAddress']}');
      }
    } on FirebaseException catch (e) {
      print('❌ Firebase error initializing wallet: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ Error initializing wallet address: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> _initializePortfolio(String userId) async {
    try {
      print('📦 Initializing portfolio for user: $userId');

      // Check if portfolio already exists
      final portfolioSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('portfolio')
          .limit(1)
          .get();

      if (portfolioSnapshot.docs.isNotEmpty) {
        print('ℹ️  Portfolio already exists, skipping initialization...');
        return;
      }

      print('   Creating portfolio with default assets...');

      // Add Bitcoin
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('portfolio')
          .doc('bitcoin')
          .set({
        'amount': 0.04511,
        'averagePrice': 45000.0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      print('  ✅ Bitcoin added: 0.04511 BTC');

      // Add Ethereum
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('portfolio')
          .doc('ethereum')
          .set({
        'amount': 3.56,
        'averagePrice': 2500.0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      print('  ✅ Ethereum added: 3.56 ETH');

      // Add Ripple
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('portfolio')
          .doc('ripple')
          .set({
        'amount': 4.0,
        'averagePrice': 0.50,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      print('  ✅ Ripple added: 4.0 XRP');

      print('✅ Portfolio created successfully!');
    } on FirebaseException catch (e) {
      print('❌ Firebase error initializing portfolio: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ Error initializing portfolio: ${e.toString()}');
      rethrow;
    }
  }

  String _generateWalletAddress() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000000).toString().padLeft(6, '0');
    final address = '0x19a15446affabcd1234$random';
    print('🔑 Generated wallet address: $address');
    return address;
  }

  // Check status database
  Future<Map<String, dynamic>> checkDatabaseStatus() async {
    try {
      print('🔍 Checking database status...');

      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️  No user logged in');
        return {
          'hasWallet': false,
          'hasPortfolio': false,
          'portfolioCount': 0,
        };
      }

      final userId = user.uid;
      print('   Checking status for user: $userId');

      // Check wallet
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final hasWallet = userDoc.exists && userDoc.data()?['walletAddress'] != null;
      print('   Wallet status: ${hasWallet ? "✅ Exists" : "❌ Missing"}');

      // Check portfolio
      final portfolioSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('portfolio')
          .get();
      final hasPortfolio = portfolioSnapshot.docs.isNotEmpty;
      final portfolioCount = portfolioSnapshot.docs.length;
      print('   Portfolio status: ${hasPortfolio ? "✅ Exists ($portfolioCount assets)" : "❌ Empty"}');

      final status = {
        'hasWallet': hasWallet,
        'hasPortfolio': hasPortfolio,
        'portfolioCount': portfolioCount,
        'walletAddress': userDoc.data()?['walletAddress'],
      };

      print('✅ Database status check completed');
      return status;

    } on FirebaseException catch (e) {
      print('❌ Firebase error checking status: ${e.code} - ${e.message}');
      return {
        'hasWallet': false,
        'hasPortfolio': false,
        'portfolioCount': 0,
        'error': e.message,
      };
    } catch (e) {
      print('❌ Error checking database status: ${e.toString()}');
      return {
        'hasWallet': false,
        'hasPortfolio': false,
        'portfolioCount': 0,
        'error': e.toString(),
      };
    }
  }
}

// Widget untuk UI - Tombol Initialize
class DatabaseInitializerWidget extends StatefulWidget {
  const DatabaseInitializerWidget({super.key});

  @override
  State<DatabaseInitializerWidget> createState() => _DatabaseInitializerWidgetState();
}

class _DatabaseInitializerWidgetState extends State<DatabaseInitializerWidget> {
  final DatabaseInitializer _initializer = DatabaseInitializer();
  bool _isLoading = false;
  bool _isChecking = true;
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    print('🔧 DatabaseInitializerWidget initialized');
    _checkStatus();
  }

  @override
  void dispose() {
    print('🧹 DatabaseInitializerWidget disposed');
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;

    print('📊 Checking database status...');

    setState(() {
      _isChecking = true;
    });

    try {
      final status = await _initializer.checkDatabaseStatus();

      if (!mounted) return;

      setState(() {
        _status = status;
        _isChecking = false;
      });

      print('✅ Status check completed: ${_status.toString()}');
    } catch (e) {
      print('❌ Error in _checkStatus: ${e.toString()}');

      if (!mounted) return;

      setState(() {
        _status = {
          'hasWallet': false,
          'hasPortfolio': false,
          'portfolioCount': 0,
          'error': e.toString(),
        };
        _isChecking = false;
      });
    }
  }

  Future<void> _initialize() async {
    if (!mounted) return;

    print('🚀 Starting database initialization...');

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _initializer.initializeUserData();

      if (!mounted) return;

      print('📢 Initialization result: ${result.toString()}');

      // Show snackbar with result
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result['success'] ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(result['message']),
              ),
            ],
          ),
          backgroundColor: result['success'] ? AppColors.green : AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      if (result['success']) {
        // Refresh status after successful initialization
        await _checkStatus();
      }
    } catch (e) {
      print('❌ Error in _initialize: ${e.toString()}');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Error: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 12),
              Text(
                'Checking database status...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hasWallet = _status?['hasWallet'] ?? false;
    final hasPortfolio = _status?['hasPortfolio'] ?? false;
    final portfolioCount = _status?['portfolioCount'] ?? 0;
    final hasError = _status?['error'] != null;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasError
                    ? Icons.error
                    : (hasWallet && hasPortfolio)
                    ? Icons.check_circle
                    : Icons.warning,
                color: hasError
                    ? AppColors.red
                    : (hasWallet && hasPortfolio)
                    ? AppColors.green
                    : AppColors.orange,
              ),
              const SizedBox(width: 12),
              const Text(
                'Database Status',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (hasError) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Error: ${_status!['error']}',
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          _buildStatusItem(
            'Wallet Address',
            hasWallet,
            _status?['walletAddress']?.toString() ?? 'Not set',
          ),
          const SizedBox(height: 8),
          _buildStatusItem(
            'Portfolio',
            hasPortfolio,
            hasPortfolio ? '$portfolioCount crypto assets' : 'Not initialized',
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading || (hasWallet && hasPortfolio && !hasError)
                  ? null
                  : _initialize,
              icon: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Icon(
                (hasWallet && hasPortfolio && !hasError)
                    ? Icons.check
                    : Icons.rocket_launch,
              ),
              label: Text(
                _isLoading
                    ? 'Initializing...'
                    : (hasWallet && hasPortfolio && !hasError)
                    ? 'Already Initialized ✓'
                    : hasError
                    ? 'Retry Initialization'
                    : 'Initialize Database',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: (hasWallet && hasPortfolio && !hasError)
                    ? AppColors.green.withOpacity(0.3)
                    : hasError
                    ? AppColors.orange
                    : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          if (hasWallet || hasPortfolio || hasError) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _isLoading ? null : _checkStatus,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh Status'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, bool isOk, String value) {
    return Row(
      children: [
        Icon(
          isOk ? Icons.check_circle : Icons.cancel,
          color: isOk ? AppColors.green : AppColors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}