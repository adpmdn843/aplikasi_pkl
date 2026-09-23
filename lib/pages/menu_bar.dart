import 'package:flutter/material.dart';

class MenuBarPKL extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const MenuBarPKL({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  // ============================================================
  // WARNA
  // ============================================================

  static const Color primaryColor =
      Color(0xFF2563EB);

  static const Color textColor =
      Color(0xFF64748B);

  static const Color backgroundColor =
      Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            10,
            12,
            10,
            8,
          ),
          child: SizedBox(
            height: 78,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // ==================================================
                // BACKGROUND MENU BAR
                // ==================================================

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildNavigationBar(
                    context,
                  ),
                ),

                // ==================================================
                // ABSENSI TENGAH
                // ==================================================

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 19,
                  child: Center(
                    child: _buildCenterAttendanceButton(
                      context,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NAVIGATION BAR
  // ============================================================

  Widget _buildNavigationBar(
    BuildContext context,
  ) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE8EDF4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.065,
            ),
            blurRadius: 22,
            spreadRadius: 0,
            offset: const Offset(
              0,
              7,
            ),
          ),
        ],
      ),
      child: Row(
        children: [
          // ======================================================
          // HOME
          // ======================================================

          Expanded(
            child: _SideMenuItem(
              icon: Icons.home_outlined,
              activeIcon:
                  Icons.home_rounded,
              label: 'Home',
              selected:
                  currentIndex == 0,
              onTap: () => onTap(0),
            ),
          ),

          // ======================================================
          // SAKU
          // ======================================================

          Expanded(
            child: _SideMenuItem(
              icon:
                  Icons.account_balance_wallet_outlined,
              activeIcon:
                  Icons.account_balance_wallet_rounded,
              label: 'Saku',
              selected:
                  currentIndex == 4,
              onTap: () => onTap(4),
            ),
          ),

          // ======================================================
          // AREA TENGAH ABSENSI
          //
          // Dikosongkan supaya tombol lingkaran berada di tengah.
          // ======================================================

          Expanded(
            child: const SizedBox(),
          ),

          // ======================================================
          // PERIZINAN
          // ======================================================

          Expanded(
            child: _SideMenuItem(
              icon:
                  Icons.assignment_outlined,
              activeIcon:
                  Icons.assignment_rounded,
              label: 'Perizinan',
              selected:
                  currentIndex == 2,
              onTap: () => onTap(2),
            ),
          ),

          // ======================================================
          // HISTORY
          // ======================================================

          Expanded(
            child: _SideMenuItem(
              icon: Icons.history_outlined,
              activeIcon:
                  Icons.history_rounded,
              label: 'History',
              selected:
                  currentIndex == 3,
              onTap: () => onTap(3),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOMBOL ABSENSI TENGAH
  // ============================================================

  Widget _buildCenterAttendanceButton(
    BuildContext context,
  ) {
    final bool selected =
        currentIndex == 1;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ======================================================
          // LINGKARAN
          // ======================================================

          AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 260,
            ),
            curve:
                Curves.easeOutCubic,
            width: selected ? 68 : 64,
            height: selected ? 68 : 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,

              // Lapisan luar
              color: Colors.white,

              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(
                    alpha: selected
                        ? 0.28
                        : 0.18,
                  ),
                  blurRadius:
                      selected ? 18 : 13,
                  spreadRadius:
                      selected ? 2 : 0,
                  offset:
                      const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding:
                  const EdgeInsets.all(4),
              child: AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 260,
                ),
                decoration:
                    BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? primaryColor
                      : const Color(
                          0xFF3B82F6,
                        ),
                  gradient:
                      const LinearGradient(
                    begin:
                        Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
                    colors: [
                      Color(0xFF3B82F6),
                      Color(0xFF2563EB),
                    ],
                  ),
                ),
                child: Icon(
                  selected
                      ? Icons
                          .access_time_filled_rounded
                      : Icons
                          .access_time_rounded,
                  color: Colors.white,
                  size: selected
                      ? 30
                      : 28,
                ),
              ),
            ),
          ),

          // ======================================================
          // LABEL ABSENSI
          // ======================================================

          const SizedBox(height: 3),

          AnimatedDefaultTextStyle(
            duration:
                const Duration(
              milliseconds: 220,
            ),
            style: TextStyle(
              fontSize:
                  selected ? 10.5 : 10,
              fontWeight:
                  selected
                      ? FontWeight.w700
                      : FontWeight.w600,
              color: selected
                  ? primaryColor
                  : textColor,
              height: 1,
            ),
            child: const Text(
              'Absensi',
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SIDE MENU ITEM
// ============================================================

class _SideMenuItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SideMenuItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const Color primaryColor =
      Color(0xFF2563EB);

  static const Color textColor =
      Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(20),
        splashColor:
            primaryColor.withValues(
          alpha: 0.08,
        ),
        highlightColor:
            primaryColor.withValues(
          alpha: 0.04,
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 5,
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            mainAxisSize:
                MainAxisSize.min,
            children: [
              // ==================================================
              // ICON
              // ==================================================

              AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 220,
                ),
                curve:
                    Curves.easeOutCubic,
                width:
                    selected ? 38 : 34,
                height:
                    selected ? 31 : 29,
                decoration:
                    BoxDecoration(
                  color: selected
                      ? const Color(
                          0xFFEAF2FF,
                        )
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration:
                        const Duration(
                      milliseconds: 180,
                    ),
                    transitionBuilder:
                        (
                          child,
                          animation,
                        ) {
                      return ScaleTransition(
                        scale: animation,
                        child: child,
                      );
                    },
                    child: Icon(
                      selected
                          ? activeIcon
                          : icon,
                      key: ValueKey(
                        selected,
                      ),
                      size:
                          selected ? 21 : 20,
                      color: selected
                          ? primaryColor
                          : textColor,
                    ),
                  ),
                ),
              ),

              // ==================================================
              // LABEL
              // ==================================================

              const SizedBox(height: 2),

              Flexible(
                child:
                    AnimatedDefaultTextStyle(
                  duration:
                      const Duration(
                    milliseconds: 180,
                  ),
                  style: TextStyle(
                    fontSize:
                        selected ? 10 : 9.5,
                    fontWeight:
                        selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                    color: selected
                        ? primaryColor
                        : textColor,
                    height: 1,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    textAlign:
                        TextAlign.center,
                  ),
                ),
              ),

              // ==================================================
              // INDICATOR
              // ==================================================

              const SizedBox(height: 2),

              AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 220,
                ),
                curve:
                    Curves.easeOutCubic,
                width:
                    selected ? 14 : 0,
                height:
                    selected ? 2.5 : 0,
                decoration:
                    BoxDecoration(
                  color: primaryColor,
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}