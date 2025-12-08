import 'package:cloud_firestore/cloud_firestore.dart';

class WalletNote {
  final String? id;
  final String title;
  final String description;
  final double amount;
  final DateTime createdAt;

  WalletNote({
    this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'amount': amount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory WalletNote.fromMap(Map<String, dynamic> map, String id) {
    return WalletNote(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

class WalletNotesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get collection reference for a specific user
  CollectionReference _getNotesCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('wallet_notes');
  }

  // CREATE
  Future<void> addNote(String userId, WalletNote note) async {
    try {
      await _getNotesCollection(userId).add(note.toMap());
    } catch (e) {
      throw Exception('Failed to add note: $e');
    }
  }

  // READ (Stream)
  Stream<List<WalletNote>> getNotesStream(String userId) {
    return _getNotesCollection(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return WalletNote.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // UPDATE
  Future<void> updateNote(String userId, String noteId, WalletNote note) async {
    try {
      await _getNotesCollection(userId).doc(noteId).update(note.toMap());
    } catch (e) {
      throw Exception('Failed to update note: $e');
    }
  }

  // DELETE
  Future<void> deleteNote(String userId, String noteId) async {
    try {
      await _getNotesCollection(userId).doc(noteId).delete();
    } catch (e) {
      throw Exception('Failed to delete note: $e');
    }
  }
}