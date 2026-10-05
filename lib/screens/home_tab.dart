// ignore_for_file: unused_element

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/tx_tile.dart';
import 'voice_screen.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onMicTap;
  const HomeTab({super.key, required this.onMicTap});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _balanceVisible = true;
  bool _loading = false;
  String? _loadError;
  int _balanceCfa = 0;
  String _accountNumber = '';
  List<Map<String, dynamic>> _rawTxs = [];

  static const _quickActions = [
    (Icons.arrow_upward_rounded, 'Envoyer', Color(0xFF4A6CF7)),
    (Icons.arrow_downward_rounded, 'Recevoir', Color(0xFF6B4CF7)),
    (Icons.receipt_rounded, 'Payer', Color(0xFF8B5CF6)),
    (Icons.phone_android_rounded, 'Crédit', Color(0xFF10B981)),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Aucun utilisateur connecté');

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};

      final txsSnapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(6)
          .get();

      if (!mounted) return;
      setState(() {
        _balanceCfa = (userData['balance'] as num?)?.toInt() ?? 0;
        _accountNumber = userData['accountNumber'] as String? ?? '';
        _rawTxs = txsSnapshot.docs.map((d) {
          final data = d.data();
          data['_id'] = d.id;
          return data;
        }).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Erreur: $e';
        _loading = false;
      });
    }
  }

  TxData _toTxData(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'incoming';
    final isOut = type == 'outgoing';
    final icon = isOut ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final sign = isOut ? '-' : '+';
    final target = data['target'] ?? data['summary'] ?? 'Transaction';
    final amount = data['amount'] ?? 0;
    final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final reference = (data['_id'] as String? ?? '').substring(0, 8).toUpperCase();

    return TxData(
      title: target.toString(),
      subtitle: '$timeStr · Réf. $reference',
      amount: '$sign$amount F',
      isOut: isOut,
      icon: icon,
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupByDay(
    List<Map<String, dynamic>> txs,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final tx in txs) {
      final date = (tx['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final d = DateTime(date.year, date.month, date.day);
      final String label;
      if (d == today) {
        label = "Aujourd'hui";
      } else if (d == yesterday) {
        label = 'Hier';
      } else {
        label = '${date.day}/${date.month}/${date.year}';
      }
      grouped.putIfAbsent(label, () => []).add(tx);
    }
    return grouped;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4A6CF7),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openVoiceForService(String serviceName) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => VoiceScreen(serviceName: serviceName),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, .06),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDay(_rawTxs);
    final firstName = (FirebaseAuth.instance.currentUser?.displayName ?? '')
        .split(' ')
        .first;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: const Color(0xFF4A6CF7),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              if (_loadError != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _loadError!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              // Topbar modernisé
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'I ni sɔgɔma',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bonjour, $firstName',
                          style: const TextStyle(
                            fontFamily: 'Serif',
                            fontSize: 20,
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _NotificationBell(
                          onTap: () => _showSnackBar('Notifications à venir'),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF4A6CF7),
                                Color(0xFF6B4CF7),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Carte de solde
              Container(
                margin: const EdgeInsets.fromLTRB(22, 16, 22, 6),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromARGB(255, 10, 74, 176),
                      Color.fromARGB(255, 23, 27, 33),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A6CF7).withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Wari bɛ sisan — Solde disponible',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.3,
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _balanceVisible = !_balanceVisible),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              _balanceVisible
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: const Color(0xFF94A3B8),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _balanceVisible ? '$_balanceCfa FCFA' : '••• ••• FCFA',
                      style: const TextStyle(
                        fontFamily: 'Serif',
                        fontSize: 34,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Numéro de compte',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _accountNumber,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                const Color(0xFF10B981).withValues(alpha: 0.2),
                                const Color(0xFF10B981).withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: Color(0xFF10B981),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Vérifié',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Taux de change modernisé
              const SizedBox(height: 14),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 22),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),

              // Quick actions modernisées
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 4),
                child: Row(
                  children: [
                    for (final action in _quickActions) ...[
                      Expanded(
                        child: _QuickAction(
                          icon: action.$1,
                          label: action.$2,
                          color: action.$3,
                          onTap: () {
                            switch (action.$2) {
                              case 'Envoyer':
                                _openVoiceForService('Ci wari — Transfert');
                                break;
                              case 'Recevoir':
                                _showSnackBar('Fonctionnalité à venir');
                                break;
                              case 'Payer':
                                _showSnackBar('Fonctionnalité à venir');
                                break;
                              case 'Crédit':
                                _showSnackBar('Achat de crédit à venir');
                                break;
                            }
                          },
                        ),
                      ),
                      if (action != _quickActions.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),

              // Transactions récentes
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ko kɛlenw — Récentes',
                      style: TextStyle(
                        fontFamily: 'Serif',
                        fontSize: 17,
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          _showSnackBar('Toutes les transactions à venir'),
                      child: const Text(
                        'Tout voir',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A6CF7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4A6CF7),
                          ),
                        ),
                      )
                    : _rawTxs.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Aucune transaction pour le moment.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              for (final entry in grouped.entries) ...[
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 6, bottom: 8),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                                for (final tx in entry.value) ...[
                                  TxTile(tx: _toTxData(tx)),
                                  if (tx != entry.value.last)
                                    const SizedBox(height: 10),
                                ],
                                if (entry.key != grouped.keys.last)
                                  const SizedBox(height: 18),
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

  Widget _buildRateChip(String currency, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          currency,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '= $value',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ========== NOTIFICATION BELL ==========

class _NotificationBell extends StatelessWidget {
  final VoidCallback onTap;
  final bool hasUnread;

  const _NotificationBell({required this.onTap}) : hasUnread = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              size: 20,
              color: Color(0xFF475569),
            ),
            if (hasUnread)
              Positioned(
                top: -1,
                right: -1,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ========== QUICK ACTION MODERNISÉ ==========

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}