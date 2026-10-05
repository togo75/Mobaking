import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class InsufficientFundsException implements Exception {
  const InsufficientFundsException();
  @override
  String toString() => 'Insufficient funds';
}

class DatabaseService {
  DatabaseService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  String? _cachedUserId;
  Map<String, dynamic>? _cachedUserData;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw StateError('No authenticated user.');
    return uid;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserData() {
    final uid = _uid;
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        _cachedUserId = uid;
        _cachedUserData = snapshot.data();
      }
      return snapshot;
    });
  }

  Future<double> getCurrentBalance() async {
    final uid = _uid;
    if (_cachedUserId == uid && _cachedUserData?['balance'] is num) {
      return (_cachedUserData!['balance'] as num).toDouble();
    }
    final snapshot = await _db.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (!snapshot.exists || data?['balance'] is! num) {
      throw StateError('User balance is missing or invalid.');
    }
    _cachedUserId = uid;
    _cachedUserData = data;
    return (data!['balance'] as num).toDouble();
  }

  Future<void> saveVoiceAnnotation({
    required String mainAudioUrl,
    String? amountAudioUrl,
    String? numberAudioUrl,
    required Map<String, dynamic> annotation,
  }) async {
    final audioId = const Uuid().v4();
    final payload = <String, dynamic>{
      'audio_id': audioId,
      'audio_url': mainAudioUrl,
      'amount_audio_url': amountAudioUrl,
      'number_audio_url': numberAudioUrl,
      'annotation': annotation,
      'metadata': {
        'user_id': _uid,
        'timestamp': DateTime.now().toIso8601String(),
      },
    };
    await _db.collection('voice_collection').doc(audioId).set(payload);
  }

  Future<String> executeTransfer({
    required int amount,
    required String target,
    required String summary,
    required String messageToSpeak,
  }) async {
    if (amount <= 0 || target.isEmpty) {
      throw ArgumentError('Transfer amount and target must be valid.');
    }
    final uid = _uid;
    final userRef = _db.collection('users').doc(uid);
    final transactionRef = _db.collection('transactions').doc();
    await _db.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final data = userSnapshot.data();
      if (!userSnapshot.exists || data?['balance'] is! num) {
        throw StateError('User balance is missing or invalid.');
      }
      final currentBalance = (data!['balance'] as num).toDouble();
      if (currentBalance < amount) throw const InsufficientFundsException();

      transaction.update(userRef, {'balance': currentBalance - amount});
      transaction.set(transactionRef, {
        'userId': uid,
        'type': 'outgoing',
        'amount': amount,
        'target': target,
        'summary': summary,
        'messageToSpeak': messageToSpeak,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
    _cachedUserData?['balance'] =
        ((_cachedUserData?['balance'] as num?)?.toDouble() ?? 0) - amount;
    return transactionRef.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getTransactions() {
    return _db
        .collection('transactions')
        .where('userId', isEqualTo: _uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}