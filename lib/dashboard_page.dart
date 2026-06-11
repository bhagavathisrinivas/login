import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Design tokens — identical to login & profile ─────────────────────────────
abstract class _T {
  static const Color canvas   = Color(0xFF080B14);
  static const Color surface  = Color(0xFF0F1626);
  static const Color elevated = Color(0xFF16213A);

  static const Color indigo   = Color(0xFF5B6EF5);
  static const Color indigoLt = Color(0xFF8B9BFF);
  static const Color indigoDim= Color(0xFF1E245C);

  // Supporting palette — used sparingly for data encoding only
  static const Color teal     = Color(0xFF2DD4BF);
  static const Color tealDim  = Color(0xFF0D4A45);
  static const Color amber    = Color(0xFFFBBF24);
  static const Color amberDim = Color(0xFF44340A);
  static const Color rose     = Color(0xFFF43F5E);
  static const Color roseDim  = Color(0xFF4C0D1C);

  static const Color mist     = Color(0xFFAAB4C8);
  static const Color border   = Color(0xFF1F2D47);
  static const Color success  = Color(0xFF34D399);
  static const Color error    = Color(0xFFFC6B68);

  static TextStyle display(double sz,
      {Color? color, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: sz, fontWeight: w,
        color: color ?? Colors.white, letterSpacing: -0.4,
      );

  static TextStyle body(double sz,
      {Color? color, FontWeight w = FontWeight.w400}) =>
      GoogleFonts.inter(
        fontSize: sz, fontWeight: w, color: color ?? Colors.white,
      );

  static TextStyle label(double sz, {Color? color}) =>
      GoogleFonts.inter(
        fontSize: sz, fontWeight: FontWeight.w500,
        color: color ?? mist, letterSpacing: 0.1,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD PAGE
// ─────────────────────────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;

  // Staggered entrance — one controller, 6 interval animations
  late AnimationController _entranceCtrl;
  late List<Animation<double>> _stagger;

  static const _staggerCount = 6;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));

