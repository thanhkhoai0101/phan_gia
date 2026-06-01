import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../chat/chat_list_screen.dart';
import '../contacts/contacts_screen.dart';
import '../games/screens/game_hub_screen.dart';
import '../profile/profile_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../blocs/auth/auth_state.dart';
import '../settings/settings_screen.dart';
import '../feed/feed_screen.dart';
import '../../blocs/feed/feed_bloc.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({Key? key}) : super(key: key);

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _screens = [
    const ChatListScreen(),
    _FeedTabWrapper(), // Tab Gia Đình
    const ContactsScreen(),
    const GameHubScreen(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(label: 'Nhắn tin', icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded),
    _NavItem(label: 'Gia đình', icon: Icons.feed_outlined, activeIcon: Icons.feed_rounded),
    _NavItem(label: 'Thành viên', icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded),
    _NavItem(label: 'Giải trí', icon: Icons.videogame_asset_outlined, activeIcon: Icons.videogame_asset_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = const Color(0xFFF57C00);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        key: _scaffoldKey,
        extendBodyBehindAppBar: false,
        // ─── CUSTOM APP BAR ──────────────────────────────────────────────
        appBar: _buildAppBar(context, isDark, primary),
        // ─── DRAWER ──────────────────────────────────────────────────────
        drawer: _buildDrawer(context, isDark, primary),
        // ─── BODY ────────────────────────────────────────────────────────
        body: IndexedStack(index: _currentIndex, children: _screens),
        // ─── BOTTOM NAV ──────────────────────────────────────────────────
        bottomNavigationBar: _buildBottomNav(context, isDark, primary),
      ),
    );
  }

  // ─── App Bar ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark, Color primary) {
    final bgColor = isDark ? const Color(0xFF0F1B2A) : Colors.white;
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;

    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(isDark ? 0.15 : 0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border(
            bottom: BorderSide(
              color: primary.withOpacity(0.18),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // ── Menu button ──────────────────────────────────────
                _AppBarIconButton(
                  icon: Icons.menu_rounded,
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  isDark: isDark,
                  primary: primary,
                ),
                const SizedBox(width: 12),
                // ── Logo + Title ─────────────────────────────────────
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Phan Gia',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            _navItems[_currentIndex].label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: primary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Bottom Nav ──────────────────────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context, bool isDark, Color primary) {
    final bgColor = isDark ? const Color(0xFF0F1B2A) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: primary.withOpacity(0.15),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: List.generate(_navItems.length, (i) {
              final item = _navItems[i];
              final isSelected = _currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? primary.withOpacity(0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isSelected ? item.activeIcon : item.icon,
                            key: ValueKey(isSelected),
                            color: isSelected
                                ? primary
                                : (isDark ? Colors.white38 : Colors.black38),
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                            color: isSelected
                                ? primary
                                : (isDark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 3,
                          width: isSelected ? 20 : 0,
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ─── Drawer ──────────────────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context, bool isDark, Color primary) {
    final bgColor = isDark ? const Color(0xFF0D1821) : Colors.white;

    return Drawer(
      backgroundColor: bgColor,
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final user = state is AuthAuthenticated ? state.user : null;
          return Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              Stack(
                children: [
                  // Cover background
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: primary,
                      image: user?.coverUrl != null && user!.coverUrl!.isNotEmpty
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(user.coverUrl!),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(
                                Colors.black.withOpacity(0.35),
                                BlendMode.darken,
                              ),
                            )
                          : null,
                      gradient: user?.coverUrl == null || (user?.coverUrl?.isEmpty ?? true)
                          ? const LinearGradient(
                              colors: [Color(0xFFFF9800), Color(0xFFE65100)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                    ),
                  ),
                  // Overlay gradient at bottom for readability
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.55), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  // User info
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                                ? CachedNetworkImageProvider(user.avatarUrl!)
                                : const AssetImage('assets/images/logo.png') as ImageProvider,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user?.displayName ?? 'Phan Gia',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? '',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                  shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Menu Items ──────────────────────────────────────────
              _DrawerItem(
                icon: Icons.person_rounded,
                label: 'Hồ sơ',
                isDark: isDark,
                primary: primary,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                },
              ),
              _DrawerItem(
                icon: Icons.settings_rounded,
                label: 'Cài đặt',
                isDark: isDark,
                primary: primary,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),

              const Spacer(),

              // ── Divider & Logout ────────────────────────────────────
              Divider(color: Colors.grey.withOpacity(0.2), height: 1),
              _DrawerItem(
                icon: Icons.logout_rounded,
                label: 'Đăng xuất',
                isDark: isDark,
                primary: Colors.redAccent,
                isDestructive: true,
                onTap: () => context.read<AuthBloc>().add(LogoutRequested()),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

// ─── Helper: Nav Item Data ─────────────────────────────────────────────────────
class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem({required this.label, required this.icon, required this.activeIcon});
}

// ─── Helper: AppBar Icon Button ───────────────────────────────────────────────
class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final Color primary;

  const _AppBarIconButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withOpacity(0.2)),
        ),
        child: Icon(icon, color: primary, size: 22),
      ),
    );
  }
}

// ─── Helper: Drawer Item ──────────────────────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color primary;
  final VoidCallback onTap;
  final bool isDestructive;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.primary,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: primary, size: 20),
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDestructive ? Colors.redAccent : textColor,
                  ),
                ),
                const Spacer(),
                if (!isDestructive)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white24 : Colors.black26,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Wrapper for Feed Tab ─────────────────────────────────────────────────────
class _FeedTabWrapper extends StatelessWidget {
  const _FeedTabWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return FeedScreen(currentUser: state.user);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
