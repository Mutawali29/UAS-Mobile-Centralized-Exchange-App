import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction.dart' as models;

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get transactions collection reference for a user
  CollectionReference _getTransactionsCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('transactions');
  }

  // Create a new transaction
  Future<void> createTransaction({
    required String userId,
    required models.Transaction transaction,
  }) async {
    try {
      await _getTransactionsCollection(userId)
          .doc(transaction.id)
          .set(transaction.toJson());
    } catch (e) {
      throw Exception('Failed to create transaction: $e');
    }
  }

  // Get all transactions for a user (real-time stream)
  Stream<List<models.Transaction>> getTransactionsStream(String userId) {
    return _getTransactionsCollection(userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return models.Transaction.fromJson(data);
      }).toList();
    });
  }

  // Get all transactions for a user (one-time fetch)
  Future<List<models.Transaction>> getTransactions(String userId) async {
    try {
      final snapshot = await _getTransactionsCollection(userId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return models.Transaction.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get transactions: $e');
    }
  }

  // Get transactions by type
  Stream<List<models.Transaction>> getTransactionsByType({
    required String userId,
    required models.TransactionType type,
  }) {
    return _getTransactionsCollection(userId)
        .where('type', isEqualTo: type.toString().split('.').last)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return models.Transaction.fromJson(data);
      }).toList();
    });
  }

  // Get transactions by status
  Stream<List<models.Transaction>> getTransactionsByStatus({
    required String userId,
    required models.TransactionStatus status,
  }) {
    return _getTransactionsCollection(userId)
        .where('status', isEqualTo: status.toString().split('.').last)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return models.Transaction.fromJson(data);
      }).toList();
    });
  }

  // Get transaction by ID
  Future<models.Transaction?> getTransactionById({
    required String userId,
    required String transactionId,
  }) async {
    try {
      final doc = await _getTransactionsCollection(userId)
          .doc(transactionId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return models.Transaction.fromJson(data);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get transaction: $e');
    }
  }

  // Update transaction status
  Future<void> updateTransactionStatus({
    required String userId,
    required String transactionId,
    required models.TransactionStatus newStatus,
  }) async {
    try {
      await _getTransactionsCollection(userId)
          .doc(transactionId)
          .update({
        'status': newStatus.toString().split('.').last,
      });
    } catch (e) {
      throw Exception('Failed to update transaction status: $e');
    }
  }

  // Delete transaction
  Future<void> deleteTransaction({
    required String userId,
    required String transactionId,
  }) async {
    try {
      await _getTransactionsCollection(userId)
          .doc(transactionId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  // Get transactions for a specific crypto
  Stream<List<models.Transaction>> getTransactionsByCrypto({
    required String userId,
    required String cryptoSymbol,
  }) {
    return _getTransactionsCollection(userId)
        .where('cryptoSymbol', isEqualTo: cryptoSymbol)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return models.Transaction.fromJson(data);
      }).toList();
    });
  }

  // Get transactions within date range
  Stream<List<models.Transaction>> getTransactionsByDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _getTransactionsCollection(userId)
        .where('timestamp', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('timestamp', isLessThanOrEqualTo: endDate.toIso8601String())
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return models.Transaction.fromJson(data);
      }).toList();
    });
  }

  // Calculate total sent amount
  Future<double> getTotalSent(String userId) async {
    try {
      final snapshot = await _getTransactionsCollection(userId)
          .where('type', isEqualTo: 'send')
          .where('status', isEqualTo: 'completed')
          .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total = total + (data['valueUSD'] as num).toDouble();
      }
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  // Calculate total received amount
  Future<double> getTotalReceived(String userId) async {
    try {
      final snapshot = await _getTransactionsCollection(userId)
          .where('type', isEqualTo: 'receive')
          .where('status', isEqualTo: 'completed')
          .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total = total + (data['valueUSD'] as num).toDouble();
      }
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  // Calculate total trade amount (buy + sell + swap)
  Future<double> getTotalTrade(String userId) async {
    try {
      final snapshot = await _getTransactionsCollection(userId)
          .where('status', isEqualTo: 'completed')
          .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['type'] as String;
        if (type == 'buy' || type == 'sell' || type == 'swap') {
          total = total + (data['valueUSD'] as num).toDouble();
        }
      }
      return total;
    } catch (e) {
      return 0.0;
    }
  }
}