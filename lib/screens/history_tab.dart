// screens/history_tab.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/tx_tile.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  bool _loading = true;
  String? _error;
  List<TxData> _txs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Aucun utilisateur connecté');

      final snapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      if (!mounted) return;
      setState(() {
        _txs = snapshot.docs.map(_toTxData).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur: $e';
        _loading = false;
      });
    }
  }

  TxData _toTxData(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final type = data['type'] as String? ?? 'incoming';
    final isOut = type == 'outgoing';
    final icon = isOut ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final sign = isOut ? '-' : '+';
    final amount = data['amount'] ?? 0;
    final target = data['target'] ?? data['summary'] ?? 'Transaction';
    final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final reference = doc.id.substring(0, 8).toUpperCase();

    return TxData(
      title: target.toString(),
      subtitle: '$dateStr · $timeStr · Réf. $reference',
      amount: '$sign$amount FCFA',
      isOut: isOut,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.gold500,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ko kɛlenw bɛɛ', style: AppText.eyebrow()),
                    const SizedBox(height: 6),
                    Text('Historique', style: AppText.serif(size: 24)),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _error!,
                      style: AppText.sans(
                        size: 12.5,
                        color: AppColors.red,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.gold500),
                        ),
                      )
                    : _txs.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Aucune transaction pour le moment.',
                              style: AppText.sub(),
                            ),
                          )
                        : Column(
                            children: [
                              for (final tx in _txs) ...[
                                TxTile(tx: tx),
                                if (tx != _txs.last) const SizedBox(height: 10),
                              ],
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}