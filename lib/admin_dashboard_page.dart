import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Admin Dashboard ──────────────────────────────────────────────────────────
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _adminData;
  bool _isLoading = true;
  String? _error;
  String _filterStatus = 'all'; // 'all' | 'active' | 'inactive'
  String _searchQuery = '';

  late AnimationController _anim;
  late Animation<double> _fade;

  static const _bg     = Color(0xFF0B0B1E);
  static const _rose   = Color(0xFFFF6B8A);
  static const _gold   = Color(0xFFFFB347);
  static const _purple = Color(0xFF7C6FFF);
  static const _teal   = Color(0xFF4ECDC4);
  static const _green  = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _loadAdmin();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _loadAdmin() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .get();
      if (!doc.exists) throw Exception('Admin profile not found');
      setState(() {
        _adminData = doc.data();
        _isLoading = false;
      });
      _anim.forward();
    } catch (e) {
      setState(() {
        _error     = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _LogoutDialog(),
    );
    if (ok == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // ─── Toggle active/inactive ───────────────────────────────────────────────
  Future<void> _toggleUserStatus(String uid, bool currentlyActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'isActive': !currentlyActive});
      _toast(
        currentlyActive ? 'User deactivated.' : 'User activated.',
        isError: false,
      );
    } catch (_) {
      _toast('Failed to update status.', isError: true);
    }
  }

  // ─── NEW: Delete user ─────────────────────────────────────────────────────
  Future<void> _deleteUser(String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDeleteDialog(name: name),
    );
    if (confirmed != true) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      _toast('$name has been deleted.', isError: false);
    } catch (_) {
      _toast('Failed to delete user.', isError: true);
    }
  }

  // ─── NEW: Edit user profile ───────────────────────────────────────────────
  Future<void> _editUser(
      String uid, Map<String, dynamic> data) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditUserSheet(uid: uid, data: data),
    );
  }

  // ─── NEW: Show user detail popup ──────────────────────────────────────────
  void _showUserDetail(String uid, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailSheet(uid: uid, data: data),
    );
  }

  void _toast(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 17,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style:
                const TextStyle(fontSize: 13.5, color: Colors.white),
                overflow: TextOverflow.ellipsis,
                maxLines: 2),
          ),
        ],
      ),
      backgroundColor:
      isError ? const Color(0xFFD32F2F) : const Color(0xFF388E3C),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.3, -0.9),
                radius: 1.5,
                colors: [Color(0xFF2B0A1A), _bg],
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child:
            _GlowBlob(color: _rose.withValues(alpha: 0.16), size: 260),
          ),
          Positioned(
            bottom: 100,
            left: -70,
            child:
            _GlowBlob(color: _gold.withValues(alpha: 0.10), size: 220),
          ),
          CustomPaint(
            size: Size(size.width, size.height),
            painter: _DotGridPainter(),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(
                    valueColor:
                    AlwaysStoppedAnimation<Color>(_rose),
                    strokeWidth: 2.2))
                : _error != null
                ? _buildError()
                : FadeTransition(
                opacity: _fade, child: _buildContent()),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: Colors.white30, size: 56),
            const SizedBox(height: 16),
            Text(_error ?? 'Something went wrong',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14)),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _loadAdmin();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _rose,
                side: const BorderSide(color: _rose),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final name     = _adminData?['name']  as String? ?? 'Admin';
    final email    = _adminData?['email'] as String? ?? '';
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildAppBar(initials)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _buildAdminBanner(name, email, initials),
                const SizedBox(height: 24),
                _buildSectionLabel('OVERVIEW'),
                const SizedBox(height: 14),
                _buildStatsRow(),
                const SizedBox(height: 24),

                // ── NEW: Analytics Chart ──────────────────────────
                _buildSectionLabel('ACTIVITY ANALYTICS'),
                const SizedBox(height: 14),
                _ActivityAnalyticsCard(),
                const SizedBox(height: 24),

                _buildSectionLabel('REGISTERED USERS'),
                const SizedBox(height: 14),
                _buildFilterTabs(),
                const SizedBox(height: 10),

                // ── NEW: Search bar ───────────────────────────────
                _buildSearchBar(),
                const SizedBox(height: 14),
                _buildUsersList(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────────────────
  Widget _buildAppBar(String initials) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [_rose, Color(0xFFCC3D5E)]),
              boxShadow: [
                BoxShadow(
                    color: _rose.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 19),
          ),
          const SizedBox(width: 10),
          Text('Admin Panel',
              style: GoogleFonts.syne(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _rose.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _rose.withValues(alpha: 0.30)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_rounded,
                    color: _rose, size: 12),
                const SizedBox(width: 4),
                Text('ADMIN',
                    style: GoogleFonts.dmSans(
                        color: _rose,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _signOut,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _rose.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                Border.all(color: _rose.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.logout_rounded,
                      color: _rose, size: 14),
                  const SizedBox(width: 4),
                  Text('Logout',
                      style: GoogleFonts.dmSans(
                          color: _rose,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Admin Banner ─────────────────────────────────────────────────────────
  Widget _buildAdminBanner(
      String name, String email, String initials) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _rose.withValues(alpha: 0.22),
            _gold.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _rose.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [_rose, Color(0xFFCC3D5E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              boxShadow: [
                BoxShadow(
                    color: _rose.withValues(alpha: 0.40),
                    blurRadius: 14,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Center(
              child: Text(initials,
                  style: GoogleFonts.syne(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, ${name.split(' ').first} 👋',
                    style: GoogleFonts.syne(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(email,
                    style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12.5),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _gold.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded,
                          color: _gold, size: 12),
                      const SizedBox(width: 4),
                      Text('Super Administrator',
                          style: GoogleFonts.dmSans(
                              color: _gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(label,
        style: GoogleFonts.dmSans(
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3));
  }

  // ─── Stats Row ────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'user')
          .snapshots(),
      builder: (ctx, snap) {
        final docs     = snap.data?.docs ?? [];
        final total    = docs.length;
        final active   = docs
            .where((d) =>
        (d.data() as Map<String, dynamic>)['isActive'] != false)
            .length;
        final inactive = total - active;
        // NEW: count online users (lastSeen within 2 minutes)
        final now      = DateTime.now();
        final online   = docs.where((d) {
          final ts = (d.data() as Map<String, dynamic>)['lastSeen'];
          if (ts == null) return false;
          final last = (ts as Timestamp).toDate();
          return now.difference(last).inMinutes < 2;
        }).length;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                      label: 'Total',
                      value: total.toString(),
                      icon: Icons.people_rounded,
                      color: _purple),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                      label: 'Active',
                      value: active.toString(),
                      icon: Icons.check_circle_rounded,
                      color: _green),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                      label: 'Inactive',
                      value: inactive.toString(),
                      icon: Icons.cancel_rounded,
                      color: _rose),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // NEW: Online Now stat card (full-width)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _teal.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.wifi_tethering_rounded,
                        color: _teal, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text('Online Right Now',
                      style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13)),
                  const Spacer(),
                  // Pulsing dot
                  _PulsingDot(color: _teal),
                  const SizedBox(width: 8),
                  Text(online.toString(),
                      style: GoogleFonts.syne(
                          color: _teal,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  Text('  users',
                      style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 12)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Filter Tabs ──────────────────────────────────────────────────────────
  Widget _buildFilterTabs() {
    final tabs = [
      {'key': 'all',      'label': 'All Users'},
      {'key': 'active',   'label': 'Active'},
      {'key': 'inactive', 'label': 'Inactive'},
    ];

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border:
        Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: tabs.map((t) {
          final key      = t['key']!;
          final label    = t['label']!;
          final selected = _filterStatus == key;
          final color    = key == 'active'
              ? _green
              : key == 'inactive'
              ? _rose
              : _purple;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _filterStatus = key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.20)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: selected
                      ? Border.all(
                      color: color.withValues(alpha: 0.40))
                      : null,
                ),
                child: Center(
                  child: Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: selected
                          ? color
                          : Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── NEW: Search Bar ──────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border:
        Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        style: GoogleFonts.dmSans(
            color: Colors.white, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Search by name or email…',
          hintStyle: GoogleFonts.dmSans(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13.5),
          prefixIcon: Icon(Icons.search_rounded,
              color: Colors.white.withValues(alpha: 0.35), size: 18),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  // ─── Users List ───────────────────────────────────────────────────────────
  Widget _buildUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'user')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(
                  valueColor:
                  AlwaysStoppedAnimation<Color>(_rose),
                  strokeWidth: 2),
            ),
          );
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _emptyState('No users registered yet.');
        }

        var docs = snap.data!.docs;

        // Filter by status
        if (_filterStatus == 'active') {
          docs = docs
              .where((d) =>
          (d.data() as Map<String, dynamic>)['isActive'] !=
              false)
              .toList();
        } else if (_filterStatus == 'inactive') {
          docs = docs
              .where((d) =>
          (d.data() as Map<String, dynamic>)['isActive'] ==
              false)
              .toList();
        }

        // NEW: Filter by search query
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          docs = docs.where((d) {
            final data  = d.data() as Map<String, dynamic>;
            final name  = (data['name']  as String? ?? '').toLowerCase();
            final email = (data['email'] as String? ?? '').toLowerCase();
            return name.contains(q) || email.contains(q);
          }).toList();
        }

        if (docs.isEmpty) {
          return _emptyState(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery".'
                : _filterStatus == 'active'
                ? 'No active users.'
                : 'No inactive users.',
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            children: List.generate(docs.length, (i) {
              final data     = docs[i].data() as Map<String, dynamic>;
              final uid      = docs[i].id;
              final name     = data['name']   as String? ?? 'User';
              final email    = data['email']  as String? ?? '';
              final mobile   = data['mobile'] as String? ?? '—';
              final isActive = data['isActive'] != false;

              // NEW: Real-time online status
              final ts       = data['lastSeen'];
              final isOnline = ts != null &&
                  DateTime.now()
                      .difference((ts as Timestamp).toDate())
                      .inMinutes <
                      2;

              final initials = name
                  .split(' ')
                  .take(2)
                  .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
                  .join();

              final avatarColors = [_purple, _teal, _gold, _rose];
              final avatarColor  =
              avatarColors[i % avatarColors.length];

              return Column(
                children: [
                  InkWell(
                    onTap: () => _showUserDetail(uid, data),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // ── Avatar with online ring ──────────────
                          Stack(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: avatarColor
                                      .withValues(alpha: 0.16),
                                  // NEW: online ring
                                  border: Border.all(
                                    color: isOnline
                                        ? _teal.withValues(alpha: 0.8)
                                        : avatarColor
                                        .withValues(alpha: 0.30),
                                    width: isOnline ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Text(initials,
                                      style: GoogleFonts.syne(
                                          color: avatarColor,
                                          fontSize: 14,
                                          fontWeight:
                                          FontWeight.w800)),
                                ),
                              ),
                              // Status dot (active/inactive)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOnline
                                        ? _teal
                                        : isActive
                                        ? _green
                                        : _rose,
                                    border: Border.all(
                                        color:
                                        const Color(0xFF0B0B1E),
                                        width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),

                          // ── Info ─────────────────────────────────
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(name,
                                          style: GoogleFonts.dmSans(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight:
                                              FontWeight.w600),
                                          overflow:
                                          TextOverflow.ellipsis),
                                    ),
                                    const SizedBox(width: 6),
                                    // NEW: Online badge
                                    if (isOnline)
                                      Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 6,
                                            vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _teal.withValues(
                                              alpha: 0.15),
                                          borderRadius:
                                          BorderRadius.circular(
                                              20),
                                          border: Border.all(
                                              color: _teal.withValues(
                                                  alpha: 0.40)),
                                        ),
                                        child: Row(
                                          mainAxisSize:
                                          MainAxisSize.min,
                                          children: [
                                            Container(
                                                width: 5,
                                                height: 5,
                                                decoration:
                                                BoxDecoration(
                                                  shape:
                                                  BoxShape.circle,
                                                  color: _teal,
                                                )),
                                            const SizedBox(width: 4),
                                            Text('Online',
                                                style:
                                                GoogleFonts.dmSans(
                                                    color: _teal,
                                                    fontSize: 9.5,
                                                    fontWeight:
                                                    FontWeight
                                                        .w700)),
                                          ],
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 7,
                                            vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? _green.withValues(
                                              alpha: 0.14)
                                              : _rose.withValues(
                                              alpha: 0.14),
                                          borderRadius:
                                          BorderRadius.circular(
                                              20),
                                          border: Border.all(
                                            color: isActive
                                                ? _green.withValues(
                                                alpha: 0.35)
                                                : _rose.withValues(
                                                alpha: 0.35),
                                          ),
                                        ),
                                        child: Text(
                                          isActive
                                              ? 'Active'
                                              : 'Inactive',
                                          style: GoogleFonts.dmSans(
                                              color: isActive
                                                  ? _green
                                                  : _rose,
                                              fontSize: 10,
                                              fontWeight:
                                              FontWeight.w700),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(email,
                                    style: GoogleFonts.dmSans(
                                        color: Colors.white
                                            .withValues(alpha: 0.42),
                                        fontSize: 12),
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 1),
                                Text(mobile,
                                    style: GoogleFonts.dmSans(
                                        color: Colors.white
                                            .withValues(alpha: 0.30),
                                        fontSize: 11.5)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // ── Action buttons (edit / delete) ────────
                          Column(
                            children: [
                              // Edit button
                              GestureDetector(
                                onTap: () => _editUser(uid, data),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  margin: const EdgeInsets.only(
                                      bottom: 6),
                                  decoration: BoxDecoration(
                                    color: _purple
                                        .withValues(alpha: 0.14),
                                    borderRadius:
                                    BorderRadius.circular(9),
                                    border: Border.all(
                                        color: _purple
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: const Icon(
                                      Icons.edit_rounded,
                                      color: _purple,
                                      size: 15),
                                ),
                              ),
                              // Delete button
                              GestureDetector(
                                onTap: () =>
                                    _deleteUser(uid, name),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color:
                                    _rose.withValues(alpha: 0.14),
                                    borderRadius:
                                    BorderRadius.circular(9),
                                    border: Border.all(
                                        color: _rose
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: const Icon(
                                      Icons.delete_rounded,
                                      color: _rose,
                                      size: 15),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(width: 8),

                          // ── Toggle Switch ─────────────────────────
                          GestureDetector(
                            onTap: () => _showStatusConfirm(
                                uid, name, isActive),
                            child: AnimatedContainer(
                              duration:
                              const Duration(milliseconds: 250),
                              width: 48,
                              height: 26,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                borderRadius:
                                BorderRadius.circular(13),
                                color: isActive
                                    ? _green
                                    : Colors.white
                                    .withValues(alpha: 0.12),
                                border: Border.all(
                                  color: isActive
                                      ? _green.withValues(alpha: 0.6)
                                      : Colors.white
                                      .withValues(alpha: 0.15),
                                ),
                              ),
                              child: AnimatedAlign(
                                duration:
                                const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                                alignment: isActive
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i < docs.length - 1)
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.05),
                      margin: const EdgeInsets.only(left: 72),
                    ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  // ─── Status confirm dialog ────────────────────────────────────────────────
  void _showStatusConfirm(
      String uid, String name, bool isActive) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14142B),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(
          isActive ? 'Deactivate User?' : 'Activate User?',
          style: GoogleFonts.syne(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800),
        ),
        content: Text(
          isActive
              ? '$name will be marked as inactive and will not be able to access the app.'
              : '$name will be marked as active and regain access.',
          style: GoogleFonts.dmSans(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13.5,
              height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(
                    color: Colors.white54,
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _toggleUserStatus(uid, isActive);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? _rose : _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(
              isActive ? 'Deactivate' : 'Activate',
              style: GoogleFonts.syne(
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded,
              color: Colors.white.withValues(alpha: 0.3), size: 48),
          const SizedBox(height: 12),
          Text(msg,
              style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14)),
        ],
      ),
    );
  }
}

// ─── NEW: Activity Analytics Card ─────────────────────────────────────────────
class _ActivityAnalyticsCard extends StatelessWidget {
  static const _bg     = Color(0xFF0B0B1E);
  static const _rose   = Color(0xFFFF6B8A);
  static const _teal   = Color(0xFF4ECDC4);
  static const _purple = Color(0xFF7C6FFF);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'user')
          .snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];

        // Build daily login counts from lastSeen for the past 7 days
        final now    = DateTime.now();
        final counts = List<int>.filled(7, 0);
        for (final d in docs) {
          final ts = (d.data() as Map<String, dynamic>)['lastSeen'];
          if (ts == null) continue;
          final dt   = (ts as Timestamp).toDate();
          final diff = now.difference(dt).inDays;
          if (diff >= 0 && diff < 7) counts[6 - diff]++;
        }

        final maxCount = counts.reduce((a, b) => a > b ? a : b);
        final days     = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final today    = now.weekday - 1; // 0=Mon … 6=Sun

        // Usage breakdown from 'usage' field (0.0–1.0)
        double totalUsage = 0;
        int usageCount    = 0;
        for (final d in docs) {
          final u = (d.data() as Map<String, dynamic>)['usage'];
          if (u != null) {
            totalUsage += (u as num).toDouble();
            usageCount++;
          }
        }
        final avgUsage =
        usageCount > 0 ? totalUsage / usageCount : 0.0;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _purple.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.bar_chart_rounded,
                        color: _purple, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text('Last 7-Day Logins',
                      style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 18),

              // Bar chart
              SizedBox(
                height: 100,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final isToday = i == today;
                    final ratio   = maxCount > 0
                        ? counts[i] / maxCount
                        : 0.0;
                    final barColor = isToday ? _rose : _purple;

                    return Expanded(
                      child: Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(counts[i].toString(),
                                style: GoogleFonts.dmSans(
                                    color: isToday
                                        ? _rose
                                        : Colors.white
                                        .withValues(alpha: 0.35),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration:
                              const Duration(milliseconds: 600),
                              curve: Curves.easeOut,
                              height: (ratio * 70).clamp(4.0, 70.0),
                              decoration: BoxDecoration(
                                color: barColor
                                    .withValues(alpha: isToday ? 0.85 : 0.40),
                                borderRadius:
                                const BorderRadius.vertical(
                                    top: Radius.circular(5)),
                                border: Border.all(
                                    color: barColor
                                        .withValues(alpha: 0.5),
                                    width: 0.5),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(days[i],
                                style: GoogleFonts.dmSans(
                                    color: isToday
                                        ? _rose
                                        : Colors.white
                                        .withValues(alpha: 0.35),
                                    fontSize: 10,
                                    fontWeight: isToday
                                        ? FontWeight.w700
                                        : FontWeight.w400)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 18),
              Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06)),
              const SizedBox(height: 14),

              // Avg usage bar
              Row(
                children: [
                  const Icon(Icons.data_usage_rounded,
                      color: _teal, size: 14),
                  const SizedBox(width: 6),
                  Text('Avg App Usage',
                      style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12)),
                  const Spacer(),
                  Text('${(avgUsage * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.syne(
                          color: _teal,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: avgUsage,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor:
                  const AlwaysStoppedAnimation<Color>(_teal),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── NEW: User Detail Bottom Sheet ────────────────────────────────────────────
class _UserDetailSheet extends StatelessWidget {
  final String             uid;
  final Map<String, dynamic> data;

  static const _bg     = Color(0xFF14142B);
  static const _rose   = Color(0xFFFF6B8A);
  static const _gold   = Color(0xFFFFB347);
  static const _purple = Color(0xFF7C6FFF);
  static const _teal   = Color(0xFF4ECDC4);
  static const _green  = Color(0xFF4CAF50);

  const _UserDetailSheet({required this.uid, required this.data});

  @override
  Widget build(BuildContext context) {
    final name     = data['name']   as String? ?? 'User';
    final email    = data['email']  as String? ?? '';
    final mobile   = data['mobile'] as String? ?? '—';
    final age      = data['age']    as int?    ?? 0;
    final isActive = data['isActive'] != false;
    final usage    = ((data['usage'] as num?)?.toDouble() ?? 0.0);
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();

    // Firestore activity log stream
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
                children: [
                  // Avatar + name
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _purple.withValues(alpha: 0.16),
                          border: Border.all(
                              color: _purple.withValues(alpha: 0.4),
                              width: 1.5),
                        ),
                        child: Center(
                          child: Text(initials,
                              style: GoogleFonts.syne(
                                  color: _purple,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: GoogleFonts.syne(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? _green.withValues(alpha: 0.14)
                                        : _rose.withValues(alpha: 0.14),
                                    borderRadius:
                                    BorderRadius.circular(20),
                                    border: Border.all(
                                        color: isActive
                                            ? _green.withValues(
                                            alpha: 0.4)
                                            : _rose.withValues(
                                            alpha: 0.4)),
                                  ),
                                  child: Text(
                                    isActive ? 'Active' : 'Inactive',
                                    style: GoogleFonts.dmSans(
                                        color: isActive
                                            ? _green
                                            : _rose,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Info grid
                  _detailCard(children: [
                    _infoRow(Icons.email_rounded,    'Email',  email),
                    _divider(),
                    _infoRow(Icons.phone_rounded,    'Mobile', mobile),
                    _divider(),
                    _infoRow(Icons.cake_rounded,     'Age',    '$age yrs'),
                    _divider(),
                    _infoRow(Icons.fingerprint_rounded, 'UID', uid,
                        small: true),
                  ]),

                  const SizedBox(height: 16),

                  // Usage
                  _detailCard(children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.data_usage_rounded,
                                  color: _teal, size: 15),
                              const SizedBox(width: 6),
                              Text('App Usage',
                                  style: GoogleFonts.dmSans(
                                      color: Colors.white
                                          .withValues(alpha: 0.55),
                                      fontSize: 12.5)),
                              const Spacer(),
                              Text(
                                '${(usage * 100).toStringAsFixed(0)}%',
                                style: GoogleFonts.syne(
                                    color: _teal,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: usage,
                              minHeight: 8,
                              backgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                              valueColor:
                              const AlwaysStoppedAnimation<Color>(
                                  _teal),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // Activity log
                  Text('Activity Log',
                      style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.3)),
                  const SizedBox(height: 10),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('activityLog')
                        .orderBy('timestamp', descending: true)
                        .limit(10)
                        .snapshots(),
                    builder: (ctx2, logSnap) {
                      final logs =
                          logSnap.data?.docs ?? [];

                      if (logs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withValues(alpha: 0.04),
                            borderRadius:
                            BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white
                                    .withValues(alpha: 0.07)),
                          ),
                          child: Center(
                            child: Text(
                              'No activity recorded yet.',
                              style: GoogleFonts.dmSans(
                                  color: Colors.white
                                      .withValues(alpha: 0.35),
                                  fontSize: 13),
                            ),
                          ),
                        );
                      }

                      return _detailCard(
                        children: List.generate(logs.length, (i) {
                          final log = logs[i].data()
                          as Map<String, dynamic>;
                          final action =
                              log['action'] as String? ?? 'Action';
                          final ts    = log['timestamp'] as Timestamp?;
                          final dt    = ts?.toDate();
                          final timeStr = dt != null
                              ? _fmt(dt)
                              : '—';

                          return Column(
                            children: [
                              Padding(
                                padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _gold.withValues(
                                            alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(action,
                                          style:
                                          GoogleFonts.dmSans(
                                              color: Colors
                                                  .white
                                                  .withValues(
                                                  alpha: 0.75),
                                              fontSize: 13)),
                                    ),
                                    Text(timeStr,
                                        style: GoogleFonts.dmSans(
                                            color: Colors.white
                                                .withValues(
                                                alpha: 0.3),
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              if (i < logs.length - 1)
                                Container(
                                  height: 1,
                                  margin: const EdgeInsets.only(
                                      left: 31),
                                  color: Colors.white
                                      .withValues(alpha: 0.05),
                                ),
                            ],
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inHours < 1)    return '${diff.inMinutes}m ago';
    if (diff.inDays < 1)     return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _detailCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border:
        Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => Container(
    height: 1,
    margin: const EdgeInsets.only(left: 44),
    color: Colors.white.withValues(alpha: 0.05),
  );

  Widget _infoRow(IconData icon, String label, String value,
      {bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Icon(icon,
              color: Colors.white.withValues(alpha: 0.35),
              size: 16),
          const SizedBox(width: 10),
          Text(label,
              style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12.5)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: small ? 10.5 : 13,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
        ],
      ),
    );
  }
}

// ─── NEW: Edit User Bottom Sheet ──────────────────────────────────────────────
class _EditUserSheet extends StatefulWidget {
  final String             uid;
  final Map<String, dynamic> data;

  const _EditUserSheet({required this.uid, required this.data});

  @override
  State<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<_EditUserSheet> {
  static const _bg     = Color(0xFF14142B);
  static const _rose   = Color(0xFFFF6B8A);
  static const _purple = Color(0xFF7C6FFF);

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _ageCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl   = TextEditingController(
        text: widget.data['name']   as String? ?? '');
    _emailCtrl  = TextEditingController(
        text: widget.data['email']  as String? ?? '');
    _mobileCtrl = TextEditingController(
        text: widget.data['mobile'] as String? ?? '');
    _ageCtrl    = TextEditingController(
        text: (widget.data['age'] ?? '').toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update({
        'name':   _nameCtrl.text.trim(),
        'email':  _emailCtrl.text.trim(),
        'mobile': _mobileCtrl.text.trim(),
        'age':    int.tryParse(_ageCtrl.text.trim()) ?? 0,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Profile updated.',
              style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF388E3C),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to update.',
              style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Edit User Profile',
                style: GoogleFonts.syne(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Changes are saved to Firestore immediately.',
              style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 12),
            ),
            const SizedBox(height: 22),
            _editField('Full Name', _nameCtrl,
                Icons.person_rounded),
            const SizedBox(height: 14),
            _editField('Email', _emailCtrl,
                Icons.email_rounded,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 14),
            _editField('Mobile', _mobileCtrl,
                Icons.phone_rounded,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 14),
            _editField('Age', _ageCtrl, Icons.cake_rounded,
                keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(
                          color: Colors.white
                              .withValues(alpha: 0.15)),
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Cancel',
                        style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                            color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2))
                        : Text('Save Changes',
                        style: GoogleFonts.syne(
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField(
      String label,
      TextEditingController ctrl,
      IconData icon, {
        TextInputType keyboardType = TextInputType.text,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            style: GoogleFonts.dmSans(
                color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: Icon(icon,
                  color: Colors.white.withValues(alpha: 0.30),
                  size: 18),
              border: InputBorder.none,
              contentPadding:
              const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── NEW: Confirm Delete Dialog ───────────────────────────────────────────────
class _ConfirmDeleteDialog extends StatelessWidget {
  final String name;

  static const _rose = Color(0xFFFF6B8A);

  const _ConfirmDeleteDialog({required this.name});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF14142B),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _rose.withValues(alpha: 0.12),
                border:
                Border.all(color: _rose.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  color: _rose, size: 26),
            ),
            const SizedBox(height: 18),
            Text('Delete User?',
                style: GoogleFonts.syne(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              '$name will be permanently removed from Firestore. This cannot be undone.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13.5,
                  height: 1.5),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(
                          color: Colors.white
                              .withValues(alpha: 0.15)),
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Cancel',
                        style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                            color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _rose,
                      foregroundColor: Colors.white,
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('Delete',
                        style: GoogleFonts.syne(
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
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

// ─── NEW: Pulsing Dot (online indicator) ─────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale =
        Tween<double>(begin: 0.7, end: 1.2).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
        ),
      ),
    );
  }
}

// ─── Stat Card (unchanged) ────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border:
        Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: GoogleFonts.syne(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── Logout Dialog (unchanged) ────────────────────────────────────────────────
class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();

  static const _rose = Color(0xFFFF6B8A);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF14142B),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _rose.withValues(alpha: 0.12),
                border:
                Border.all(color: _rose.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: _rose, size: 26),
            ),
            const SizedBox(height: 18),
            Text('Sign Out?',
                style: GoogleFonts.syne(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'You will need to sign in again to access the admin panel.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13.5),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(
                          color: Colors.white
                              .withValues(alpha: 0.15)),
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Cancel',
                        style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                            color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _rose,
                      foregroundColor: Colors.white,
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('Sign Out',
                        style: GoogleFonts.syne(
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
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

// ─── Decorative helpers (unchanged) ──────────────────────────────────────────
class _GlowBlob extends StatelessWidget {
  final Color  color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: color,
              blurRadius: size / 1.4,
              spreadRadius: size / 4)
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03);
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}