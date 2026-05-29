import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  late AnimationController _animCtrl;
  late List<Animation<double>> _cardAnims;

  static const _accent = Color(0xFF7C6FFF);
  static const _teal   = Color(0xFF4ECDC4);
  static const _rose   = Color(0xFFFF6B8A);
  static const _amber  = Color(0xFFFFB347);
  static const _bg     = Color(0xFF0A0A1A);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _cardAnims = List.generate(
      5,
          (i) => CurvedAnimation(
        parent: _animCtrl,
        curve: Interval(i * 0.12, (i * 0.12) + 0.5,
            curve: Curves.easeOutBack),
      ),
    );
    _loadUser();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ─── Load User ─────────────────────────────────────────────────────────────
  Future<void> _loadUser() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) throw Exception('User profile not found');
      setState(() {
        _userData  = doc.data();
        _isLoading = false;
      });
      _animCtrl.forward();
    } catch (e) {
      setState(() {
        _error     = e.toString();
        _isLoading = false;
      });
    }
  }

  // ─── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _LogoutDialog(),
    );
    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // ─── Toast ─────────────────────────────────────────────────────────────────
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
                style: const TextStyle(fontSize: 13.5, color: Colors.white),
                overflow: TextOverflow.ellipsis,
                maxLines: 2),
          ),
        ],
      ),
      backgroundColor:
      isError ? const Color(0xFFD32F2F) : const Color(0xFF388E3C),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  // =========================================================================
  // EDIT PROFILE BOTTOM SHEET
  // =========================================================================
  void _openEditProfile() {
    // Pre-fill with current data
    final nameCtrl   = TextEditingController(
        text: _userData?['name']   as String? ?? '');
    final ageCtrl    = TextEditingController(
        text: _userData?['age']?.toString() ?? '');
    final mobileCtrl = TextEditingController(
        text: _userData?['mobile'] as String? ?? '');

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF13132E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Handle bar ────────────────────────────────────────────
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Title ─────────────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: _accent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Edit Profile',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                          Text('Update your personal information',
                              style: TextStyle(
                                  color: Color(0x70FFFFFF),
                                  fontSize: 12.5)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Full Name ─────────────────────────────────────────────
                  _EditField(
                    controller: nameCtrl,
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    icon: Icons.badge_outlined,
                    color: _accent,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Full name is required';
                      }
                      if (v.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Age ───────────────────────────────────────────────────
                  _EditField(
                    controller: ageCtrl,
                    label: 'Age',
                    hint: 'Enter your age',
                    icon: Icons.cake_outlined,
                    color: _rose,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Age is required';
                      }
                      final age = int.tryParse(v.trim());
                      if (age == null || age < 1 || age > 120) {
                        return 'Enter a valid age (1–120)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Mobile ────────────────────────────────────────────────
                  _EditField(
                    controller: mobileCtrl,
                    label: 'Mobile Number',
                    hint: 'Enter your mobile number',
                    icon: Icons.phone_outlined,
                    color: _teal,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(15),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Mobile number is required';
                      }
                      if (v.trim().length < 10) {
                        return 'Enter a valid mobile number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  // ── Buttons ───────────────────────────────────────────────
                  Row(
                    children: [
                      // Cancel
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.15)),
                            padding:
                            const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13)),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Save
                      Expanded(
                        flex: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_accent, Color(0xFF5A4FE0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                color: _accent.withValues(alpha: 0.38),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                              if (!formKey.currentState!.validate()) {
                                return;
                              }
                              setModal(() => isSaving = true);
                              try {
                                final uid = FirebaseAuth
                                    .instance.currentUser?.uid;
                                if (uid != null) {
                                  final newName =
                                  nameCtrl.text.trim();
                                  final newAge =
                                  int.tryParse(ageCtrl.text.trim());
                                  final newMobile =
                                  mobileCtrl.text.trim();

                                  // Save to Firestore
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(uid)
                                      .update({
                                    'name':   newName,
                                    'age':    newAge,
                                    'mobile': newMobile,
                                  });

                                  // Update local state
                                  if (mounted) {
                                    setState(() {
                                      _userData?['name']   = newName;
                                      _userData?['age']    = newAge;
                                      _userData?['mobile'] = newMobile;
                                    });
                                  }
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                                _toast('Profile updated successfully!',
                                    isError: false);
                              } catch (_) {
                                _toast('Failed to update profile.',
                                    isError: true);
                              } finally {
                                setModal(() => isSaving = false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13)),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2))
                                : const Row(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text('Save Changes',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        fontSize: 14.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.9),
                radius: 1.5,
                colors: [Color(0xFF1A1047), _bg],
              ),
            ),
          ),
          Positioned(
            top: -80, right: -60,
            child: _Glow(
                color: _accent.withValues(alpha: 0.17), size: 260),
          ),
          Positioned(
            bottom: 100, left: -70,
            child: _Glow(
                color: _teal.withValues(alpha: 0.11), size: 220),
          ),
          CustomPaint(
            size: Size(size.width, size.height),
            painter: _DotGridPainter(),
          ),
          SafeArea(
            child: _isLoading
                ? _buildLoader()
                : _error != null
                ? _buildError()
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoader() => const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(_accent),
      strokeWidth: 2.2,
    ),
  );

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
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14)),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _loadUser();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: const BorderSide(color: _accent),
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
    final name    = _userData!['name']   as String? ?? 'User';
    final email   = _userData!['email']  as String? ?? '';
    final age     = _userData!['age'];
    final gender  = _userData!['gender'] as String? ?? '';
    final mobile  = _userData!['mobile'] as String? ?? '';
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
            child: _buildAppBar(name.split(' ').first, initials)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _buildWelcomeBanner(name, email, initials),
                const SizedBox(height: 28),
                _buildSectionLabel('PROFILE OVERVIEW'),
                const SizedBox(height: 14),
                _buildProfileGrid(age, gender, mobile, email),
                const SizedBox(height: 28),
                _buildSectionLabel('QUICK ACTIONS'),
                const SizedBox(height: 14),
                _buildQuickActions(),
                const SizedBox(height: 28),
                _buildSectionLabel('ACTIVITY'),
                const SizedBox(height: 14),
                _buildActivityCard(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(String firstName, String initials) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [_accent, Color(0xFF5A4FE0)]),
              boxShadow: [
                BoxShadow(
                    color: _accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: const Icon(Icons.bolt_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Text('Dashboard',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2)),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: Stack(
              children: [
                Icon(Icons.notifications_outlined,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 24),
                Positioned(
                  right: 0, top: 0,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: _rose, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          _LogoutButton(onTap: _signOut),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner(
      String name, String email, String initials) {
    return ScaleTransition(
      scale: _cardAnims[0],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _accent.withValues(alpha: 0.25),
              _teal.withValues(alpha: 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_accent, Color(0xFF5A4FE0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                      color: _accent.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6))
                ],
              ),
              child: Center(
                child: Text(initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${name.split(' ').first} 👋',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 4),
                  Text(email,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12.5),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border:
                      Border.all(color: _teal.withValues(alpha: 0.35)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_outlined,
                            color: _teal, size: 12),
                        SizedBox(width: 4),
                        Text('Verified Account',
                            style: TextStyle(
                                color: _teal,
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
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(label,
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3));
  }

  Widget _buildProfileGrid(
      dynamic age, String gender, String mobile, String email) {
    final items = [
      _InfoItem(label: 'Age',
          value: age?.toString() ?? '—',
          icon: Icons.cake_outlined,    color: _rose),
      _InfoItem(label: 'Gender',
          value: gender.isEmpty ? '—' : gender,
          icon: Icons.wc_outlined,      color: _amber),
      _InfoItem(label: 'Mobile',
          value: mobile.isEmpty ? '—' : mobile,
          icon: Icons.phone_outlined,   color: _teal),
      _InfoItem(label: 'Email',
          value: email,
          icon: Icons.email_outlined,   color: _accent),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ScaleTransition(
                  scale: _cardAnims[1],
                  child: _ProfileInfoCard(item: items[0])),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ScaleTransition(
                  scale: _cardAnims[2],
                  child: _ProfileInfoCard(item: items[1])),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ScaleTransition(
                  scale: _cardAnims[3],
                  child: _ProfileInfoCard(item: items[2])),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ScaleTransition(
                  scale: _cardAnims[4],
                  child: _ProfileInfoCard(item: items[3])),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Quick Actions ─────────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(
          icon: Icons.person_outline_rounded,
          label: 'Edit Profile',
          color: _accent,
          onTap: _openEditProfile),   // ← wired to edit profile
      _QuickAction(
          icon: Icons.security_outlined,
          label: 'Security',
          color: _rose,
          onTap: () {}),
      _QuickAction(
          icon: Icons.notifications_outlined,
          label: 'Alerts',
          color: _amber,
          onTap: () {}),
      _QuickAction(
          icon: Icons.help_outline_rounded,
          label: 'Support',
          color: _teal,
          onTap: () {}),
    ];

    return Row(
      children: actions.map((a) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: a == actions.last ? 0 : 10),
            child: _QuickActionTile(action: a),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: const Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Activity',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5)),
              Text('View all',
                  style: TextStyle(
                      color: _accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          SizedBox(height: 16),
          _ActivityRow(
              icon: Icons.login_rounded,
              title: 'Account Created',
              subtitle: 'Welcome aboard!',
              color: _teal),
          SizedBox(height: 12),
          _ActivityRow(
              icon: Icons.verified_user_outlined,
              title: 'Profile Completed',
              subtitle: 'All fields filled in',
              color: _accent),
          SizedBox(height: 12),
          _ActivityRow(
              icon: Icons.security_outlined,
              title: 'Email Verified',
              subtitle: 'Account secured',
              color: _amber),
        ],
      ),
    );
  }
}

// =============================================================================
// EDIT FIELD — reusable validated text field for the bottom sheet
// =============================================================================
class _EditField extends StatelessWidget {
  final TextEditingController          controller;
  final String                         label;
  final String                         hint;
  final IconData                       icon;
  final Color                          color;
  final TextInputType                  keyboardType;
  final TextCapitalization             textCapitalization;
  final List<TextInputFormatter>?      inputFormatters;
  final String? Function(String?)?     validator;

  const _EditField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
    this.keyboardType        = TextInputType.text,
    this.textCapitalization  = TextCapitalization.none,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Row(
          children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 13),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        // Input
        TextFormField(
          controller:         controller,
          keyboardType:       keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters:    inputFormatters,
          validator:          validator,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 14),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 12),
              child: Icon(icon, color: color, size: 18),
            ),
            prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.055),
            contentPadding:
            const EdgeInsets.fromLTRB(0, 16, 16, 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.09)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: color, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(
                  color: Color(0xFFFF5252), width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(
                  color: Color(0xFFFF5252), width: 1.5),
            ),
            errorStyle: const TextStyle(
                color: Color(0xFFFF5252), fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SUPPORTING WIDGETS
// =============================================================================

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B8A).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: const Color(0xFFFF6B8A).withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.logout_rounded,
                color: Color(0xFFFF6B8A), size: 15),
            SizedBox(width: 5),
            Text('Logout',
                style: TextStyle(
                    color: Color(0xFFFF6B8A),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();

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
              width: 58, height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6B8A).withValues(alpha: 0.12),
                border: Border.all(
                    color: const Color(0xFFFF6B8A)
                        .withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Color(0xFFFF6B8A), size: 26),
            ),
            const SizedBox(height: 18),
            const Text('Sign Out?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'You will need to sign in again to access your account.',
              textAlign: TextAlign.center,
              style: TextStyle(
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
                          color: Colors.white.withValues(alpha: 0.15)),
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B8A),
                      foregroundColor: Colors.white,
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Sign Out',
                        style: TextStyle(fontWeight: FontWeight.w700)),
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

class _InfoItem {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  final bool     fullWidth;

  const _InfoItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.fullWidth = false,
  });
}

class _ProfileInfoCard extends StatelessWidget {
  final _InfoItem item;
  const _ProfileInfoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 17),
          ),
          const SizedBox(height: 12),
          Text(item.label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text(item.value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, color: action.color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;
  final Color    color;

  const _ActivityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12)),
            ],
          ),
        ),
        Icon(Icons.check_circle_rounded, color: color, size: 16),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final Color  color;
  final double size;
  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
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
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;
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