    _stagger = List.generate(_staggerCount, (i) {
      final start = i * 0.10;
      return CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(start, (start + 0.55).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic),
      );
    });

    _loadUser();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────
  Future<void> _loadUser() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not signed in.');
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      if (!doc.exists) throw Exception('Profile not found.');
      setState(() { _userData = doc.data(); _isLoading = false; });
      _entranceCtrl.forward(from: 0);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ── Sign out ─────────────────────────────────────────────────────────────────
  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Sign out?',
        body: 'You\'ll need to sign in again to access your account.',
        confirmLabel: 'Sign out',
        confirmColor: _T.rose,
      ),
    );
    if (ok == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // ── Edit profile sheet ───────────────────────────────────────────────────────
  void _openEditProfile() {
    final nameCtrl   = TextEditingController(
        text: _userData?['name']   as String? ?? '');
    final ageCtrl    = TextEditingController(
        text: (_userData?['age'] as int?)?.toString() ?? '');
    final mobileCtrl = TextEditingController(
        text: _userData?['mobile'] as String? ?? '');
    final formKey    = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfileSheet(
        nameCtrl:   nameCtrl,
        ageCtrl:    ageCtrl,
        mobileCtrl: mobileCtrl,
        formKey:    formKey,
        onSaved: (name, age, mobile) async {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) return;
          await FirebaseFirestore.instance
              .collection('users').doc(uid).update({
            'name':   name,
            'age':    age,
            'mobile': mobile,
          });
          if (mounted) {
            setState(() {
              _userData?['name']   = name;
              _userData?['age']    = age;
              _userData?['mobile'] = mobile;
            });
            _showSnack('Profile updated.', isError: false);
          }
        },
      ),
    );
  }

  // ── Snack ────────────────────────────────────────────────────────────────────
  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(msg,
              style: _T.body(13.5, color: Colors.white),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
        backgroundColor: isError ? const Color(0xFF991B1B) : const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.canvas,
      body: Stack(children: [
        // Aurora blobs
        Positioned(top: -90, right: -60,
            child: _GlowBlob(color: _T.indigo.withValues(alpha: 0.13), size: 280)),
        Positioned(bottom: 120, left: -50,
            child: _GlowBlob(color: _T.teal.withValues(alpha: 0.08), size: 220)),
        // Dot grid
        Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),

        SafeArea(
          child: _isLoading
              ? _buildLoader()
              : _error != null
              ? _buildError()
              : _buildContent(),
        ),
      ]),
    );
  }

  // ── Loading ──────────────────────────────────────────────────────────────────
  Widget _buildLoader() {
    return const Center(
      child: CircularProgressIndicator(
          color: _T.indigo, strokeWidth: 2.2),
    );
  }

  // ── Error ────────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: _T.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.cloud_off_rounded,
                  color: _T.error.withValues(alpha: 0.7), size: 26),
            ),
            const SizedBox(height: 16),
            Text('Something went wrong', style: _T.display(17)),
            const SizedBox(height: 8),
            Text(_error ?? '', style: _T.label(13.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _loadUser,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _T.indigoLt,
                  side: BorderSide(color: _T.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main content ─────────────────────────────────────────────────────────────
  Widget _buildContent() {
    final data     = _userData!;
    final name     = data['name']     as String? ?? 'User';
    final email    = data['email']    as String? ?? '';
    final mobile   = data['mobile']   as String? ?? '';
    final age      = data['age'];
    final isActive = data['isActive'] as bool?   ?? true;
    final usage    = (data['usage'] as num?)?.toDouble() ?? 0.0;
    final initials = name.trim().split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .take(2).join();
    final firstName = name.split(' ').first;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
            child: _buildTopBar(firstName, initials)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero banner ─────────────────────────────────────────────
                _FadeSlide(
                  anim: _stagger[0],
                  child: _HeroBanner(
                    firstName: firstName,
                    email: email,
                    initials: initials,
                    isActive: isActive,
                    avatarUrl: data['avatarUrl'] as String? ?? '',
                    onEditProfile: _openEditProfile,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Stat row ────────────────────────────────────────────────
                _FadeSlide(
                  anim: _stagger[1],
                  child: _StatRow(usage: usage, age: age, mobile: mobile),
                ),
                const SizedBox(height: 28),

                // ── Section: Quick actions ──────────────────────────────────
                _FadeSlide(
                  anim: _stagger[2],
                  child: _SectionLabel(text: 'Quick actions'),
                ),
                const SizedBox(height: 14),
                _FadeSlide(
                  anim: _stagger[2],
                  child: _QuickActionsRow(
                    onEditProfile: _openEditProfile,
                    onProfile: () => Navigator.pushNamed(context, '/profile'),
                    onSnack: (m) => _showSnack(m, isError: false),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Section: Profile details ────────────────────────────────
                _FadeSlide(
                  anim: _stagger[3],
                  child: _SectionLabel(text: 'Account details'),
                ),
                const SizedBox(height: 14),
                _FadeSlide(
                  anim: _stagger[3],
                  child: _AccountDetailsCard(
                    name: name,
                    email: email,
                    mobile: mobile,
                    age: age,
                    isActive: isActive,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Section: Activity ───────────────────────────────────────
                _FadeSlide(
                  anim: _stagger[4],
                  child: _SectionLabel(text: 'Activity'),
                ),
                const SizedBox(height: 14),
                _FadeSlide(
                  anim: _stagger[4],
                  child: const _ActivityCard(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────────
  Widget _buildTopBar(String firstName, String initials) {
    return _FadeSlide(
      anim: _stagger[0],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Row(children: [
          // Brand mark
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _T.indigoDim,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _T.indigo.withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.electric_bolt_rounded,
                color: _T.indigoLt, size: 17),
          ),
          const SizedBox(width: 10),
          Text('Nexus', style: _T.display(17)),
          const Spacer(),

          // Notification bell
          _TopBarBtn(
            icon: Icons.notifications_outlined,
            badge: true,
            onTap: () => _showSnack('No new notifications.', isError: false),
          ),
          const SizedBox(width: 8),

          // Sign out
          GestureDetector(
            onTap: _signOut,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: _T.rose.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _T.rose.withValues(alpha: 0.22)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.logout_rounded,
                    color: _T.rose.withValues(alpha: 0.85), size: 14),
                const SizedBox(width: 5),
                Text('Sign out',
                    style: _T.body(12,
                        color: _T.rose.withValues(alpha: 0.85),
                        w: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final String firstName;
  final String email;
  final String initials;
  final String avatarUrl;
  final bool   isActive;
  final VoidCallback onEditProfile;

  const _HeroBanner({
    required this.firstName,
    required this.email,
    required this.initials,
    required this.isActive,
    required this.avatarUrl,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.border),
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _T.indigoDim,
            border: Border.all(color: _T.indigo.withValues(alpha: 0.4),
                width: 1.5),
            boxShadow: [BoxShadow(
                color: _T.indigo.withValues(alpha: 0.22),
                blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: ClipOval(
            child: avatarUrl.isNotEmpty
                ? Image.network(avatarUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initialsView(initials))
                : _initialsView(initials),
          ),
        ),
        const SizedBox(width: 14),

        // Name + email + badge
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hey, $firstName', style: _T.display(20)),
                const SizedBox(height: 3),
                Text(email,
                    style: _T.label(12.5),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 9),
                // Status badge
                Row(children: [
                  _StatusBadge(active: isActive),
                ]),
              ]),
        ),

        // Edit button
        GestureDetector(
          onTap: onEditProfile,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _T.indigo.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _T.indigo.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.edit_rounded,
                color: _T.indigoLt, size: 16),
          ),
        ),
      ]),
    );
  }

  Widget _initialsView(String i) => Center(
    child: Text(i, style: _T.display(22, color: _T.indigoLt)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT ROW — three metric chips
// ─────────────────────────────────────────────────────────────────────────────
class _StatRow extends StatelessWidget {
  final double usage;
  final dynamic age;
  final String  mobile;

  const _StatRow({required this.usage, required this.age, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _StatChip(
        label: 'Usage',
        value: '${usage.toStringAsFixed(1)} GB',
        icon: Icons.data_usage_rounded,
        color: _T.indigo,
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatChip(
        label: 'Age',
        value: age != null ? age.toString() : '—',
        icon: Icons.cake_rounded,
        color: _T.teal,
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatChip(
        label: 'Mobile',
        value: mobile.isEmpty ? '—' : mobile.length > 7
            ? '${mobile.substring(0, 7)}…' : mobile,
        icon: Icons.phone_iphone_rounded,
        color: _T.amber,
      )),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: _T.display(15, w: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: _T.label(11.5)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTIONS ROW
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onEditProfile;
  final VoidCallback onProfile;
  final void Function(String) onSnack;

  const _QuickActionsRow({
    required this.onEditProfile,
    required this.onProfile,
    required this.onSnack,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QA(icon: Icons.person_rounded,    label: 'Edit info',
          color: _T.indigo,  onTap: onEditProfile),
      _QA(icon: Icons.lock_reset_rounded, label: 'Password',
          color: _T.teal,   onTap: onProfile),
      _QA(icon: Icons.shield_rounded,    label: 'Security',
          color: _T.amber,  onTap: () => onSnack('Coming soon.')),
      _QA(icon: Icons.headset_rounded,   label: 'Support',
          color: _T.rose,   onTap: () => onSnack('Coming soon.')),
    ];

    return Row(
      children: List.generate(actions.length, (i) {
        final a = actions[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < actions.length - 1 ? 10 : 0),
            child: _QATile(qa: a),
          ),
        );
      }),
    );
  }
}

class _QA {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _QA({required this.icon, required this.label,
    required this.color, required this.onTap});
}

class _QATile extends StatelessWidget {
  final _QA qa;
  const _QATile({required this.qa});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: qa.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _T.border),
        ),
        child: Column(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: qa.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(qa.icon, color: qa.color, size: 18),
          ),
          const SizedBox(height: 7),
          Text(qa.label,
              style: _T.body(11, color: _T.mist, w: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNT DETAILS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _AccountDetailsCard extends StatelessWidget {
  final String  name;
  final String  email;
  final String  mobile;
  final dynamic age;
  final bool    isActive;

  const _AccountDetailsCard({
    required this.name,
    required this.email,
    required this.mobile,
    required this.age,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.person_outline_rounded,
            label: 'Name',
            value: name.isEmpty ? '—' : name,
            isFirst: true,
          ),
          _Hairline(),
          _DetailRow(
            icon: Icons.alternate_email_rounded,
            label: 'Email',
            value: email.isEmpty ? '—' : email,
          ),
          _Hairline(),
          _DetailRow(
            icon: Icons.phone_iphone_rounded,
            label: 'Mobile',
            value: mobile.isEmpty ? '—' : mobile,
          ),
          _Hairline(),
          _DetailRow(
            icon: Icons.cake_rounded,
            label: 'Age',
            value: age != null ? age.toString() : '—',
          ),
          _Hairline(),
          _DetailRow(
            icon: Icons.radio_button_checked_rounded,
            label: 'Status',
            value: isActive ? 'Active' : 'Inactive',
            valueColor: isActive ? _T.success : _T.error,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color?   valueColor;
  final bool     isFirst;
  final bool     isLast;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isFirst = false,
    this.isLast  = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        isFirst ? 16 : 13,
        16,
        isLast  ? 16 : 13,
      ),
      child: Row(children: [
        Icon(icon, size: 17,
            color: Colors.white.withValues(alpha: 0.28)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: _T.label(13.5)),
        ),
        Flexible(
          child: Text(
            value,
            style: _T.body(13.5,
                color: valueColor ?? Colors.white,
                w: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ]),
    );
  }
}

class _Hairline extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(color: _T.border, thickness: 1, height: 1);
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  const _ActivityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              Text('Recent activity',
                  style: _T.body(14, w: FontWeight.w600)),
              const Spacer(),
              Text('All caught up',
                  style: _T.label(12.5,
                      color: _T.mist.withValues(alpha: 0.55))),
            ]),
          ),
          Divider(color: _T.border, thickness: 1, height: 1),
          _ActivityRow(
            icon: Icons.login_rounded,
            title: 'Account created',
            subtitle: 'Welcome to Nexus',
            color: _T.teal,
            isFirst: true,
          ),
          Divider(color: _T.border, thickness: 1, height: 1),
          _ActivityRow(
            icon: Icons.person_rounded,
            title: 'Profile completed',
            subtitle: 'All fields filled in',
            color: _T.indigo,
          ),
          Divider(color: _T.border, thickness: 1, height: 1),
          _ActivityRow(
            icon: Icons.mark_email_read_rounded,
            title: 'Email on file',
            subtitle: 'Recovery address saved',
            color: _T.amber,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;
  final Color    color;
  final bool     isFirst;
  final bool     isLast;

  const _ActivityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.isFirst = false,
    this.isLast  = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        isFirst ? 14 : 12,
        16,
        isLast  ? 14 : 12,
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: _T.body(13.5, w: FontWeight.w600)),
            const SizedBox(height: 1),
            Text(subtitle, style: _T.label(12)),
          ],
        )),
        Icon(Icons.check_circle_rounded,
            color: color.withValues(alpha: 0.65), size: 15),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT PROFILE SHEET (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController ageCtrl;
  final TextEditingController mobileCtrl;
  final GlobalKey<FormState>  formKey;
  final Future<void> Function(String name, int? age, String mobile) onSaved;

  const _EditProfileSheet({
    required this.nameCtrl,
    required this.ageCtrl,
    required this.mobileCtrl,
    required this.formKey,
    required this.onSaved,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  bool _saving = false;

  Future<void> _submit() async {
    if (!widget.formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSaved(
        widget.nameCtrl.text.trim(),
        int.tryParse(widget.ageCtrl.text.trim()),
        widget.mobileCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save — try again.'),
          backgroundColor: Color(0xFF991B1B),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: _T.border),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 28 + bottom),
      child: Form(
        key: widget.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: _T.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _T.indigo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_rounded,
                    color: _T.indigoLt, size: 16),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Edit info', style: _T.display(18)),
                Text('Update your personal details',
                    style: _T.label(12.5)),
              ]),
            ]),
            const SizedBox(height: 24),

            // Name
            _SheetField(
              controller: widget.nameCtrl,
              label: 'Full name',
              icon: Icons.person_outline_rounded,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name is required.';
                if (v.trim().length < 2) return 'At least 2 characters.';
                return null;
              },
            ),
            const SizedBox(height: 10),

            // Age
            _SheetField(
              controller: widget.ageCtrl,
              label: 'Age',
              icon: Icons.cake_rounded,
              accentColor: _T.teal,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Age is required.';
                final a = int.tryParse(v.trim());
                if (a == null || a < 1 || a > 120) return 'Enter a valid age (1–120).';
                return null;
              },
            ),
            const SizedBox(height: 10),

            // Mobile
            _SheetField(
              controller: widget.mobileCtrl,
              label: 'Mobile number',
              icon: Icons.phone_iphone_rounded,
              accentColor: _T.amber,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onEditingComplete: _saving ? null : _submit,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                LengthLimitingTextInputFormatter(16),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Mobile is required.';
                if (v.trim().replaceAll(' ', '').length < 10) {
                  return 'Enter a valid mobile number.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _T.mist,
                      side: BorderSide(color: _T.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                    ),
                    child: Text('Cancel',
                        style: _T.body(14.5, w: FontWeight.w600,
                            color: _T.mist)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _T.indigo,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [BoxShadow(
                          color: _T.indigo.withValues(alpha: 0.32),
                          blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: TextButton(
                      onPressed: _saving ? null : _submit,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: _saving
                          ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.2))
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white),
                          const SizedBox(width: 7),
                          Text('Save changes',
                              style: _T.display(14.5,
                                  color: Colors.white,
                                  w: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Sheet form field — matches profile page _SheetField
class _SheetField extends StatelessWidget {
  final TextEditingController      controller;
  final String                     label;
  final IconData                   icon;
  final Color                      accentColor;
  final TextInputType              keyboardType;
  final TextInputAction?           textInputAction;
  final TextCapitalization         textCapitalization;
  final VoidCallback?              onEditingComplete;
  final List<TextInputFormatter>?  inputFormatters;
  final String? Function(String?)? validator;

  const _SheetField({
    required this.controller,
    required this.label,
    required this.icon,
    this.accentColor        = _T.indigo,
    this.keyboardType       = TextInputType.text,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onEditingComplete,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:          controller,
      keyboardType:        keyboardType,
      textInputAction:     textInputAction,
      textCapitalization:  textCapitalization,
      onEditingComplete:   onEditingComplete,
      inputFormatters:     inputFormatters,
      validator:           validator,
      autovalidateMode:    AutovalidateMode.onUserInteraction,
      style:               _T.body(14.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _T.label(13.5),
        floatingLabelStyle: _T.body(11,
            color: accentColor, w: FontWeight.w600),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Icon(icon, size: 17,
              color: Colors.white.withValues(alpha: 0.3)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: _T.canvas,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _T.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _T.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentColor, width: 1.3)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _T.error, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _T.error, width: 1.3)),
        contentPadding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
        errorStyle: GoogleFonts.inter(color: _T.error, fontSize: 11.5),
      ),
    );
  }
}

/// Status badge
class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? _T.success : _T.error;
    final label = active ? 'Active' : 'Inactive';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: _T.body(11.5, color: color, w: FontWeight.w600)),
      ]),
    );
  }
}

/// Section label — uppercase small caps + hairline
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(text.toUpperCase(),
          style: _T.label(10.5,
              color: _T.mist.withValues(alpha: 0.55))
              .copyWith(letterSpacing: 1.1)),
      const SizedBox(width: 10),
      Expanded(child: Divider(color: _T.border, thickness: 1, height: 1)),
    ]);
  }
}

