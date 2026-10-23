import 'package:flutter/material.dart';

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

const List<_NavItem> _items = [
  _NavItem(Icons.home_rounded, 'Accueil'),
  _NavItem(Icons.grid_view_rounded, 'Sèribi'), // Services
  _NavItem(Icons.mic_none_rounded, ''), // bouton micro central
  _NavItem(Icons.receipt_long_rounded, 'Kunnafoni'), // Historique
  _NavItem(Icons.person_rounded, 'Profil'),
];

class BottomNavbar extends StatelessWidget {
  /// Index de l'onglet actif parmi les 4 onglets réels : 0=Accueil, 1=Services, 2=Historique, 3=Profil.
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onMicTap;

  const BottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onMicTap,
  });

  // Convertit l'index d'item de navbar (0,1,3,4 — 2 étant le micro) en index d'onglet (0..3).
  static int _tabIndexOf(int navItemIndex) => navItemIndex > 2 ? navItemIndex - 1 : navItemIndex;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 18,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            if (i == 2) {
              return GestureDetector(
                onTap: onMicTap,
                child: Container(
                  width: 56,
                  height: 56,
                  margin: const EdgeInsets.only(top: 0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF4A6CF7),
                        Color(0xFF6B4CF7),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A6CF7).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: const Color(0xFF6B4CF7).withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              );
            }
            final tabIndex = _tabIndexOf(i);
            final active = tabIndex == currentIndex;
            return GestureDetector(
              onTap: () => onTabSelected(tabIndex),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _items[i].icon,
                      size: 24,
                      color: active 
                        ? const Color(0xFF4A6CF7) 
                        : const Color(0xFF9CA3AF),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 3,
                      width: active ? 20 : 0,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFF4A6CF7),
                            Color(0xFF6B4CF7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      _items[i].label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active 
                          ? const Color(0xFF4A6CF7) 
                          : const Color(0xFF9CA3AF),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}