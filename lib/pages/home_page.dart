import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_page.dart';

// ─── Home Page (Navigation Shell) ────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  static const Color _accent = Color(0xFF7C6FFF);

  late AnimationController _navAnim;
  late Animation<double> _navFade;

  static const List<Widget> _screens = <Widget>[
    DashboardPage(),
    _ExplorePage(),
    _ProfilePage(),
  ];

  static const List<_NavItem> _navItems = <_NavItem>[
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Dashboard',
    ),
    _NavItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      label: 'Explore',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _navAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _navFade = CurvedAnimation(parent: _navAnim, curve: Curves.easeOut);
    _navAnim.forward();
  }

  @override
  void dispose() {
    _navAnim.dispose();
    super.dispose();
  }

  void _onNavTap(int i) {
    if (i == _selectedIndex) return;
    setState(() => _selectedIndex = i);
    _navAnim.reset();
    _navAnim.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: FadeTransition(
        opacity: _navFade,
        child: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D20),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List<Widget>.generate(_navItems.length, (int i) {
              final bool isSelected = i == _selectedIndex;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onNavTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _accent.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isSelected
                              ? _navItems[i].activeIcon
                              : _navItems[i].icon,
                          key: ValueKey<bool>(isSelected),
                          color: isSelected ? _accent : Colors.white30,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: isSelected ? _accent : Colors.white30,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                        child: Text(_navItems[i].label),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Nav Item Model ───────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// ─── Explore Page ─────────────────────────────────────────────────────────────
class _ExplorePage extends StatelessWidget {
  const _ExplorePage();

  static const Color _accent = Color(0xFF7C6FFF);
  static const Color _teal   = Color(0xFF4ECDC4);
  static const Color _rose   = Color(0xFFFF6B8A);
  static const Color _amber  = Color(0xFFFFB347);

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.5, -0.6),
              radius: 1.3,
              colors: <Color>[Color(0xFF14103A), Color(0xFF0A0A1A)],
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          right: -80,
          child: _Glow(color: _teal.withValues(alpha: 0.10), size: 220),
        ),
        CustomPaint(
          size: Size(size.width, size.height),
          painter: _DotGridPainter(),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 24),
                const Text(
                  'Explore',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Discover features & updates',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: 16),
                      Icon(
                        Icons.search_rounded,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Search...',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _sectionLabel('FEATURED'),
                const SizedBox(height: 14),
                ..._featureCards(),
                const SizedBox(height: 28),
                _sectionLabel('CATEGORIES'),
                const SizedBox(height: 14),
                _categoryGrid(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.4),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  List<Widget> _featureCards() {
    const List<_FeatureData> items = <_FeatureData>[
      _FeatureData(
        title: 'Real-time Sync',
        desc: 'Your data syncs instantly across all devices.',
        icon: Icons.sync_rounded,
        gradientStart: Color(0xFF7C6FFF),
        gradientEnd: Color(0xFF5A4FE0),
      ),
      _FeatureData(
        title: 'Smart Notifications',
        desc: 'Get personalised alerts that matter to you.',
        icon: Icons.notifications_active_outlined,
        gradientStart: Color(0xFFFF6B8A),
        gradientEnd: Color(0xFFFF4081),
      ),
      _FeatureData(
        title: 'Secure & Private',
        desc: 'End-to-end encrypted. Always.',
        icon: Icons.lock_outlined,
        gradientStart: Color(0xFF4ECDC4),
        gradientEnd: Color(0xFF00BCD4),
      ),
    ];

    return items.map((_FeatureData item) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[item.gradientStart, item.gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: item.gradientStart.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(item.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.desc,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.2),
                size: 14,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _categoryGrid() {
    const List<_CatData> cats = <_CatData>[
      _CatData(label: 'Analytics', icon: Icons.bar_chart_rounded,          color: _accent),
      _CatData(label: 'Security',  icon: Icons.verified_user_outlined,      color: _rose),
      _CatData(label: 'Messages',  icon: Icons.chat_bubble_outline_rounded, color: _teal),
      _CatData(label: 'Settings',  icon: Icons.settings_outlined,           color: _amber),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: cats.map((_CatData c) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(c.icon, color: c.color, size: 19),
                ),
                const SizedBox(width: 10),
                Text(
                  c.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Feature Data Model ───────────────────────────────────────────────────────
class _FeatureData {
  final String title;
  final String desc;
  final IconData icon;
  final Color gradientStart;
  final Color gradientEnd;

  const _FeatureData({
    required this.title,
    required this.desc,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
  });
}

// ─── Category Data Model ──────────────────────────────────────────────────────
class _CatData {
  final String label;
  final IconData icon;
  final Color color;

  const _CatData({
    required this.label,
    required this.icon,
    required this.color,
  });
}

// ─── Profile Page ─────────────────────────────────────────────────────────────
class _ProfilePage extends StatefulWidget {
  const _ProfilePage();

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  static const Color _accent = Color(0xFF7C6FFF);
  static const Color _rose   = Color(0xFFFF6B8A);
  static const Color _teal   = Color(0xFF4ECDC4);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final DocumentSnapshot<Map<String, dynamic>> doc =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted) {
      setState(() {
        _data    = doc.data();
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _LogoutDialog(),
    );
    if (ok == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.5, -0.7),
              radius: 1.2,
              colors: <Color>[Color(0xFF18103F), Color(0xFF0A0A1A)],
            ),
          ),
        ),
        CustomPaint(
          size: Size(size.width, size.height),
          painter: _DotGridPainter(),
        ),
        SafeArea(
          child: _loading
              ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_accent),
              strokeWidth: 2,
            ),
          )
              : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      'Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    _LogoutButton(onTap: _signOut),
                  ],
                ),
                const SizedBox(height: 32),
                _buildAvatar(),
                const SizedBox(height: 28),
                _buildInfoTiles(),
                const SizedBox(height: 28),
                _buildDangerZone(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    final String name     = _data?['name']  as String? ?? 'User';
    final String email    = _data?['email'] as String? ?? '';
    final String initials = name
        .split(' ')
        .take(2)
        .map((String w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();

    return Column(
      children: <Widget>[
        Stack(
          children: <Widget>[
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: <Color>[_accent, Color(0xFF5A4FE0)],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _teal,
                  border: Border.all(
                    color: const Color(0xFF0A0A1A),
                    width: 2.5,
                  ),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTiles() {
    final List<_TileData> tiles = <_TileData>[
      _TileData(Icons.badge_outlined, 'Full Name', _data?['name']?.toString()   ?? '—', _accent),
      _TileData(Icons.cake_outlined,  'Age',       _data?['age']?.toString()    ?? '—', _rose),
      _TileData(Icons.wc_outlined,    'Gender',    _data?['gender']?.toString() ?? '—', const Color(0xFFFFB347)),
      _TileData(Icons.phone_outlined, 'Mobile',    _data?['mobile']?.toString() ?? '—', _teal),
      _TileData(Icons.email_outlined, 'Email',     _data?['email']?.toString()  ?? '—', _accent),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: List<Widget>.generate(tiles.length, (int i) {
          final _TileData t = tiles[i];
          return Column(
            children: <Widget>[
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: t.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(t.icon, color: t.color, size: 17),
                ),
                title: Text(
                  t.label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  t.value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.15),
                  size: 13,
                ),
              ),
              if (i < tiles.length - 1)
                Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                  indent: 66,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      decoration: BoxDecoration(
        color: _rose.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _rose.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        onTap: _signOut,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _rose.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.logout_rounded, color: _rose, size: 17),
        ),
        title: const Text(
          'Sign Out',
          style: TextStyle(
            color: _rose,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Log out of your account',
          style: TextStyle(
            color: _rose.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          color: _rose.withValues(alpha: 0.4),
          size: 13,
        ),
      ),
    );
  }
}

// ─── Tile Data Model ──────────────────────────────────────────────────────────
class _TileData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _TileData(this.icon, this.label, this.value, this.color);
}

// ─── Logout Button ────────────────────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  static const Color _rose = Color(0xFFFF6B8A);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _rose.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _rose.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.logout_rounded, color: _rose, size: 15),
            SizedBox(width: 5),
            Text(
              'Logout',
              style: TextStyle(
                color: _rose,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Logout Dialog ────────────────────────────────────────────────────────────
class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();

  static const Color _rose = Color(0xFFFF6B8A);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF14142B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _rose.withValues(alpha: 0.12),
                border: Border.all(color: _rose.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.logout_rounded, color: _rose, size: 26),
            ),
            const SizedBox(height: 18),
            const Text(
              'Sign Out?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You'll need to sign in again to access your account.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _rose,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Decorative: Glow ─────────────────────────────────────────────────────────
class _Glow extends StatelessWidget {
  final Color color;
  final double size;

  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color,
            blurRadius: size / 1.4,
            spreadRadius: size / 4,
          ),
        ],
      ),
    );
  }
}

// ─── Decorative: Dot Grid ─────────────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    const double spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}