/// Top bar icon button
class _TopBarBtn extends StatelessWidget {
  final IconData icon;
  final bool     badge;
  final VoidCallback onTap;

  const _TopBarBtn({
    required this.icon, required this.onTap, this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _T.border),
        ),
        child: Stack(children: [
          Center(child: Icon(icon,
              color: Colors.white.withValues(alpha: 0.65), size: 18)),
          if (badge)
            Positioned(
              right: 7, top: 7,
              child: Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                    color: _T.rose, shape: BoxShape.circle),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Confirm dialog — reused from profile page pattern
class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final Color  confirmColor;

  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _T.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _T.display(19)),
              const SizedBox(height: 10),
              Text(body, style: _T.label(14).copyWith(height: 1.55)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: _T.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text('Cancel',
                        style: _T.body(14, w: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(confirmLabel,
                        style: _T.body(14, w: FontWeight.w600)),
                  ),
                ),
              ]),
            ]),
      ),
    );
  }
}

/// FadeSlide — drives opacity + translate from a single Animation<double>
class _FadeSlide extends StatelessWidget {
  final Animation<double> anim;
  final Widget            child;

  const _FadeSlide({required this.anim, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, ch) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - anim.value)),
          child: ch,
        ),
      ),
      child: child,
    );
  }
}

/// Ambient glow blob
class _GlowBlob extends StatelessWidget {
  final Color  color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(
            color: color, blurRadius: size / 1.2, spreadRadius: size / 5)],
      ),
    );
  }
}

/// Dot grid background painter
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.022);
    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}